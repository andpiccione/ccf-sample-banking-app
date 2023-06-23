SHELL := /bin/bash

.PHONY: help
.DEFAULT_GOAL := help

check_defined = \
    $(strip $(foreach 1,$1, \
        $(call __check_defined,$1,$(strip $(value 2)))))
__check_defined = \
    $(if $(value $1),, \
      $(error Undefined $1$(if $2, ($2))))

help: ## 💬 This help message :)
	@grep -E '[a-zA-Z_-]+:.*?## .*$$' $(firstword $(MAKEFILE_LIST)) | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'

lint: ## 🔍 Lint the code base (but don't fix)
	@echo -e "\e[34m$@\e[0m" || true
	@./scripts/lint.sh

lint-fix: ## 🌟 Lint and fix the code base
	@echo -e "\e[34m$@\e[0m" || true
	@./scripts/lint.sh -f

deploy-mccf: ## 🚀 Deploy Managed CCF
	@echo -e "\e[34m$@\e[0m" || true
	@cd deploy && /opt/ccf_virtual/bin/keygenerator.sh --name member0
	@cd deploy && pwsh ./New-ManagedCCF.ps1 -PEMFilename member0_cert.pem

deploy-ms-idp: ## 🔐 Create an Identity Provider
	@echo -e "\e[34m$@\e[0m" || true
	cd deploy && pwsh ./New-IdentityProvider.ps1

generate-access-token: ## 🔐 Generate and access token
	@echo -e "\e[34m$@\e[0m" || true
	./scripts/generate_access_token.sh

clean: ## 🧹 Clean the working folders created during build/demo
	@rm -rf .venv_ccf_sandbox
	@rm -rf workspace

build: ## 🔨 Build the Banking Application
	@echo -e "\e[34m$@\e[0m" || true
	@npm run build

build-virtual: build ## 📦 Build Virtual container image from Dockerfile
	@echo -e "\e[34m$@\e[0m" || true
	@./scripts/build_image.sh virtual

build-enclave: build ## 📦 Build Enclave container image from Dockerfile
	@echo -e "\e[34m$@\e[0m" || true
	@./scripts/build_image.sh enclave

test: build ## 🧪 Test the Banking Application in the sandbox
	@echo -e "\e[34m$@\e[0m" || true
	@. ./scripts/test_sandbox.sh --nodeAddress 127.0.0.1:8000 --certificate_dir ./workspace/sandbox_common  --constitution_dir ./governance/constitution

test-docker-virtual: build-virtual ## 🧪 Test the Banking Application in a Docker sandbox
	@echo -e "\e[34m$@\e[0m" || true
	@. ./scripts/test_docker.sh --virtual --serverIP 172.17.0.3 --port 8080

test-docker-enclave: build-enclave ## 🧪 Test the Banking Application in a Docker enclave
	@echo -e "\e[34m$@\e[0m" || true
	@. ./scripts/test_docker.sh --enclave --serverIP 172.17.0.4 --port 8080

test-mccf: build ## 🧪 Test the Banking Application in a Managed CCF environment
	@echo -e "\e[34m$@\e[0m" || true
	$(call check_defined, CCF_NAME)
	$(call check_defined, PUBLIC_CERT)
	$(call check_defined, PRIVATE_CERT)
	@. ./scripts/test_mccf.sh --address "${CCF_NAME}.confidential-ledger.azure.com" --signing-cert "${PUBLIC_CERT}" --signing-key "${PRIVATE_CERT}"

# Run sandbox. Consider 3 members as 3 banks.
# This is used in the demo scripts
start-host: build ## 🏁 Start the CCF Sandbox for the demo
	@echo -e "\e[34m$@\e[0m" || true
	@/opt/ccf_virtual/bin/sandbox.sh --js-app-bundle ./dist/ --initial-member-count 3 --initial-user-count 2 --constitution-dir ./governance/constitution

demo: ## 🎬 Demo the Banking Application
	@echo -e "\e[34m$@\e[0m" || true
	@./scripts/demo.sh
	@./scripts/show_app_log.sh

clean: ## 🧹 Clean the working folders created during build/demo
	@rm -rf .venv_ccf_sandbox
	@rm -rf .venv_ccf_verify_receipt
	@rm -rf workspace
	@rm -rf dist
