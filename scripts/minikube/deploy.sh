#!/bin/bash
set -eo pipefail

if [[ "$1" == "" ]]; then
  echo "Usage: $(basename "$0") <path to defaults.sh>"
  exit 1
fi

# shellcheck source=/dev/null
source "$1"

# Load local .env if it exists in the project root
if [[ -f ".env" ]]; then
  echo " Loading environment variables from .env..."
  # shellcheck disable=SC2046
  export $(grep -v '^#' .env | xargs)
fi

# --- Unbound DNS setup ---
setup_unbound() {
  local conf_src
  conf_src="$(dirname "$0")/configs/unbound.conf"
  local conf_dst="/etc/unbound/unbound.conf.d/minikube.conf"

  echo "Setting up unbound DNS..."

  if ! command -v unbound &>/dev/null; then
    echo "   Installing unbound..."
    sudo pacman -S --noconfirm unbound
  fi

  if [[ ! -f "$conf_src" ]]; then
    echo "   Unbound config not found at $conf_src"
    return 1
  fi

  sudo mkdir -p /etc/unbound/unbound.conf.d

  if diff -q "$conf_src" "$conf_dst" &>/dev/null; then
    if systemctl is-active --quiet unbound; then
      echo "   Unbound already configured and running. Skipping."
      echo
      return
    fi
  fi

  echo "   Writing unbound config..."
  sudo cp "$conf_src" "$conf_dst"

  # Ensure the main unbound.conf includes the conf.d directory
  if ! sudo grep -q "include-toplevel.*unbound.conf.d" /etc/unbound/unbound.conf; then
    echo 'include-toplevel: "/etc/unbound/unbound.conf.d/*.conf"' | sudo tee -a /etc/unbound/unbound.conf >/dev/null
  fi

  sudo systemctl enable --now unbound
  sudo systemctl restart unbound

  # Verify it's listening on the minikube bridge
  sleep 1
  if ss -ulnp | grep -q "192.168.49.1:53"; then
    echo "   Unbound listening on 192.168.49.1:53"
  else
    echo "    Unbound may not be listening on 192.168.49.1:53 — check: systemctl status unbound"
  fi
  echo
}

# --- Cluster bootstrap ---
ensure_cluster() {
  local profile="${DEFAULT_MINIKUBE_PROFILE:-prod}"
  local driver="${MINIKUBE_DRIVER:-qemu2}"
  local cni="${MINIKUBE_CNI:-calico}"
  if minikube status -p "$profile" 2>/dev/null | grep -q "Running"; then
    echo "Cluster '$profile' already running. Skipping start."
    echo
    return
  fi

  echo "Starting minikube cluster (profile: $profile, driver: $driver, cni: $cni)..."

  local extra_args="${MINIKUBE_EXTRA_ARGS:-}"
  # shellcheck disable=SC2086
  minikube start -p "$profile" --driver="$driver" --cni="$cni" $extra_args
  echo
}

# --- Multi-node setup ---
ensure_nodes() {
  local desired="${MIN_NODES:-1}"
  local profile="${DEFAULT_MINIKUBE_PROFILE:-prod-docker}"
  local cni="${MINIKUBE_CNI:-}"

  if [[ "$desired" -le 1 ]]; then
    return
  fi

  if [[ -z "$cni" ]]; then
    echo "ERROR: MIN_NODES=$desired requires MINIKUBE_CNI to be set (e.g. calico, flannel, cilium)."
    echo "       Cross-node pod networking does not work with the default kindnet CNI."
    exit 1
  fi

  echo "Ensuring minikube has $desired node(s) (profile: $profile, CNI: $cni)..."

  # Verify the running cluster was started with a compatible CNI by checking for the CNI daemonset.
  if ! kubectl get daemonset -n kube-system 2>/dev/null | grep -qi "$cni"; then
    echo "WARNING: CNI daemonset for '$cni' not found in kube-system."
    echo "         If this cluster was started without --cni=$cni, cross-node networking may fail."
    echo "         To fix: minikube delete -p $profile && minikube start -p $profile --cni=$cni"
    echo
  fi

  local current
  current=$(minikube node list -p "$profile" 2>/dev/null | grep -c "." || true)

  while [[ "$current" -lt "$desired" ]]; do
    echo "   Adding node $((current + 1))..."
    minikube node add -p "$profile"
    ((current++))
  done

  echo "   Node count: $current"
  echo
}

setup_unbound
ensure_cluster
ensure_nodes

# --- Helm registry auth ---
if [[ -n "$GITHUB_TOKEN" ]]; then
  echo "Logging into ghcr.io for Helm..."
  echo "$GITHUB_TOKEN" | helm registry login ghcr.io --username "$(git config user.name 2>/dev/null || echo x-token)" --password-stdin 2>&1
  echo
fi

# Ensure helm-diff plugin is installed
if ! helm plugin list | grep -q "diff"; then
  echo " Installing helm-diff plugin..."
  helm plugin install https://github.com/databus23/helm-diff --verify=false
fi

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

# Helm wrapper for idempotent installs with change detection
helm_install() {
  local name=$1 ns=$2 chart=$3 values=${4:-} extra_args=${5:-}

  echo "Checking release: $name in namespace: $ns"

  if helm status "$name" -n "$ns" >/dev/null 2>&1; then
    if [[ "$FORCE_UPGRADE" == "true" ]]; then
      echo "  Forcing upgrade as requested..."
    else
      # Check for changes using helm-diff
      echo "  Checking for changes..."
      # shellcheck disable=SC2086
      if helm diff upgrade "$name" "$chart" \
        --namespace "$ns" \
        ${values:+--values "$values"} \
        $extra_args \
        --detailed-exitcode >/dev/null 2>&1; then
        echo "   No changes detected. Skipping upgrade."
        echo
        return
      fi
      echo "   Changes detected. Upgrading..."
    fi
  else
    echo "   Release does not exist. Installing..."
  fi

  echo "  Chart: $chart"
  if [[ -n "$values" ]]; then
    echo "  Values: $values"
  fi

  # shellcheck disable=SC2086
  helm upgrade --install "$name" \
    --namespace "$ns" \
    --create-namespace \
    ${values:+--values "$values"} \
    "$chart" \
    --wait \
    --timeout 15m0s \
    $extra_args
  echo
}

# --- CoreDNS configuration ---
configure_coredns() {
  echo "Configuring CoreDNS..."

  # Derive the host gateway IP from the minikube profile's network
  local profile="${DEFAULT_MINIKUBE_PROFILE:-prod}"
  local gateway
  gateway=$(minikube ssh -p "$profile" -- ip route show default 2>/dev/null | awk '/default/ {print $3; exit}')
  if [[ -z "$gateway" ]]; then
    echo "   Could not determine minikube gateway IP. Skipping CoreDNS config."
    echo
    return
  fi

  local current
  current=$(kubectl get configmap coredns -n kube-system -o jsonpath='{.data.Corefile}')

  local needs_update=false
  echo "$current" | grep -q "prefetch 10" || needs_update=true

  if [[ "$needs_update" == "false" ]]; then
    echo "   CoreDNS already configured. Skipping."
    echo
    return
  fi

  echo "   Applying CoreDNS changes (gateway: $gateway)..."
  kubectl get configmap coredns -n kube-system -o json \
    | python3 -c "
import json, sys, re
cm = json.load(sys.stdin)
cf = cm['data']['Corefile']
gateway = sys.argv[1]
# Replace forward block (with or without existing options block)
cf = re.sub(
  r'forward\s+\.\s+\S+(\s*\{[^}]*\})?',
  'forward . ' + gateway + ' {\n        max_concurrent 1000\n    }',
  cf,
  flags=re.DOTALL
)
# Replace cache block
cf = re.sub(
  r'cache\s+\d+(\s*\{[^}]*\})?',
  'cache 3600 {\n        disable success cluster.local\n        disable denial cluster.local\n        prefetch 10\n    }',
  cf,
  flags=re.DOTALL
)
cm['data']['Corefile'] = cf
print(json.dumps(cm))
" "$gateway" | kubectl apply -f -

  kubectl rollout restart deployment/coredns -n kube-system
  kubectl rollout status deployment/coredns -n kube-system --timeout=60s
  echo
}

configure_coredns

# --- Controller chart ---
INSTALLATION_NAME=$(prompt "Helm release name for controller chart" "$DEFAULT_ARC_INSTALLATION_NAME" "INSTALLATION_NAME")
NAMESPACE=$(prompt "Systems namespace (controller ns)" "$DEFAULT_ARC_NAMESPACE" "NAMESPACE")

helm_install "$INSTALLATION_NAME" "$NAMESPACE" \
  oci://ghcr.io/actions/actions-runner-controller-charts/gha-runner-scale-set-controller \
  "" \
  "--set nodeSelector.node-role=system"

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

# --- Dynamic VPA Deployment (Shadow Deployment Workaround) ---
echo " Deploying VPA Shadow Deployment for $RUNNER_INSTALLATION_NAME..."

kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ${RUNNER_INSTALLATION_NAME}-vpa-shadow
  namespace: ${RUNNER_NAMESPACE}
spec:
  replicas: 0
  selector:
    matchLabels:
      actions.github.com/scale-set-name: ${RUNNER_INSTALLATION_NAME}
      app.kubernetes.io/component: runner
  template:
    metadata:
      labels:
        actions.github.com/scale-set-name: ${RUNNER_INSTALLATION_NAME}
        app.kubernetes.io/component: runner
    spec:
      nodeSelector:
        node-role: worker
      containers:
        - name: runner
          image: busybox
EOF

echo " Deploying VPA targeting Shadow Deployment..."
export RUNNER_INSTALLATION_NAME RUNNER_NAMESPACE
envsubst < "./runners/base/manifests/vpa-runners.yaml" | kubectl apply -f -

# kubectl apply -f "$TOOLCACHE_PVC_YAML"

# # --- Prometheus stack ---
# # We use a temporary file for the prometheus values since it was just a --set flag before
# # but to use the comparison logic we need a file or we just skip comparison.
# # For simplicity, we just refactor it to use helm_install with no values file which will skip if already deployed.
# helm_install "prom-stack" "monitoring" \
#   "oci://ghcr.io/prometheus-community/charts/kube-prometheus-stack" \
#   "" \
#   "--set grafana.enabled=false"
