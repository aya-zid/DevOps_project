SHELL := /usr/bin/env bash
APP_DIR := app
IMAGE ?= ghcr.io/aya-zid/devops_project:latest

.PHONY: help install precommit lint typecheck test build sbom scan verify kind-up kind-down demo

help:
	@printf '%s\n' \
		'install    Install application dependencies' \
		'precommit  Run the pre-commit hooks' \
		'lint       Run ESLint' \
		'typecheck  Run TypeScript checks' \
		'test       Run tests with coverage' \
		'build      Compile the application' \
		'sbom       Generate an SPDX SBOM with Syft' \
		'scan       Scan the repository with Trivy' \
		'verify     Verify an image signature' \
		'kind-up    Create the local kind cluster' \
		'kind-down  Delete the local kind cluster' \
		'demo       Run the Kyverno admission demo'

install:
	cd $(APP_DIR) && npm ci

precommit:
	pre-commit run --all-files

lint:
	cd $(APP_DIR) && npm run lint

typecheck:
	cd $(APP_DIR) && npm run typecheck

test:
	cd $(APP_DIR) && npm run test:coverage

build:
	cd $(APP_DIR) && npm run build

sbom:
	syft dir:. -o spdx-json=sbom.spdx.json

scan:
	trivy fs --config security/trivy/trivy.yaml .

verify:
	./scripts/verify-image.sh "$(IMAGE)"

kind-up:
	kind create cluster --name devops-pipeline --config deploy/kind/kind-config.yaml

kind-down:
	kind delete cluster --name devops-pipeline

demo:
	./scripts/kind-demo.sh "$(IMAGE)"
