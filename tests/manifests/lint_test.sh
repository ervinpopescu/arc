#!/bin/bash
set -euo pipefail

ROOT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
TEMP_DIR=$(mktemp -d)
trap 'rm -rf "$TEMP_DIR"' EXIT

FAKE_BIN="$TEMP_DIR/bin"
mkdir -p "$FAKE_BIN"
cat >"$FAKE_BIN/helm" <<'EOF'
#!/bin/bash
set -euo pipefail

case "${1:-}" in
    pull)
        shift
        destination=
        while (($#)); do
            if [[ "$1" == "-d" ]]; then
                destination=$2
                shift 2
            else
                shift
            fi
        done
        mkdir -p "$destination/gha-runner-scale-set"
        ;;
    lint)
        if [[ "${LINT_MODE:-failure}" == "warning" ]]; then
            echo "warning: cannot overwrite table with non table for githubConfigSecret"
            exit 0
        fi
        echo "warning: cannot overwrite table with non table for githubConfigSecret"
        echo "Error: invalid values"
        exit 1
        ;;
    template)
        ;;
    *)
        echo "unexpected helm command" >&2
        exit 2
        ;;
esac
EOF
chmod +x "$FAKE_BIN/helm"

run_lint() {
    local mode=$1
    local output=$2
    LINT_MODE="$mode" PATH="$FAKE_BIN:$PATH" "$ROOT_DIR/tests/manifests/lint.sh" >"$output" 2>&1
}

failure_output="$TEMP_DIR/failure-output"
if run_lint failure "$failure_output"; then
    cat "$failure_output"
    echo "lint wrapper accepted a Helm failure" >&2
    exit 1
fi
if grep -q "cannot overwrite table with non table for githubConfigSecret" "$failure_output"; then
    cat "$failure_output"
    echo "known Helm warning was not filtered" >&2
    exit 1
fi
grep -q "Error: invalid values" "$failure_output"

warning_output="$TEMP_DIR/warning-output"
if ! run_lint warning "$warning_output"; then
    cat "$warning_output"
    echo "lint wrapper rejected the known warning" >&2
    exit 1
fi
if grep -q "cannot overwrite table with non table for githubConfigSecret" "$warning_output"; then
    cat "$warning_output"
    echo "known Helm warning was not filtered" >&2
    exit 1
fi
grep -q "Manifests passed linting." "$warning_output"

echo "Lint wrapper regression checks passed."
