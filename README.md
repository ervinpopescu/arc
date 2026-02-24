# Configs for [ARC](https://github.com/actions/actions-runner-controller)

This repository contains configurations, Dockerfiles, and scripts for deploying custom Actions Runner Controller (ARC) runner sets on Kubernetes (Minikube).

## Project Structure

```
.
├── .github/workflows  # CI/CD for building runner images
├── images/            # Dockerfiles for custom runners
│   ├── base/          # Base runner with common deps
│   └── qtile/         # Runner specialized for Qtile development
├── runners/           # Helm values and runner-set configs
├── scripts/           # Deployment and utility scripts
└── Makefile           # Unified interface for management
```

## Quick Start

### 1. Build Images
Build and push the custom runner images to GHCR:
```bash
make build
make push
```

### 2. Deploy Runners
Deploy the controller and a specific runner scale set. You will be prompted for your GitHub PAT if `GITHUB_TOKEN` is not set.
```bash
# Deploy base runner set
make deploy-base

# Deploy qtile runner set
make deploy-qtile
```

### 3. Non-interactive Deployment
For automation, you can provide environment variables to skip prompts:
```bash
export GITHUB_TOKEN=your_pat_here
export RUNNER_NAMESPACE=my-runners
make deploy-base
```

### 4. Cleanup
To uninstall a runner set and its associated resources:
```bash
make undeploy-base
```

If a namespace gets stuck in a "Terminating" state:
```bash
make cleanup-base
```

## Monitoring
The deployment includes the `kube-prometheus-stack`. You can access the Prometheus dashboard using the provided systemd service or by running:
```bash
kubectl --namespace monitoring port-forward svc/prometheus-operated 9090:9090
```
