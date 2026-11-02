# Changelog

All notable changes to this project are documented here. The format follows Keep a Changelog, and the project uses Semantic Versioning.

## [Unreleased]

### Added

- Repository governance files, issue and pull request templates, and contributor guidance.
- ServiceAccount, Namespace, and PodDisruptionBudget manifests for the demo deployment.
- Testing guide.

### Fixed

- Raised the Vitest timeout to avoid cold-start failures on Windows.
- Completed the Kustomize entrypoint with namespace, image, and workload resources.

## [0.1.0] - 2026-11-02

### Added

- Fastify service with `/`, `/health`, and `/metrics` endpoints.
- Multi-stage, non-root container image.
- Supply Chain workflow: Gitleaks, Semgrep, ESLint, TypeScript, Vitest, Docker, Syft, Trivy, Cosign, and build provenance.
- CodeQL, Dependency Review, OpenSSF Scorecard, and scheduled Trivy workflows.
- Kyverno signature-verification and container-hardening policies.
- kind-based end-to-end admission demo.
- Pre-commit hooks, threat model, architecture notes, and runbook.
