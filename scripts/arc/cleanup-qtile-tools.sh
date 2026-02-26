#!/bin/bash
set -eo pipefail

NAMESPACE="qtile-runners"
POD_NAME="debug"

read -rp "⚠️  Are you sure you want to delete ALL data in /opt/hostedtoolcache and remove the debug pod? [y/N]: " confirm
if [[ "${confirm,,}" != "y" ]]; then
  echo "❌ Cleanup cancelled."
  exit 0
fi

echo "🧹 Cleaning up Qtile tools data..."

# Check if debug pod is running to perform cleanup
if kubectl -n "$NAMESPACE" get pod "$POD_NAME" >/dev/null 2>&1; then
    echo "🗑️  Clearing /opt/hostedtoolcache contents..."
    kubectl -n "$NAMESPACE" exec "$POD_NAME" -- bash -c "rm -rf /opt/hostedtoolcache/*"
    echo "🐞 Deleting debug pod..."
    kubectl -n "$NAMESPACE" delete pod "$POD_NAME"
    echo "✅ Data cleanup finished."
else
    echo "⚠️  Debug pod not found. Cannot clean persistent data safely."
    echo "💡 Start the tools first or use a temporary pod to clear the PVC."
fi
