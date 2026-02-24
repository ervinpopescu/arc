# Configs for ARC

.PHONY: help build push deploy-base deploy-qtile undeploy-base undeploy-qtile cleanup-base cleanup-qtile

help:
	@echo "Usage: make [target]"
	@echo ""
	@echo "Targets:"
	@echo "  build            Build custom runner images"
	@echo "  push             Push custom runner images to GHCR"
	@echo "  deploy-base      Deploy base runner scale set"
	@echo "  deploy-qtile     Deploy qtile runner scale set"
	@echo "  undeploy-base    Undeploy base runner scale set"
	@echo "  undeploy-qtile   Undeploy qtile runner scale set"
	@echo "  cleanup-base     Force cleanup base-runners namespace"
	@echo "  cleanup-qtile    Force cleanup qtile-runners namespace"

build:
	./scripts/images/build_n_push.sh

push:
	./scripts/images/build_n_push.sh

deploy-base:
	./scripts/minikube/deploy.sh runners/base/defaults.sh

deploy-qtile:
	./scripts/minikube/deploy.sh runners/qtile/defaults.sh

undeploy-base:
	./scripts/minikube/undeploy.sh runners/base/defaults.sh

undeploy-qtile:
	./scripts/minikube/undeploy.sh runners/qtile/defaults.sh

cleanup-base:
	./scripts/minikube/cleanup-ns.sh base-runners

cleanup-qtile:
	./scripts/minikube/cleanup-ns.sh qtile-runners
