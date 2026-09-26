#!/bin/bash
set -euo pipefail

PROFILE="${1:-prod}"

if ! kubectl --context "$PROFILE" get nodes >/dev/null 2>&1; then
  echo "ERROR: cluster '$PROFILE' is not reachable." >&2
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
  is_control_plane=$(kubectl --context "$PROFILE" get "$node" \
    -o 'jsonpath={.metadata.labels.node-role\.kubernetes\.io/control-plane}')
  role=$(kubectl --context "$PROFILE" get "$node" -o 'jsonpath={.metadata.labels.node-role}')

  if [[ -n "$is_control_plane" ]]; then
    if [[ "$role" != "system" ]]; then
      kubectl --context "$PROFILE" label node "$name" node-role=system --overwrite
    fi
  elif [[ "$role" != "system" && "$role" != "worker" ]]; then
    kubectl --context "$PROFILE" label node "$name" node-role=worker --overwrite
  fi
done <<< "$nodes"
