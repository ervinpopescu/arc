# Configs for ARC

ifneq (,$(wildcard ./.env))
	include .env
	export
endif

.PHONY: help build push ensure-cluster harden-ssh deploy-base deploy-qtile deploy-monitoring deploy-vpa deploy-infra get-vpa-recommendations undeploy-base undeploy-qtile cleanup-base cleanup-qtile cleanup-qtile-tools test-images test-manifests test-cluster test-all pre-commit

help:
	@echo "Usage: make [target]"
	@echo ""
	@echo "Targets:"
	@echo "  build                     Build custom runner images"
	@echo "  push                      Push custom runner images to GHCR"
	@echo "  ensure-cluster            Start minikube cluster if not running (uses DEFAULTS=<path>)"
	@echo "  harden-ssh                Disable OpenSSH PerSourcePenalties on minikube nodes"
	@echo "  deploy-base               Deploy base runner scale set"
	@echo "  deploy-qtile              Deploy qtile runner scale set"
	@echo "  deploy-monitoring         Deploy lightweight Prometheus and VPA"
	@echo "  deploy-vpa-crds           Install VPA CRDs"
	@echo "  deploy-vpa                Apply VPA RBAC (runner policies applied by deploy scripts)"
	@echo "  deploy-infra              Deploy monitoring, VPA CRDs, and VPA RBAC"
	@echo "  get-vpa-recommendations   View current VPA resource suggestions"
	@echo "  undeploy-base             Undeploy base runner scale set"
	@echo "  undeploy-qtile            Undeploy qtile runner scale set"
	@echo "  cleanup-base              Force cleanup base-runners namespace"
	@echo "  cleanup-qtile             Force cleanup qtile-runners namespace"
	@echo "  cleanup-qtile-tools       Clear persistent data and remove debug pod"
	@echo "  test-images               Verify binaries and permissions in custom images"
	@echo "  test-manifests            Lint and template Helm manifests"
	@echo "  test-cluster              Verify live cluster state and PVC access"
	@echo "  test-all                  Run all automated tests"
	@echo "  pre-commit                Run pre-commit hooks on all files"

build:
	./scripts/images/build_n_push.sh

push:
	./scripts/images/build_n_push.sh --push

DEFAULTS ?= runners/qtile/defaults.sh

ensure-cluster:
	@bash -c 'source $(DEFAULTS) && \
	  profile=$${DEFAULT_MINIKUBE_PROFILE:-prod} && \
	  if ! minikube status -p "$$profile" 2>/dev/null | grep -q Running; then \
	    nodes_arg=""; \
	    [[ "$${MIN_NODES:-1}" -gt 1 ]] && nodes_arg="--nodes=$${MIN_NODES}"; \
	    minikube start -p "$$profile" \
	      --driver="$${MINIKUBE_DRIVER:-kvm2}" \
	      --cni="$${MINIKUBE_CNI:-calico}" \
	      $$nodes_arg \
	      $${MINIKUBE_EXTRA_ARGS:-}; \
	  fi && \
	  echo "Labeling nodes..." && \
	  kubectl label node "$$profile" node-role=system --overwrite && \
	  for node in $$(kubectl get nodes --no-headers -o custom-columns=NAME:.metadata.name | grep -v "^$$profile$$"); do \
	    kubectl label node "$$node" node-role=worker --overwrite; \
	  done && \
	  DEFAULT_MINIKUBE_PROFILE="$$profile" ./scripts/minikube/harden-ssh.sh'

# Disable OpenSSH PerSourcePenalties on every minikube node.  Safe to re-run.
# ensure-cluster already calls this internally; the standalone target lets
# users run it ad-hoc if a node was recreated outside of `make ensure-cluster`.
harden-ssh:
	@bash -c 'source $(DEFAULTS) && \
	  DEFAULT_MINIKUBE_PROFILE="$${DEFAULT_MINIKUBE_PROFILE:-prod}" ./scripts/minikube/harden-ssh.sh'

deploy-monitoring:
	kubectl apply -f runners/base/manifests/prometheus-lite.yaml
	minikube addons enable metrics-server -p prod

deploy-vpa-crds:
	kubectl apply -f https://raw.githubusercontent.com/kubernetes/autoscaler/master/vertical-pod-autoscaler/deploy/vpa-v1-crd-gen.yaml

deploy-vpa:
	kubectl apply -f runners/base/manifests/vpa-rbac.yaml

deploy-infra: ensure-cluster deploy-monitoring deploy-vpa-crds deploy-vpa

get-vpa-recommendations:
	kubectl get vpa -A

cleanup-qtile-tools:
	./scripts/arc/cleanup-qtile-tools.sh

test-images:
	chmod +x tests/images/test_images.sh
	./tests/images/test_images.sh

test-manifests:
	chmod +x tests/manifests/lint.sh
	./tests/manifests/lint.sh

test-cluster:
	chmod +x tests/cluster/verify_health.sh
	./tests/cluster/verify_health.sh

test-all: test-manifests test-images

pre-commit:
	pre-commit run --all-files

deploy-base: deploy-infra
	./scripts/minikube/deploy.sh runners/base/defaults.sh

deploy-qtile: deploy-infra
	./scripts/minikube/deploy.sh runners/qtile/defaults.sh
	./scripts/arc/setup-qtile-tools.sh

undeploy-base:
	./scripts/minikube/undeploy.sh runners/base/defaults.sh

undeploy-qtile:
	./scripts/minikube/undeploy.sh runners/qtile/defaults.sh

cleanup-base:
	./scripts/minikube/cleanup-ns.sh base-runners

cleanup-qtile:
	./scripts/minikube/cleanup-ns.sh qtile-runners
