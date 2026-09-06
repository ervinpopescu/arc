#!/bin/bash
set -eo pipefail

DEFAULTS="${1:-$(dirname "$0")/../../runners/qtile/defaults.sh}"
# shellcheck source=/dev/null
source "$DEFAULTS"

export MINIKUBE_HOME="${MINIKUBE_HOME:-${XDG_DATA_HOME:-$HOME/.local/share}/minikube}"

PROFILE="${DEFAULT_MINIKUBE_PROFILE:-prod}"
DRIVER="${MINIKUBE_DRIVER:-kvm2}"
CNI="${MINIKUBE_CNI:-}"
NODES="${MIN_NODES:-1}"
EXTRA="${MINIKUBE_EXTRA_ARGS:-}"

cni_arg=""
[[ -n "$CNI" ]] && cni_arg="--cni=$CNI"

nodes_arg=""
[[ "$NODES" -gt 1 ]] && nodes_arg="--nodes=$NODES"

ensure_kvm2_acls() {
  local driver="${DRIVER:-${MINIKUBE_DRIVER:-kvm2}}"
  if [[ "$driver" != "kvm2" ]]; then
    return 0
  fi

  if ! command -v setfacl &>/dev/null; then
    return 0
  fi

  local qemu_user=""
  if id "libvirt-qemu" &>/dev/null; then
    qemu_user="libvirt-qemu"
  elif id "qemu" &>/dev/null; then
    qemu_user="qemu"
  else
    return 0
  fi

  local minikube_home="${MINIKUBE_HOME:-${XDG_DATA_HOME:-$HOME/.local/share}/minikube}"
  mkdir -p "$minikube_home" 2>/dev/null || true

  local curr
  curr="$(readlink -f "$minikube_home" 2>/dev/null || echo "$minikube_home")"
  local home_dir
  home_dir="$(readlink -f "$HOME" 2>/dev/null || echo "$HOME")"

  while [[ -n "$curr" && "$curr" != "/" && "$curr" != "$home_dir" ]]; do
    if [[ -d "$curr" ]]; then
      setfacl -m "u:${qemu_user}:x,m:x" "$curr" 2>/dev/null || true
    fi
    curr="$(dirname "$curr")"
  done
}

ensure_kvm2_acls

if ! (minikube status -p "$PROFILE" 2>/dev/null || true) | grep -q "host: Running"; then
  # shellcheck disable=SC2086
  minikube start -p "$PROFILE" --keep-context \
    --driver="$DRIVER" \
    $cni_arg \
    $nodes_arg \
    $EXTRA
  "$(dirname "$0")/harden-ssh.sh" || true
fi

echo "Monitoring Minikube status..."
while sleep 60; do
  if ! (minikube status -p "$PROFILE" 2>/dev/null || true) | grep -q "host: Running"; then
    echo "Minikube cluster is not running! Exiting to trigger restart..."
    exit 1
  fi
done
