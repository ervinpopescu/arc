This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Is

ARC (Actions Runner Controller) configuration repo: custom GitHub Actions runner images, Helm values, and deployment scripts for Kubernetes (Minikube, profile `prod-docker`, docker driver).

## Common Commands

```bash
make build                  # Build base + qtile runner images locally
make push                   # Build and push images to GHCR
make deploy-base            # Deploy base runner scale set
make deploy-qtile           # Set up qtile tool cache + deploy runner scale set
make undeploy-base          # Uninstall base runner set
make undeploy-qtile         # Uninstall qtile runner set
make test-manifests         # Lint Helm charts and verify template substitution
make test-images            # Verify binaries and permissions in built images
make test-cluster           # Verify live cluster health and PVC access
make test-all               # Run test-manifests + test-images
make pre-commit             # Run pre-commit hooks (shellcheck, hadolint, yaml checks)
make deploy-infra           # Deploy Prometheus + VPA
make get-vpa-recommendations # View VPA resource suggestions
```

Set `GITHUB_TOKEN` in a `.env` file (gitignored) for non-interactive deployment.

## Architecture

### Image Inheritance

`images/base/Dockerfile` builds `ghcr.io/ervinpopescu/arc-custom-runner:ubuntu-26.04` from Microsoft's dotnet runtime-deps. `images/qtile/Dockerfile` extends it via `ARG BASE_IMAGE`. The build script (`scripts/images/build_n_push.sh`) tags the base image as `arc-base:local` so the qtile image can inherit from it during local builds. Dependencies are listed in `images/{base,qtile}/deps` files (one package per line).

### Runner Sets (Parameterized Deployment)

Each runner set lives under `runners/{name}/` with:

- `defaults.sh` — shell variables (installation name, namespace, values path, PVC path)
- `values.runner-set.yaml` — Helm values for `gha-runner-scale-set` chart
- `manifests/` — PVCs, VPA policies, debug pods, etc.

`scripts/minikube/deploy.sh` and `undeploy.sh` both take a `defaults.sh` path as their argument and source it for configuration. Deploy uses `helm-diff` for idempotent change detection.

### Tool Cache Persistence

A 25Gi ReadWriteMany PVC (`tool-cache-runnerset`) is mounted at `/opt/hostedtoolcache` across runner pods. Tools (Rust, uv) are pre-installed via a debug pod (`scripts/arc/setup-qtile-tools.sh`). The runner user is UID 1001, GID 123 — manifests use `fsGroup: 123` to maintain volume permissions.

### VPA Shadow Deployment

VPA targets a replica=0 shadow deployment (not the StatefulSet directly) with `updateMode: Off` for recommendation-only mode. The shadow deployment is created by `deploy.sh` using envsubst on the VPA manifest.

### CI/CD

`.github/workflows/build-images.yaml`: lint -> build-and-test -> conditional push (main branch only). Triggered by changes to images/, runners/, scripts/, tests/, Makefile, plus weekly schedule. `.github/workflows/cleanup-images.yaml`: monthly cleanup of GHCR versions older than 90 days.

## Conventions

- All deployment/cleanup scripts must be **idempotent** and handle existing resources gracefully.
- Cleanup scripts must include **confirmation prompts**.
- Pre-commit hooks: shellcheck (shell), hadolint (Dockerfiles), standard yaml/whitespace checks.
- Base runner set targets `github.com/ervinpopescu/arc`; qtile targets `github.com/ervinpopescu/qtile-cmd-client`.
