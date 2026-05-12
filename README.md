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

## Prerequisites

### Packages (Arch Linux)

```bash
# Core
sudo pacman -S libvirt qemu-system-x86 qemu-img dnsmasq

# KVM2 minikube driver (AUR)
yay -S docker-machine-driver-kvm2
```

### One-time system setup

**1. Add your user to the `libvirt` group** (re-login or `newgrp libvirt` to activate):
```bash
sudo usermod -aG libvirt $USER
```

**2. Enable libvirtd:**
```bash
sudo systemctl enable --now libvirtd
```

**3. Set libvirt to use the iptables firewall backend** (avoids conflicts with Docker's iptables rules):
```bash
echo 'firewall_backend = "iptables"' | sudo tee -a /etc/libvirt/network.conf
sudo systemctl restart libvirtd
```

## Quick Start

### 1. Build Images
```bash
make build
make push
```

### 2. Deploy Runners

Deploy the controller and a runner scale set. Prompts for your GitHub PAT if `GITHUB_TOKEN` is not set. The deploy script will start the minikube cluster automatically if it is not already running.

```bash
# Deploy base runner set
make deploy-base

# Deploy qtile runner set
make deploy-qtile
```

For non-interactive deployment:
```bash
export GITHUB_TOKEN=your_pat_here
make deploy-base
```

### 3. Cleanup

```bash
make undeploy-base   # Uninstall runner set
make cleanup-base    # Force-delete stuck namespace
```

## Multi-node Setup

Both runner sets are configured for 2 nodes with Calico CNI by default (`MIN_NODES=2`, `MINIKUBE_CNI=calico` in `runners/*/defaults.sh`). The deploy script adds worker nodes automatically using `minikube node add`.

To use a single node, set `MIN_NODES=1` in the relevant `defaults.sh`.

## Driver & Cluster Configuration

Cluster settings live in `runners/*/defaults.sh` and are consumed by `scripts/minikube/deploy.sh`:

| Variable | Default | Description |
|----------|---------|-------------|
| `DEFAULT_MINIKUBE_PROFILE` | `prod` | Minikube profile name |
| `MINIKUBE_DRIVER` | `kvm2` | Minikube driver |
| `MINIKUBE_EXTRA_ARGS` | _(unset)_ | Extra args passed to `minikube start` |
| `MINIKUBE_CNI` | `calico` | CNI plugin (required for multi-node) |
| `MIN_NODES` | `2` | Total node count (control-plane + workers) |

The `kvm2` driver runs each node as a KVM virtual machine via libvirt. It requires `/dev/kvm` access (world-accessible on Arch by default) and the `libvirt` group.

## Rootless Operation

The deployment is fully rootless — no `sudo` is needed for `kubectl`, `minikube`, or `helm`. The only operations that require elevated privileges are:

- Unbound DNS setup (scoped `sudo` inside `scripts/minikube/deploy.sh`)
- Initial one-time system setup (libvirt group, libvirtd service, firewall backend)

## Runner Images

### Base runner (`images/base/`)
Debian-based image extending `mcr.microsoft.com/dotnet/runtime-deps`. Packages are listed in `images/base/deps`.

### Qtile runner (`images/qtile/`)
Fedora-based image extending `qtile-ci-base`. Includes:
- ARC runner binary and container hooks
- `cargo-binstall` (installed to `/usr/local/bin` for use in CI jobs)

## Monitoring
```bash
make deploy-monitoring   # Deploy Prometheus lite + metrics-server
make get-vpa-recommendations
kubectl --namespace monitoring port-forward svc/prometheus-operated 9090:9090
```

## Related Repositories

- **[archnet-cfg](https://github.com/ervinpopescu/archnet-cfg)**: Host machine configuration — provides the base `minikube.service` and `port-fwd-prometheus.service` that integrate with this setup.
