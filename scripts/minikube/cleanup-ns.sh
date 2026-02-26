#!/usr/bin/env bash
# Force-delete all unfinalized resources in a given namespace
# Usage: ./cleanup-namespace.sh <namespace>

set -euo pipefail

NAMESPACE="${1:-}"
if [[ -z "$NAMESPACE" ]]; then
  echo "Usage: $0 <namespace>"
  exit 1
fi

read -rp "⚠️  Are you sure you want to FORCE cleanup namespace '$NAMESPACE'? [y/N]: " confirm
if [[ "${confirm,,}" != "y" ]]; then
  echo "❌ Cleanup cancelled."
  exit 0
fi

echo "🔎 Checking for stuck resources in namespace: $NAMESPACE"

# Get all resource types (excluding non-namespaced types)
RESOURCE_TYPES=$(kubectl api-resources --verbs=list --namespaced -o name | tr '\n' ' ')

for resource in $RESOURCE_TYPES; do
  # Get all objects for this resource in the namespace
  objs=$(kubectl -n "$NAMESPACE" get "$resource" -o name --ignore-not-found)
  for obj in $objs; do
    # Check if it has finalizers
    finalizers=$(kubectl -n "$NAMESPACE" get "$obj" -o jsonpath='{.metadata.finalizers}' 2>/dev/null || true)
    if [[ -n "$finalizers" && "$finalizers" != "[]" ]]; then
      echo "⚠️  Removing finalizers from $obj"
      kubectl -n "$NAMESPACE" patch "$obj" --type=json -p='[{"op":"remove","path":"/metadata/finalizers"}]' || true
    fi
  done
done

echo "🧹 Deleting all remaining resources in $NAMESPACE..."
kubectl -n "$NAMESPACE" delete all --all --ignore-not-found
kubectl -n "$NAMESPACE" delete pvc --all --ignore-not-found
kubectl -n "$NAMESPACE" delete configmap --all --ignore-not-found
kubectl -n "$NAMESPACE" delete secret --all --ignore-not-found
kubectl -n "$NAMESPACE" delete serviceaccount --all --ignore-not-found

echo "✅ Cleanup complete for namespace: $NAMESPACE"
