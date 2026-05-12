#!/bin/bash
export DEFAULT_ARC_INSTALLATION_NAME="arc"
export DEFAULT_ARC_NAMESPACE="arc-systems"
export DEFAULT_RUNNERSET_INSTALLATION_NAME="base"
export DEFAULT_RUNNERS_NAMESPACE="base-runners"
export DEFAULT_SECRET_NAME="pre-defined-secret"
export DEFAULT_OVERRIDES_PATH="./runners/base/values.runner-set.yaml"
export TOOLCACHE_PVC_YAML=./runners/base/manifests/tool-cache-pvc.yaml
export DEFAULT_MINIKUBE_PROFILE="prod"
export MINIKUBE_DRIVER="kvm2"
# Uncomment and set MIN_NODES > 1 to provision a multi-node cluster.
# MINIKUBE_CNI must also be set to a CNI that supports cross-node networking (calico, flannel, cilium).
export MIN_NODES=2
export MINIKUBE_CNI=calico
