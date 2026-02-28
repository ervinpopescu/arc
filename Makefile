# Configs for ARC

ifneq (,$(wildcard ./.env))
	include .env
	export
endif

.PHONY: help build push deploy-base deploy-qtile deploy-monitoring get-vpa-recommendations undeploy-base undeploy-qtile cleanup-base cleanup-qtile cleanup-qtile-tools test-images test-manifests test-cluster test-all

help:
	@echo "Usage: make [target]"
	@echo ""
	@echo "Targets:"
	@echo "  build                     Build custom runner images"
	@echo "  push                      Push custom runner images to GHCR"
	@echo "  deploy-base               Deploy base runner scale set"
	@echo "  deploy-qtile              Deploy qtile runner scale set"
	@echo "  deploy-monitoring         Deploy lightweight Prometheus and VPA"
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

build:
	./scripts/images/build_n_push.sh

push:
	./scripts/images/build_n_push.sh --push

deploy-monitoring:
	sudo kubectl apply -f runners/base/manifests/prometheus-lite.yaml
	sudo minikube addons enable metrics-server -p prod-docker

deploy-vpa:
	kubectl apply -f runners/base/manifests/vpa-runners.yaml

deploy-infra: deploy-monitoring deploy-vpa

get-vpa-recommendations:
	sudo kubectl get vpa -A

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

deploy-base:
	./scripts/minikube/deploy.sh runners/base/defaults.sh

deploy-qtile:
	./scripts/arc/setup-qtile-tools.sh
	./scripts/minikube/deploy.sh runners/qtile/defaults.sh

undeploy-base:
	./scripts/minikube/undeploy.sh runners/base/defaults.sh

undeploy-qtile:
	./scripts/minikube/undeploy.sh runners/qtile/defaults.sh

cleanup-base:
	./scripts/minikube/cleanup-ns.sh base-runners

cleanup-qtile:
	./scripts/minikube/cleanup-ns.sh qtile-runners
