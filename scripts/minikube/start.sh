#!/bin/bash
set -eo pipefail

DEFAULTS="${1:-$(dirname "$0")/../../runners/qtile/defaults.sh}"
# shellcheck source=/dev/null
source "$DEFAULTS"

PROFILE="${DEFAULT_MINIKUBE_PROFILE:-prod}"
DRIVER="${MINIKUBE_DRIVER:-kvm2}"
CNI="${MINIKUBE_CNI:-}"
NODES="${MIN_NODES:-1}"
EXTRA="${MINIKUBE_EXTRA_ARGS:-}"

cni_arg=""
[[ -n "$CNI" ]] && cni_arg="--cni=$CNI"

nodes_arg=""
[[ "$NODES" -gt 1 ]] && nodes_arg="--nodes=$NODES"

if ! minikube status -p "$PROFILE" 2>/dev/null | grep -q "host: Running"; then
  # shellcheck disable=SC2086
  minikube start -p "$PROFILE" --keep-context \
    --driver="$DRIVER" \
    $cni_arg \
    $nodes_arg \
    $EXTRA
fi

echo "Monitoring Minikube status..."
while sleep 60; do
  if ! minikube status -p "$PROFILE" | grep -q "host: Running"; then
    echo "Minikube cluster is not running! Exiting to trigger restart..."
    exit 1
  fi
done
