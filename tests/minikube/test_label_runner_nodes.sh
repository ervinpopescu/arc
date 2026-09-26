#!/bin/bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/../.." && pwd)"
tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT
export LABEL_LOG="$tmpdir/labels"
: > "$LABEL_LOG"

cat > "$tmpdir/kubectl" <<'MOCK'
#!/bin/bash
set -euo pipefail
shift 2 # --context profile
case "$1 $2" in
  "get nodes")
    printf 'node/prod\nnode/prod-m02\nnode/already-worker\nnode/other-system\n'
    ;;
  "get node/prod")
    printf '%s\n' '{"metadata":{"labels":{"node-role.kubernetes.io/control-plane":"","node-role":"system"}}}'
    ;;
  "get node/prod-m02")
    printf '%s\n' '{"metadata":{"labels":{}}}'
    ;;
  "get node/already-worker")
    printf '%s\n' '{"metadata":{"labels":{"node-role":"worker"}}}'
    ;;
  "get node/other-system")
    printf '%s\n' '{"metadata":{"labels":{"node-role":"system"}}}'
    ;;
  "label node")
    printf '%s\n' "$*" >> "$LABEL_LOG"
    ;;
  *)
    echo "Unexpected kubectl arguments: $*" >&2
    exit 1
    ;;
esac
MOCK
chmod +x "$tmpdir/kubectl"
PATH="$tmpdir:$PATH" "$repo_root/scripts/minikube/label-runner-nodes.sh" prod

grep -Fx 'label node prod-m02 node-role=worker --overwrite' "$LABEL_LOG" >/dev/null
grep -Fx 'label node prod node-role=system --overwrite' "$LABEL_LOG" >/dev/null && {
  echo "Existing system role should not be rewritten" >&2
  exit 1
}
[[ $(wc -l < "$LABEL_LOG") -eq 1 ]]
echo "Runner node labeling tests passed."
