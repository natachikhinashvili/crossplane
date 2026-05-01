#!/usr/bin/env bash
# One-command setup for the Crossplane course.
# Spins up a kind cluster, installs Crossplane + providers + composition functions,
# deploys LocalStack, and runs a health check.
#
# Re-running is safe: each step is idempotent.
#
# Versions are pinned in STACK.md. Update both files together.

set -euo pipefail

# ---- pinned versions (mirror STACK.md) ---------------------------------------
CLUSTER_NAME="${CLUSTER_NAME:-crossplane-course}"
KIND_NODE_IMAGE="kindest/node:v1.31.2"
CROSSPLANE_CHART_VERSION="1.18.0"

# ---- pretty output -----------------------------------------------------------
if [[ -t 1 ]]; then
  BOLD=$'\033[1m'; GREEN=$'\033[32m'; YELLOW=$'\033[33m'; RED=$'\033[31m'; RESET=$'\033[0m'
else
  BOLD=""; GREEN=""; YELLOW=""; RED=""; RESET=""
fi

step()  { printf '\n%s==>%s %s%s%s\n' "$GREEN" "$RESET" "$BOLD" "$*" "$RESET"; }
info()  { printf '    %s\n' "$*"; }
warn()  { printf '%s[warn]%s %s\n' "$YELLOW" "$RESET" "$*"; }
fail()  { printf '%s[fail]%s %s\n' "$RED" "$RESET" "$*" >&2; exit 1; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ---- prerequisites -----------------------------------------------------------
step "Checking prerequisites"
for bin in docker kind kubectl helm; do
  command -v "$bin" >/dev/null 2>&1 || fail "missing required tool: $bin"
  info "found $bin: $(command -v "$bin")"
done
docker info >/dev/null 2>&1 || fail "docker daemon not reachable — start Docker Desktop"

# ---- kind cluster ------------------------------------------------------------
step "Creating kind cluster '${CLUSTER_NAME}'"
if kind get clusters 2>/dev/null | grep -qx "${CLUSTER_NAME}"; then
  info "cluster already exists, reusing it"
else
  kind create cluster --name "${CLUSTER_NAME}" --image "${KIND_NODE_IMAGE}" --wait 300s
fi
kubectl cluster-info --context "kind-${CLUSTER_NAME}" >/dev/null

# ---- Crossplane --------------------------------------------------------------
step "Installing Crossplane v${CROSSPLANE_CHART_VERSION}"
helm repo add crossplane-stable https://charts.crossplane.io/stable >/dev/null 2>&1 || true
helm repo update crossplane-stable >/dev/null
helm upgrade --install crossplane crossplane-stable/crossplane \
  --namespace crossplane-system --create-namespace \
  --version "${CROSSPLANE_CHART_VERSION}" \
  --wait

step "Waiting for Crossplane control plane to be Ready"
kubectl -n crossplane-system rollout status deploy/crossplane --timeout=300s
kubectl -n crossplane-system rollout status deploy/crossplane-rbac-manager --timeout=300s

# ---- LocalStack --------------------------------------------------------------
step "Deploying LocalStack"
kubectl get ns localstack >/dev/null 2>&1 || kubectl create namespace localstack
kubectl apply -f "${SCRIPT_DIR}/localstack.yaml"
# 631MB image; first-run pulls take 3-5 min on typical home connections.
kubectl -n localstack rollout status deploy/localstack --timeout=600s

# ---- AWS credentials secret (LocalStack accepts dummy creds) -----------------
step "Creating AWS credentials secret for the AWS provider"
kubectl apply -f "${SCRIPT_DIR}/aws-creds.yaml"

# ---- Providers ---------------------------------------------------------------
step "Installing AWS providers (ec2 + s3; family-aws auto-installed as dependency)"
kubectl apply -f "${SCRIPT_DIR}/aws-provider.yaml"
kubectl apply -f "${SCRIPT_DIR}/provider-aws-ec2.yaml"

step "Installing provider-kubernetes"
kubectl apply -f "${SCRIPT_DIR}/provider-kubernetes.yaml"

step "Installing composition functions"
kubectl apply -f "${SCRIPT_DIR}/functions.yaml"

# ---- Wait for packages to become Healthy -------------------------------------
wait_healthy() {
  local kind="$1" name="$2" timeout="${3:-1200s}"
  info "waiting for ${kind}/${name} to be Healthy (timeout ${timeout})"
  kubectl wait "${kind}.pkg.crossplane.io" "${name}" \
    --for=condition=Healthy --timeout="${timeout}" >/dev/null
}

step "Waiting for providers and functions to be Healthy"
wait_healthy provider provider-aws-s3
wait_healthy provider provider-aws-ec2
wait_healthy provider provider-kubernetes
wait_healthy function function-patch-and-transform
wait_healthy function function-go-templating

# ---- Provider configuration --------------------------------------------------
# ProviderConfig CRDs are installed by their providers, so they must be applied
# AFTER the provider is Healthy. Brief retry covers the gap between Healthy=True
# being reported and the CRD being servable.
apply_with_retry() {
  local file="$1"
  for attempt in 1 2 3 4 5; do
    if kubectl apply -f "${file}" 2>/dev/null; then
      return 0
    fi
    info "CRD for $(basename "${file}") not ready yet, retrying (${attempt}/5)"
    sleep 5
  done
  fail "could not apply ${file} after 5 attempts"
}

step "Applying AWS ProviderConfig pointing at LocalStack"
apply_with_retry "${SCRIPT_DIR}/providerconfig.yaml"

step "Applying provider-kubernetes ProviderConfig"
apply_with_retry "${SCRIPT_DIR}/provider-kubernetes-config.yaml"

# ---- Health check ------------------------------------------------------------
step "Health check"
checks_failed=0
check() {
  local label="$1"; shift
  if "$@" >/dev/null 2>&1; then
    printf '    %s[ok]%s   %s\n' "$GREEN" "$RESET" "$label"
  else
    printf '    %s[FAIL]%s %s\n' "$RED" "$RESET" "$label"
    checks_failed=$((checks_failed + 1))
  fi
}

check "kind cluster reachable" \
  kubectl --context "kind-${CLUSTER_NAME}" get nodes
check "crossplane deployment Available" \
  kubectl -n crossplane-system wait --for=condition=Available deploy/crossplane --timeout=10s
check "localstack deployment Available" \
  kubectl -n localstack wait --for=condition=Available deploy/localstack --timeout=10s
check "provider-aws-ec2 Healthy" \
  kubectl wait provider.pkg.crossplane.io/provider-aws-ec2 --for=condition=Healthy --timeout=10s
check "provider-aws-s3 Healthy" \
  kubectl wait provider.pkg.crossplane.io/provider-aws-s3 --for=condition=Healthy --timeout=10s
check "provider-kubernetes Healthy" \
  kubectl wait provider.pkg.crossplane.io/provider-kubernetes --for=condition=Healthy --timeout=10s
check "function-patch-and-transform Healthy" \
  kubectl wait function.pkg.crossplane.io/function-patch-and-transform --for=condition=Healthy --timeout=10s
check "function-go-templating Healthy" \
  kubectl wait function.pkg.crossplane.io/function-go-templating --for=condition=Healthy --timeout=10s
check "AWS ProviderConfig 'default' present" \
  kubectl get providerconfig.aws.upbound.io/default
check "LocalStack /_localstack/health responds" \
  kubectl -n localstack run ls-health --rm -i --restart=Never --image=curlimages/curl:8.10.1 \
    --command -- curl -fsS http://localstack.localstack.svc.cluster.local:4566/_localstack/health

if (( checks_failed > 0 )); then
  fail "${checks_failed} health check(s) failed — see output above"
fi

step "Bootstrap complete"
cat <<EOF

  Cluster:     kind-${CLUSTER_NAME}
  Crossplane:  v${CROSSPLANE_CHART_VERSION} (namespace: crossplane-system)
  LocalStack:  http://localstack.localstack.svc.cluster.local:4566 (in-cluster)

  Try it:
    kubectl get providers
    kubectl get functions
    kubectl get providerconfigs.aws.upbound.io

  Tear down with:
    kind delete cluster --name ${CLUSTER_NAME}

EOF
