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

# Prompt with default support
prompt() {
  local msg=$1 default=$2 var
  read -rp "$msg [$default]: " var
  echo "${var:-$default}"
}

# Helm uninstall wrapper
helm_uninstall() {
  local name=$1 ns=$2
  echo "Uninstalling Helm release:"
  echo "  Release: $name"
  echo "  Namespace: $ns"
  helm uninstall "$name" --namespace "$ns" || echo "ℹ️ Release $name not found in $ns"
  echo
}

# Delete secret safely
delete_secret() {
  local name=$1 ns=$2
  echo "Deleting secret:"
  echo "  Secret: $name"
  echo "  Namespace: $ns"
  kubectl delete secret "$name" -n "$ns" --ignore-not-found
  echo
}

# Optionally delete namespace
delete_namespace() {
  local ns=$1
  read -rp "Do you also want to delete namespace '$ns'? [y/N]: " confirm
  if [[ "${confirm,,}" == "y" ]]; then
    kubectl delete ns "$ns" --ignore-not-found --timeout 5s || $(basename $0)/cleanup-ns.sh $ns
    echo "✅ Namespace $ns deleted"
  else
    echo "⏩ Namespace $ns preserved"
  fi
  echo
}

# --- Runner chart cleanup ---
INSTALLATION_NAME=$(prompt "Helm release name for runner chart" "$DEFAULT_RUNNERSET_INSTALLATION_NAME")
NAMESPACE=$(prompt "Runners namespace" "$DEFAULT_RUNNERS_NAMESPACE")
SECRET_NAME=$(prompt "Kubernetes secret name" "$DEFAULT_SECRET_NAME")

helm_uninstall "$INSTALLATION_NAME" "$NAMESPACE"
delete_secret "$SECRET_NAME" "$NAMESPACE"
delete_namespace "$NAMESPACE"

# --- Controller chart cleanup ---
INSTALLATION_NAME=$(prompt "Helm release name for controller chart" "$DEFAULT_ARC_INSTALLATION_NAME")
NAMESPACE=$(prompt "Systems namespace (controller ns)" "$DEFAULT_ARC_NAMESPACE")

helm_uninstall "$INSTALLATION_NAME" "$NAMESPACE"
delete_namespace "$NAMESPACE"

echo "🎉 Uninstall complete."
