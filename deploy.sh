#!/bin/bash

set -e

function read_var_q() {
  echo -n $1:
  read -rs $2
  echo
}

function read_var() {
  echo -n $1:
  echo
  read -r $2
  echo
}

read_var "helm release name for controller chart" "INSTALLATION_NAME"
[ -z "$INSTALLATION_NAME" ] && INSTALLATION_NAME="arc"

read_var "systems namespace (controller ns)" "NAMESPACE"
[ -z "$NAMESPACE" ] && NAMESPACE="arc-systems"

set -x
helm install "${INSTALLATION_NAME}" \
  --namespace "${NAMESPACE}" \
  --create-namespace \
  oci://ghcr.io/actions/actions-runner-controller-charts/gha-runner-scale-set-controller
set +x

read_var "helm release name for runner chart" "INSTALLATION_NAME"
[ -z "$INSTALLATION_NAME" ] && INSTALLATION_NAME="arc-runner-set"

read_var "runners namespace" "NAMESPACE"
[ -z "$NAMESPACE" ] && NAMESPACE="arc-runners"

set -x
kubectl get ns | grep -q "$NAMESPACE" || kubectl create ns "${NAMESPACE}"
set +x

read_var_q "GitHub PAT" "TOKEN"

kubectl create secret generic pre-defined-secret \
  --namespace="${NAMESPACE}" \
  --from-literal=github_token="$TOKEN"

read_var "Overrides path" "OVERRIDES_PATH"
[ -z "$OVERRIDES_PATH" ] && OVERRIDES_PATH="values.runner-set.yaml"

set -x
helm install "${INSTALLATION_NAME}" \
  --namespace "${NAMESPACE}" \
  --values "$OVERRIDES_PATH" \
  oci://ghcr.io/actions/actions-runner-controller-charts/gha-runner-scale-set
set +x
