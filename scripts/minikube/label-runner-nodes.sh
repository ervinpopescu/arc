#!/bin/bash
set -euo pipefail

PROFILE="${1:-prod}"

if ! kubectl --context "$PROFILE" get nodes >/dev/null 2>&1; then
  echo "ERROR: cluster '$PROFILE' is not reachable." >&2
  exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "ERROR: jq is required to inspect node labels." >&2
  exit 1
fi

nodes=$(kubectl --context "$PROFILE" get nodes -o name)
if [[ -z "$nodes" ]]; then
  echo "ERROR: no nodes found in cluster '$PROFILE'." >&2
  exit 1
fi

while IFS= read -r node; do
  [[ -z "$node" ]] && continue
  name="${node#node/}"
  node_json=$(kubectl --context "$PROFILE" get "$node" -o json)
  is_control_plane=0
  if jq -e '.metadata.labels // {} | has("node-role.kubernetes.io/control-plane")' <<<"$node_json" >/dev/null; then
    is_control_plane=1
  fi
  role=$(jq -r '.metadata.labels["node-role"] // ""' <<<"$node_json")

  if ((is_control_plane)); then
    if [[ "$role" != "system" ]]; then
      kubectl --context "$PROFILE" label node "$name" node-role=system --overwrite
    fi
  elif [[ "$role" != "system" && "$role" != "worker" ]]; then
    kubectl --context "$PROFILE" label node "$name" node-role=worker --overwrite
  fi
done <<< "$nodes"
