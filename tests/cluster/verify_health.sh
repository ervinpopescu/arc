#!/bin/bash
set -eo pipefail

echo " Verifying cluster health..."

# Check ARC Controller
echo "Checking ARC Controller..."
kubectl get pods -n arc-systems -l app.kubernetes.io/name=gha-rs-controller | grep Running >/dev/null || (echo " ARC Controller not running" && exit 1)

# Check Runner Listener Pods
echo "Checking Runner Listener pods..."
listeners=$(kubectl get pods -n arc-systems -l app.kubernetes.io/component=runner-scale-set-listener --no-headers -o custom-columns=NAME:.metadata.name,STATUS:.status.phase 2>/dev/null || true)
if [[ -z "$listeners" ]]; then
  echo " No runner listener pods found in arc-systems" && exit 1
fi
while read -r name status; do
  if [[ "$status" != "Running" ]]; then
    echo " Runner listener '$name' is not Running (status: $status)" && exit 1
  fi
done <<<"$listeners"

# Check scale set ID alignment
echo "Checking scale set ID consistency..."
for rs in $(kubectl get autoscalingrunnerset -A -o jsonpath="{range .items[*]}{.metadata.namespace}{\"/\"}{.metadata.name}{\" \"}{end}"); do
  ns="${rs%%/*}"
  name="${rs##*/}"
  expected_id=$(kubectl get autoscalingrunnerset -n "$ns" "$name" -o jsonpath="{.metadata.annotations.runner-scale-set-id}" 2>/dev/null || true)
  if [[ -n "$expected_id" ]]; then
    ephemeral_id=$(kubectl get ephemeralrunnerset -n "$ns" -o jsonpath="{.items[0].spec.ephemeralRunnerSpec.runnerScaleSetId}" 2>/dev/null || true)
    if [[ -n "$ephemeral_id" && "$ephemeral_id" != "$expected_id" ]]; then
      echo " Desync detected in $ns/$name: AutoscalingRunnerSet ID=$expected_id but EphemeralRunnerSet ID=$ephemeral_id"
      echo "       To fix: kubectl delete ephemeralrunnerset -n $ns -l app.kubernetes.io/name=$name"
      exit 1
    fi
  fi
done

# Check Qtile Tools (PVC & Debug Pod)
echo "Checking Qtile tools..."
kubectl get pvc -n qtile-runners tool-cache-runnerset >/dev/null || (echo " tool-cache PVC not found" && exit 1)
kubectl get pods -n qtile-runners debug | grep Running >/dev/null || (echo " debug pod not running" && exit 1)

# Test PVC write access
echo "Testing PVC write access..."
kubectl -n qtile-runners exec debug -- bash -c "touch /opt/hostedtoolcache/.health-check && rm /opt/hostedtoolcache/.health-check" || (echo " PVC write access failed" && exit 1)

echo " Cluster health verified."
