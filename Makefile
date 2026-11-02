SHELL := /usr/bin/env bash
APP_DIR := app
IMAGE ?= ghcr.io/aya-zid/devops_project:latest

.PHONY: install lint typecheck test build sbom scan verify kind-up kind-down demo

install:
	cd $(APP_DIR) && npm ci

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
