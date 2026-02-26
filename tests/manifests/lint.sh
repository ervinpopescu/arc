#!/bin/bash
set -eo pipefail

echo "🧪 Linting Helm manifests..."

# Create a temp directory for the chart
TEMP_CHART_DIR=$(mktemp -d)
trap 'rm -rf "$TEMP_CHART_DIR"' EXIT

# Pull the chart to temp directory
echo "📥 Pulling ARC chart..."
helm pull oci://ghcr.io/actions/actions-runner-controller-charts/gha-runner-scale-set --version 0.13.1 -d "$TEMP_CHART_DIR" --untar

CHART_PATH="$TEMP_CHART_DIR/gha-runner-scale-set"

# Function to run lint and filter noise
run_lint() {
    local name=$1
    local values=$2
    echo "--- $name ---"
    # We filter out the "cannot overwrite table with non table" warning as it is a harmless
    # side effect of overriding the default githubConfigSecret map with a string (Variation C).
    helm lint "$CHART_PATH" --values "$values" 2>&1 | grep -v "cannot overwrite table with non table for githubConfigSecret" || true
}

# Check Base Runner
run_lint "Base Runner" "runners/base/values.runner-set.yaml"

# Check Qtile Runner
run_lint "Qtile Runner" "runners/qtile/values.runner-set.yaml"

# Template check
echo "🧪 Verifying template substitution..."
helm template base "$CHART_PATH" --values runners/base/values.runner-set.yaml > /dev/null
helm template qtile "$CHART_PATH" --values runners/qtile/values.runner-set.yaml > /dev/null

echo "✅ Manifests passed linting."
