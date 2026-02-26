#!/bin/bash
set -eo pipefail

echo "🧪 Verifying cluster health..."

# Check ARC Controller
echo "Checking ARC Controller..."
kubectl get pods -n arc-systems -l app.kubernetes.io/name=gha-rs-controller | grep Running > /dev/null || (echo "❌ ARC Controller not running" && exit 1)

# Check Qtile Tools (PVC & Debug Pod)
echo "Checking Qtile tools..."
kubectl get pvc -n qtile-runners tool-cache-runnerset > /dev/null || (echo "❌ tool-cache PVC not found" && exit 1)
kubectl get pods -n qtile-runners debug | grep Running > /dev/null || (echo "❌ debug pod not running" && exit 1)

# Test PVC write access
echo "Testing PVC write access..."
kubectl -n qtile-runners exec debug -- bash -c "touch /opt/hostedtoolcache/.health-check && rm /opt/hostedtoolcache/.health-check" || (echo "❌ PVC write access failed" && exit 1)

echo "✅ Cluster health verified."
