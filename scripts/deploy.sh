#!/bin/bash
set -eo pipefail

if [[ "$1" -eq "" ]]; then
  echo "Usage: $(basename $0) <path to defaults.sh>"
  exit
fi
source "$1"

[ -z "$DEFAULT_ARC_INSTALLATION_NAME" ] && export DEFAULT_ARC_INSTALLATION_NAME="arc"
[ -z "$DEFAULT_ARC_NAMESPACE" ] && export DEFAULT_ARC_NAMESPACE="arc-systems"
[ -z "$DEFAULT_RUNNERSET_INSTALLATION_NAME" ] && export DEFAULT_RUNNERSET_INSTALLATION_NAME="arc-runner-set"
[ -z "$DEFAULT_RUNNERS_NAMESPACE" ] && export DEFAULT_RUNNERS_NAMESPACE="arc-runners"
[ -z "$DEFAULT_SECRET_NAME" ] && export DEFAULT_SECRET_NAME="pre-defined-secret"
[ -z "$DEFAULT_OVERRIDES_PATH" ] && export DEFAULT_OVERRIDES_PATH="./runners/base/values.runner-set.yaml"
[ -z "$TOOLCACHE_PVC_YAML" ] && export TOOLCACHE_PVC_YAML="./runners/base/tool-cache-pvc.yaml"

# Prompt with default support
prompt() {
  local msg=$1 default=$2 var
  read -rp "$msg [$default]: " var
  echo "${var:-$default}"
}

# Helm wrapper for idempotent installs
helm_install() {
  local name=$1 ns=$2 chart=$3 values=${4:-}
  echo "Installing chart: $chart"
  echo "  Release: $name"
  echo "  Namespace: $ns"
  if [[ -n "$values" ]]; then
    echo "  Values: $values"
  fi
  helm upgrade --install "$name" \
    --namespace "$ns" \
    --create-namespace \
    ${values:+--values "$values"} \
    "$chart" \
    --wait --timeout 5s
  echo
}

# --- Controller chart ---
INSTALLATION_NAME=$(prompt "Helm release name for controller chart" "$DEFAULT_ARC_INSTALLATION_NAME")
NAMESPACE=$(prompt "Systems namespace (controller ns)" "$DEFAULT_ARC_NAMESPACE")

helm_install "$INSTALLATION_NAME" "$NAMESPACE" \
  oci://ghcr.io/actions/actions-runner-controller-charts/gha-runner-scale-set-controller

# --- Runner chart ---
INSTALLATION_NAME=$(prompt "Helm release name for runner chart" "$DEFAULT_RUNNERSET_INSTALLATION_NAME")
NAMESPACE=$(prompt "Runners namespace" "$DEFAULT_RUNNERS_NAMESPACE")

kubectl get ns "$NAMESPACE" >/dev/null 2>&1 || kubectl create ns "$NAMESPACE"

# --- GitHub PAT secret ---
read -rsp "GitHub PAT: " TOKEN
echo
SECRET_NAME=$(prompt "Kubernetes secret name" "$DEFAULT_SECRET_NAME")

kubectl apply -f - <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: ${SECRET_NAME}
  namespace: ${NAMESPACE}
stringData:
  github_token: ${TOKEN}
EOF
echo "Created/updated secret: ${SECRET_NAME} in namespace ${NAMESPACE}"
echo

# --- Runner values override ---
OVERRIDES_PATH=$(prompt "Overrides path" "$DEFAULT_OVERRIDES_PATH")

helm_install "$INSTALLATION_NAME" "$NAMESPACE" \
  oci://ghcr.io/actions/actions-runner-controller-charts/gha-runner-scale-set \
  "$OVERRIDES_PATH"

kubectl apply -f "$TOOLCACHE_PVC_YAML"
