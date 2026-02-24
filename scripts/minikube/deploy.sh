#!/bin/bash
set -eo pipefail

if [[ "$1" == "" ]]; then
  echo "Usage: $(basename $0) <path to defaults.sh>"
  exit 1
fi
source "$1"

[ -z "$DEFAULT_ARC_INSTALLATION_NAME" ] && export DEFAULT_ARC_INSTALLATION_NAME="arc"
[ -z "$DEFAULT_ARC_NAMESPACE" ] && export DEFAULT_ARC_NAMESPACE="arc-systems"
[ -z "$DEFAULT_RUNNERSET_INSTALLATION_NAME" ] && export DEFAULT_RUNNERSET_INSTALLATION_NAME="arc-runner-set"
[ -z "$DEFAULT_RUNNERS_NAMESPACE" ] && export DEFAULT_RUNNERS_NAMESPACE="arc-runners"
[ -z "$DEFAULT_SECRET_NAME" ] && export DEFAULT_SECRET_NAME="pre-defined-secret"
[ -z "$DEFAULT_OVERRIDES_PATH" ] && export DEFAULT_OVERRIDES_PATH="./runners/base/values.runner-set.yaml"
[ -z "$TOOLCACHE_PVC_YAML" ] && export TOOLCACHE_PVC_YAML="./runners/base/tool-cache-pvc.yaml"

# Prompt with default support (skips if variable is already set)
prompt() {
  local msg=$1 default=$2 var_name=$3 var
  if [[ -n "${!var_name}" ]]; then
    echo "${!var_name}"
    return
  fi
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
    --wait
  echo
}

# --- Controller chart ---
INSTALLATION_NAME=$(prompt "Helm release name for controller chart" "$DEFAULT_ARC_INSTALLATION_NAME" "INSTALLATION_NAME")
NAMESPACE=$(prompt "Systems namespace (controller ns)" "$DEFAULT_ARC_NAMESPACE" "NAMESPACE")

helm_install "$INSTALLATION_NAME" "$NAMESPACE" \
  oci://ghcr.io/actions/actions-runner-controller-charts/gha-runner-scale-set-controller

# --- Runner chart ---
RUNNER_INSTALLATION_NAME=$(prompt "Helm release name for runner chart" "$DEFAULT_RUNNERSET_INSTALLATION_NAME" "RUNNER_INSTALLATION_NAME")
RUNNER_NAMESPACE=$(prompt "Runners namespace" "$DEFAULT_RUNNERS_NAMESPACE" "RUNNER_NAMESPACE")

kubectl get ns "$RUNNER_NAMESPACE" >/dev/null 2>&1 || kubectl create ns "$RUNNER_NAMESPACE"

# --- GitHub PAT secret ---
if [[ -z "$GITHUB_TOKEN" ]]; then
  read -rsp "GitHub PAT: " GITHUB_TOKEN
  echo
fi
SECRET_NAME=$(prompt "Kubernetes secret name" "$DEFAULT_SECRET_NAME" "SECRET_NAME")

kubectl apply -f - <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: ${SECRET_NAME}
  namespace: ${RUNNER_NAMESPACE}
stringData:
  github_token: ${GITHUB_TOKEN}
EOF
echo "Created/updated secret: ${SECRET_NAME} in namespace ${RUNNER_NAMESPACE}"
echo

# --- Runner values override ---
OVERRIDES_PATH=$(prompt "Overrides path" "$DEFAULT_OVERRIDES_PATH" "OVERRIDES_PATH")

helm_install "$RUNNER_INSTALLATION_NAME" "$RUNNER_NAMESPACE" \
  oci://ghcr.io/actions/actions-runner-controller-charts/gha-runner-scale-set \
  "$OVERRIDES_PATH"

kubectl apply -f "$TOOLCACHE_PVC_YAML"

helm upgrade --install prom-stack oci://ghcr.io/prometheus-community/charts/kube-prometheus-stack \
  --namespace monitoring \
  --create-namespace \
  --set grafana.enabled=false
