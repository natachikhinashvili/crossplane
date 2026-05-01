# Stack — Pinned Versions

All versions used in this course. Pin everything; do not use `latest`.

## Local environment

| Component  | Version  |
|------------|----------|
| Docker     | 27.3.1   |
| kind       | v0.25.0  |
| Kubernetes | v1.31.2  |

Kubernetes version is the kind node image: `kindest/node:v1.31.2`.

## Crossplane

| Component  | Version |
|------------|---------|
| Crossplane | v1.18.0 |

Install via Helm chart `crossplane-stable/crossplane` at the matching chart version `1.18.0`.

## Providers

| Provider                                          | Version |
|---------------------------------------------------|---------|
| `xpkg.upbound.io/upbound/provider-aws-ec2`        | v2.4.0  |
| `xpkg.upbound.io/upbound/provider-aws-s3`         | v2.4.0  |
| `xpkg.upbound.io/upbound/provider-family-aws`     | v2.4.0 (auto-installed as a dependency of the service providers above) |
| `xpkg.upbound.io/crossplane-contrib/provider-kubernetes` | v1.2.1  |
| `xpkg.upbound.io/crossplane-contrib/provider-helm`       | v1.2.0  |

## Composition functions

| Function                                                            | Version |
|---------------------------------------------------------------------|---------|
| `xpkg.upbound.io/crossplane-contrib/function-patch-and-transform`   | v0.8.2  |
| `xpkg.upbound.io/crossplane-contrib/function-go-templating`         | v0.9.2  |

## Backing services

| Component  | Image                       |
|------------|-----------------------------|
| LocalStack | `localstack/localstack:3.8` |
| Postgres   | `postgres:15.8-alpine`      |
