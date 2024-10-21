# If you update this file, please follow:
# https://www.thapaliya.com/en/writings/well-documented-makefiles/

.DEFAULT_GOAL := help

# See https://stackoverflow.com/questions/11958626/make-file-warning-overriding-commands-for-target
%: %-default
	@ true

ifneq (,$(wildcard ./.env))
	include .env
	export
endif

# Output
TIME   = `date +%H:%M:%S`
BLUE   := $(shell printf "\033[34m")
YELLOW := $(shell printf "\033[33m")
RED    := $(shell printf "\033[31m")
GREEN  := $(shell printf "\033[32m")
CNone  := $(shell printf "\033[0m")
INFO = echo ${TIME} ${BLUE}[ INFO ]${CNone}
OK   = echo ${TIME} ${GREEN}[ OK ]${CNone}
ERR  = echo ${TIME} ${RED}[ ERR ]${CNone} "error:"

# Get the currently used golang install path (in GOPATH/bin, unless GOBIN is set)
ifeq (,$(shell go env GOBIN))
GOBIN=$(shell go env GOPATH)/bin
else
GOBIN=$(shell go env GOBIN)
endif
GOOS ?= $(shell go env GOOS)
GOARCH ?= $(shell go env GOARCH)

# CONTAINER_TOOL defines the container tool to be used for building images.
# Be aware that the target commands are only tested with Docker which is
# scaffolded by default. However, you might want to replace it to use other
# tools. (i.e. podman)
CONTAINER_TOOL ?= docker

# Setting SHELL to bash allows bash commands to be executed by recipes.
# Options are set to exit when a recipe line exits non-zero or a piped command fails.
SHELL = /usr/bin/env bash -o pipefail
.SHELLFLAGS = -ec

.PHONY: all
all: build

##@ General

# The help target prints out all targets with their descriptions organized
# beneath their categories. The categories are represented by '##@' and the
# target descriptions by '##'. The awk commands is responsible for reading the
# entire set of makefiles included in this invocation, looking for lines of the
# file as xyz: ## something, and then pretty-format the target and help. Then,
# if there's a line with ##@ something, that gets pretty-printed as a category.
# More info on the usage of ANSI control characters for terminal formatting:
# https://en.wikipedia.org/wiki/ANSI_escape_code#SGR_parameters
# More info on the awk command:
# http://linuxcommand.org/lc3_adv_awk.php

.PHONY: help
help: ## Display this help.
	@awk 'BEGIN {FS = ":.*##"; printf "\nUsage:\n  make \033[36m<target>\033[0m\n"} /^[a-zA-Z_0-9-]+:.*?##/ { printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2 } /^##@/ { printf "\n\033[1m%s\033[0m\n", substr($$0, 5) } ' $(MAKEFILE_LIST)

##@ Static Analysis

reviewable: manifests fmt vet lint reviewable-ext frigate ## Ensure code is ready for review
	git submodule update --remote
	go mod tidy

.PHONY: reviewable-ext-default
reviewable-ext-default: ## optional reviewability extension (to be overridden)
	@$(OK) reviewability extension no-op

check-diff: reviewable ## Execute auto-gen code commands and ensure branch is clean
	git --no-pager diff
	git diff --quiet || ($(ERR) please run 'make reviewable' to include all changes && false)
	@$(OK) branch is clean

.PHONY: fmt
fmt: ## Run go fmt against code.
	go fmt ./...

.PHONY: vet
vet: ## Run go vet against code.
	go vet ./...

.PHONY: lint
lint: golangci-lint ## Run golangci-lint linter
	$(GOLANGCI_LINT) run

.PHONY: frigate
frigate-default: ## optional frigate command (to be overridden)
	@$(OK) frigate (no-op)

##@ Test

.PHONY: test-default
test-default: manifests generate fmt vet envtest helm setup-validator ## Run tests.
	IS_TEST=true KUBEBUILDER_ASSETS="$(shell $(ENVTEST) use $(ENVTEST_K8S_VERSION) --bin-dir $(LOCALBIN) -p path)" go test ./... -coverprofile cover.out

.PHONY: coverage-default
coverage-default: ## Show global test coverage
	go tool cover -func cover.out

.PHONY: coverage-html-default
coverage-html-default: ## Open global test coverage report in your browser
	go tool cover -html cover.out

.PHONY: setup-validator
setup-validator:
	@if [ ! -d ../validator ]; then \
		git clone https://github.com/validator-labs/validator ../validator; \
	fi

##@ Dependencies

## Location to install dependencies to
LOCALBIN ?= $(shell pwd)/bin
$(LOCALBIN):
	mkdir -p $(LOCALBIN)

export PATH := $(PATH):$(RUNNER_TOOL_CACHE):$(LOCALBIN)

## Tool Binaries
CONTROLLER_GEN ?= $(LOCALBIN)/controller-gen-$(CONTROLLER_TOOLS_VERSION)
ENVTEST ?= $(LOCALBIN)/setup-envtest-$(ENVTEST_VERSION)
GOCOVMERGE ?= $(LOCALBIN)/gocovmerge-$(GOCOVMERGE_VERSION)
GOLANGCI_LINT ?= $(LOCALBIN)/golangci-lint-$(GOLANGCI_LINT_VERSION)
HELM = $(LOCALBIN)/helm-$(HELM_VERSION)
HELMIFY ?= $(LOCALBIN)/helmify
KIND_VERSION ?= 0.20.0
KUBECTL_VERSION ?= 1.24.10
KUBECTL ?= kubectl
KUSTOMIZE ?= $(LOCALBIN)/kustomize-$(KUSTOMIZE_VERSION)

## Tool Versions
CONTROLLER_TOOLS_VERSION ?= v0.16.4
ENVTEST_VERSION ?= release-0.18
ENVTEST_K8S_VERSION ?= 1.27.1
GOCOVMERGE_VERSION ?= latest
GOLANGCI_LINT_VERSION ?= v1.60.3
HELM_VERSION ?= v3.14.0
KUSTOMIZE_VERSION ?= v5.2.1

.PHONY: controller-gen
controller-gen: $(CONTROLLER_GEN) ## Download controller-gen locally if necessary.
$(CONTROLLER_GEN): $(LOCALBIN)
	$(call go-install-tool,$(CONTROLLER_GEN),sigs.k8s.io/controller-tools/cmd/controller-gen,$(CONTROLLER_TOOLS_VERSION))

.PHONY: envtest
envtest: $(ENVTEST) ## Download setup-envtest locally if necessary.
$(ENVTEST): $(LOCALBIN)
	$(call go-install-tool,$(ENVTEST),sigs.k8s.io/controller-runtime/tools/setup-envtest,$(ENVTEST_VERSION))

.PHONY: gocovmerge
gocovmerge: $(GOCOVMERGE) ## Download gocovmerge locally if necessary.
$(GOCOVMERGE): $(LOCALBIN)
	$(call go-install-tool,$(GOCOVMERGE),github.com/wadey/gocovmerge,${GOCOVMERGE_VERSION})

.PHONY: golangci-lint
golangci-lint: $(GOLANGCI_LINT) ## Download golangci-lint locally if necessary.
$(GOLANGCI_LINT): $(LOCALBIN)
	$(call go-install-tool,$(GOLANGCI_LINT),github.com/golangci/golangci-lint/cmd/golangci-lint,${GOLANGCI_LINT_VERSION})

HELM_INSTALLER ?= "https://get.helm.sh/helm-$(HELM_VERSION)-$(GOOS)-$(GOARCH).tar.gz"
.PHONY: helm
helm: $(HELM) ## Download helm locally if necessary.
$(HELM): $(LOCALBIN)
	[ -e "$(HELM)" ] && rm -rf "$(HELM)" || true
	cd $(LOCALBIN) && curl -s $(HELM_INSTALLER) | tar -xzf - -C $(LOCALBIN)
	mv $(LOCALBIN)/$(GOOS)-$(GOARCH)/helm $(HELM) && rm -rf $(LOCALBIN)/$(GOOS)-$(GOARCH)
	ln -sf $(HELM) $(LOCALBIN)/helm

.PHONY: kind
kind:
	@if [ "$(GITHUB_ACTIONS)" = "true" ]; then \
		@command -v kind >/dev/null 2>&1 || { \
			echo "Kind not found, downloading..."; \
			curl -Lo $(RUNNER_TOOL_CACHE)/kind https://github.com/kubernetes-sigs/kind/releases/download/v$(KIND_VERSION)/kind-$(GOOS)-$(GOARCH); \
			chmod +x $(RUNNER_TOOL_CACHE)/kind; \
		} \
	fi

.PHONY: kubectl
kubectl:
	@if [ "$(GITHUB_ACTIONS)" = "true" ]; then \
		@command -v kubectl >/dev/null 2>&1 || { \
			echo "Kubectl not found, downloading..."; \
			curl -Lo $(RUNNER_TOOL_CACHE)/kubectl https://dl.k8s.io/release/v$(KUBECTL_VERSION)/bin/$(GOOS)/$(GOARCH)/kubectl; \
			chmod +x $(RUNNER_TOOL_CACHE)/kubectl; \
		} \
	fi

.PHONY: kustomize
kustomize: $(KUSTOMIZE) ## Download kustomize locally if necessary.
$(KUSTOMIZE): $(LOCALBIN)
	$(call go-install-tool,$(KUSTOMIZE),sigs.k8s.io/kustomize/kustomize/v5,$(KUSTOMIZE_VERSION))

# go-install-tool will 'go install' any package with custom target and name of binary, if it doesn't exist
# $1 - target path with name of binary (ideally with version)
# $2 - package url which can be installed
# $3 - specific version of package
define go-install-tool
@[ -f $(1) ] || { \
set -e; \
package=$(2)@$(3) ;\
echo "Downloading $${package}" ;\
GOBIN=$(LOCALBIN) go install $${package} ;\
mv -f "$$(echo "$(1)" | sed "s/-$(3)$$//")" $(1) ;\
}
endef