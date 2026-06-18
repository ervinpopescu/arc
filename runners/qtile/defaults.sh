#!/bin/bash
export DEFAULT_ARC_INSTALLATION_NAME="arc"
export DEFAULT_ARC_NAMESPACE="arc-systems"
export DEFAULT_RUNNERSET_INSTALLATION_NAME="qtile"
export DEFAULT_RUNNERS_NAMESPACE="qtile-runners"
export DEFAULT_SECRET_NAME="pre-defined-secret"
export DEFAULT_OVERRIDES_PATH="./runners/qtile/values.runner-set.yaml"
export TOOLCACHE_PVC_YAML=./runners/qtile/manifests/tool-cache-pvc.yaml
export DEFAULT_MINIKUBE_PROFILE="prod"
export MINIKUBE_DRIVER="kvm2"
export MINIKUBE_EXTRA_ARGS="--memory=8192 --disk-size=50g --container-runtime=containerd"
# Uncomment and set MIN_NODES > 1 to provision a multi-node cluster.
# MINIKUBE_CNI must also be set to a CNI that supports cross-node networking (calico, flannel, cilium).
export MIN_NODES=2
export MINIKUBE_CNI=calico
