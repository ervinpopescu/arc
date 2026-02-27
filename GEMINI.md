# GEMINI Context: ARC Configuration & Deployment

This repository provides a complete, automated environment for managing **Actions Runner Controller (ARC)** on Kubernetes (targeted at Minikube), featuring custom runner images, shared tool persistence, and comprehensive infrastructure testing.

## Project Overview
- **Purpose:** Deploy and maintain custom GitHub Actions runner scale sets with persistent tool caching (Rust, uv).
- **Core Technologies:** ARC (Actions Runner Controller), Kubernetes (Minikube), Docker, Helm, Shell scripting.
- **Architecture:**
  - **Custom Images:** Ubuntu 26.04 (Resolute) based runners.
  - **Persistence:** Shared PVC (`tool-cache-runnerset`) mounted to `/opt/hostedtoolcache`.
  - **Tooling:** Automated setup of Rust (stable/nightly) and `uv` via a dedicated debug pod.
  - **Monitoring:** Integrated Prometheus stack for metrics.
  - **Watchdog:** Systemd service to ensure Minikube auto-restarts on failure/OOM.

## Key Management Commands

### 1. Image Lifecycle
- `make build`: Build custom runner images locally.
- `make push`: Push verified images to GHCR (restricted to `main` in CI).

### 2. Deployment
- `make deploy-base`: Deploy the base ARC runner set.
- `make deploy-qtile`: Fully automate the Qtile environment (PVC -> Tools -> Runner Set).
- `make undeploy-qtile`: Gracefully uninstall the scale set.

### 3. Testing & Validation
- `make test-manifests`: Lint Helm charts and verify template substitution.
- `make test-images`: Verify binaries (`git`, `rustc`, `uv`) and permissions in local images.
- `make test-cluster`: Verify live cluster health and PVC write access.
- `make test-all`: Run all automated verification gates.

### 4. Maintenance & Cleanup
- `make cleanup-qtile-tools`: Clear persistent data in the PVC and remove the debug pod.
- `make cleanup-qtile`: Forcefully remove the runner namespace if stuck.

## Development Conventions
- **Branching:** New features and infrastructure changes should be developed on `setup-arc` and merged via PR.
- **CI/CD:** 
  - `lint` job runs on all branches.
  - `build` and `test` run on all branches to ensure integrity.
  - `push` is strictly limited to the `main` branch.
- **Configuration:**
  - Use a `.env` file for local `GITHUB_TOKEN` storage (ignored by git).
  - Use `fsGroup: 123` in manifests to maintain volume write permissions for the `runner` user.
- **Idempotency:** All deployment scripts (`deploy.sh`, `setup-qtile-tools.sh`) must be idempotent and handle existing resources gracefully.
- **Safety:** Always include confirmation prompts in cleanup scripts (`cleanup-ns.sh`, `cleanup-qtile-tools.sh`).

## Deployment Pre-requisites
- **Environment:** Arch Linux with Docker running as root.
- **Minikube Profile:** `prod-docker` (using the `docker` driver with `--force`).
- **GPG Keys:** Ensure `archlinux-keyring` is updated to avoid signature trust issues during local builds.
