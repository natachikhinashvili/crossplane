Crossplane v2: Build a Self-Service WebApp Platform Locally

Module 1 — Why Crossplane, Why v2 (25 min)
IaC landscape. Terraform vs Crossplane honest comparison. Control-plane mental model. v1 vs v2 changes. Who this course is for. Course roadmap ending on the WebApp capstone preview.

Module 2 — Setup & First Resource (30 min)
Bootstrap script walkthrough. Kind + Crossplane v2 + AWS provider + provider-kubernetes + LocalStack. Apply your first managed resource (S3 bucket on LocalStack). Watch reconciliation loop. Verify with kubectl and LocalStack CLI.

Module 3 — Managed Resources Deep Dive (40 min)
MRs as CRDs. External names, drift correction (delete from LocalStack, watch it return), references between resources. Lab: VPC + subnet + IAM role as separate MRs.

Module 4 — Your First Composition (60 min)
XRDs (v2 namespaced, no claims). Composition functions: function-patch-and-transform, function-go-templating. Build a Bucket XR with standard tags + encryption. Apply, inspect, debug with crossplane beta trace.

Module 5 — Building the WebApp Platform API (90 min). The capstone.
Design the WebApp XRD. Compose: VPC + subnet + S3 + IAM role (LocalStack) + Postgres StatefulSet + Service + Secret + app Deployment + Service (k8s-native). Wire DB connection string into the app via ConfigMap. Apply one YAML, curl the running app.

Module 6 — Going to Production (45 min)
Real AWS pointer: how the same XRs work against real AWS. IRSA. Billing alerts. Teardown scripts. GitOps with ArgoCD (brief). Where to go next.

Total: ~4.5 hours, 6 modules.
