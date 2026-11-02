# DevOps Security Pipeline

[![Supply Chain](https://github.com/aya-zid/devops-security-pipeline/actions/workflows/supply-chain.yml/badge.svg)](https://github.com/aya-zid/devops-security-pipeline/actions/workflows/supply-chain.yml)
[![CodeQL](https://github.com/aya-zid/devops-security-pipeline/actions/workflows/codeql.yml/badge.svg)](https://github.com/aya-zid/devops-security-pipeline/actions/workflows/codeql.yml)
[![OpenSSF Scorecard](https://api.securityscorecards.dev/projects/github.com/aya-zid/devops-security-pipeline/badge)](https://securityscorecards.dev/viewer/?uri=github.com/aya-zid/devops-security-pipeline)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

**A secure software supply-chain pipeline.** The pipeline builds a small container image, scans it, generates an SBOM, signs it with keyless Sigstore, attests its provenance, and uses Kyverno to reject unsigned images at the cluster boundary.

The pipeline is the product. The TypeScript service is a deliberately small deploy target so every stage has something real to build, scan, sign, and admit.

**Stack:** GitHub Actions · Semgrep · Gitleaks · Trivy · Syft · Cosign · GitHub attestations · kind · Kyverno · Fastify

---

## Why this exists

Most CI examples stop at "build and test." This project demonstrates the controls that make a supply chain defensible:

- **Nothing secret reaches the repo** — Gitleaks scans the full history on every run.
- **Code is analyzed before it ships** — Semgrep runs the `p/ci` ruleset plus project-specific rules.
- **Dependencies are inventoried** — Syft emits an SPDX SBOM for every build.
- **Images are scanned before and after packaging** — Trivy covers the filesystem and the built image.
- **The artifact is signed and attributable** — Cosign uses GitHub OIDC (no long-lived signing key), and build provenance is attested against the image digest.
- **The cluster enforces the policy** — Kyverno admits only images signed by this workflow, then applies hardening rules.

---

## Pipeline

```text
push / pull request
        │
        ├──────────────┬──────────────┐
        ▼              ▼              ▼
  ┌───────────┐  ┌───────────┐  ┌─────────────┐
  │ Semgrep   │  │ Gitleaks  │  │ lint + test │
  │ SAST      │  │ secrets   │  │ + coverage  │
  └─────┬─────┘  └─────┬─────┘  └──────┬──────┘
        └──────────────┴───────────────┘
                       ▼
              ┌─────────────────┐
              │  Build image    │
              └────────┬────────┘
                       ▼
        ┌──────────────┼──────────────┐
        ▼              ▼              ▼
  ┌───────────┐  ┌───────────┐  ┌───────────┐
  │ Syft SBOM │  │ Trivy fs  │  │ Trivy img │
  └─────┬─────┘  └─────┬─────┘  └─────┬─────┘
        └──────────────┴──────────────┘
                       ▼
              ┌─────────────────┐
              │ Cosign keyless  │
              │ sign + verify   │
              └────────┬────────┘
                       ▼
              ┌─────────────────┐
              │ Provenance      │
              │ attestation     │
              └────────┬────────┘
                       ▼
              ┌─────────────────┐
              │ Kyverno admits  │
              │ signed images   │
              │ only            │
              └─────────────────┘
```

| Stage | Tool | What it proves |
|-------|------|----------------|
| Secret scanning | Gitleaks | No credentials in the working tree or git history |
| SAST | Semgrep (`p/ci` + [`security/semgrep`](security/semgrep/devops-pipeline-rules.yml)) | No blocking code patterns such as `eval`, shell execution, or hardcoded secrets |
| Quality gate | ESLint, `tsc`, Vitest | Lint, types, and 100% line/function coverage of the request handlers (entrypoint excluded) |
| SBOM | Syft | A reviewable SPDX inventory of the image contents |
| Vulnerability scan | Trivy | HIGH/CRITICAL findings surfaced as SARIF in GitHub code scanning |
| Signing | Cosign + GitHub OIDC | The image was signed by this repository's workflow, not by a stolen key |
| Provenance | GitHub build attestations | The image digest was produced by this workflow from this commit |
| Admission | Kyverno | Unsigned images are rejected before a Pod can run |

---

## Quick start

### Run the service locally

```bash
cd app
npm ci
npm test
npm run dev          # http://localhost:3000
```

Routes: `/` (metadata), `/health` (probes), `/metrics` (Prometheus).

> **Windows:** the service and tests run natively. The pipeline scripts are Bash, so run them from WSL2 or Git Bash. The full kind/Kyverno demo also needs Docker Desktop with WSL2 integration; if you do not have that, use the GitHub Actions workflow instead.

### Run the pipeline

1. Create the repository and push:

   ```bash
   git remote add origin https://github.com/aya-zid/devops-security-pipeline.git
   git push -u origin main
   ```

2. Enable Actions. The `Supply Chain`, `CodeQL`, and dependency workflows run on every push and pull request.
3. On `main`, the image is published to GHCR and signed.
4. For the cluster demo, set the GHCR package visibility to **Public**:

   `Packages → devops-security-pipeline → Package settings → Change visibility → Public`

   Kyverno must be able to fetch the signature bundle from the registry.

### Run local security checks

Install the hooks once, then run them before pushing:

```bash
python -m pip install pre-commit
pre-commit install
pre-commit run --all-files
```

The hooks run Gitleaks, Semgrep (`p/ci` plus the project rules), and basic file hygiene. CodeQL and the scheduled Trivy scan run in GitHub Actions.

Run `make help` to list the local targets.

### Run the end-to-end admission demo

**Option A — GitHub Actions:** run the **End-to-End Admission Demo** workflow manually. It creates a kind cluster, installs Kyverno, deploys the signed image, smoke-tests `/health`, and asserts that an unsigned `nginx:latest` Pod is rejected.

**Option B — locally:**

```bash
export GITHUB_REPOSITORY=aya-zid/devops-security-pipeline
./scripts/preflight.sh
make demo IMAGE=ghcr.io/aya-zid/devops-security-pipeline:latest
```

Verify the signature independently:

```bash
make verify IMAGE=ghcr.io/aya-zid/devops-security-pipeline:latest
```

---

## Repository layout

| Path | Purpose |
|------|---------|
| [`app/`](app/) | TypeScript/Fastify deploy target, Dockerfile, and tests |
| [`app/src/`](app/src/) | Routes, Prometheus metrics, graceful shutdown |
| [`.github/workflows/supply-chain.yml`](.github/workflows/supply-chain.yml) | SAST, secrets, tests, SBOM, scans, signing, attestation |
| [`.github/workflows/kind-verify.yml`](.github/workflows/kind-verify.yml) | End-to-end Kyverno admission demo |
| [`.github/workflows/dependency-review.yml`](.github/workflows/dependency-review.yml) | Blocks vulnerable dependency changes in PRs |
| [`.github/workflows/scorecard.yml`](.github/workflows/scorecard.yml) | OpenSSF Scorecard, published to code scanning |
| [`.github/workflows/codeql.yml`](.github/workflows/codeql.yml) | CodeQL `security-and-quality` analysis |
| [`.github/workflows/scheduled-scan.yml`](.github/workflows/scheduled-scan.yml) | Weekly Trivy scan for newly disclosed CVEs |
| [`.pre-commit-config.yaml`](.pre-commit-config.yaml) | Local secret, SAST, and file-hygiene checks |
| [`security/semgrep/`](security/semgrep/devops-pipeline-rules.yml) | Project-specific SAST rules |
| [`security/kyverno/`](security/kyverno/) | Signature verification and container hardening policies |
| [`security/trivy/`](security/trivy/trivy.yaml) | Scanner configuration |
| [`deploy/kind/`](deploy/kind/kind-config.yaml) | Reproducible local cluster |
| [`deploy/k8s/`](deploy/k8s/) | Namespace, Deployment, Service, ServiceAccount, PodDisruptionBudget, and Kustomize entrypoint |
| [`scripts/`](scripts/) | Preflight, signature verification, kind demo |
| [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) | Components, trust boundaries, and decisions |
| [`docs/RUNBOOK.md`](docs/RUNBOOK.md) | Operate, verify, troubleshoot, tear down |
| [`docs/TESTING.md`](docs/TESTING.md) | Test strategy, coverage, and CI expectations |
| [`CONTRIBUTING.md`](CONTRIBUTING.md) | Local setup, testing, and contribution workflow |
| [`CHANGELOG.md`](CHANGELOG.md) | Release history |
| [`.github/CODEOWNERS`](.github/CODEOWNERS) | Default code owner |
| [`.github/ISSUE_TEMPLATE/`](.github/ISSUE_TEMPLATE/) | Bug and feature request forms |
| [`.github/PULL_REQUEST_TEMPLATE.md`](.github/PULL_REQUEST_TEMPLATE.md) | Pull request checklist |
| [`SECURITY.md`](SECURITY.md) | Threat model, controls, and reporting |

---

## Security controls

| Control | Implementation |
|---------|----------------|
| Least-privilege CI tokens | Each job declares only the permissions it needs; the workflow default is `contents: read` |
| No persisted git credentials | Every checkout sets `persist-credentials: false` |
| Keyless signing | Cosign uses GitHub OIDC; there is no private key to leak or rotate |
| Identity-bound verification | `cosign verify` pins the certificate identity and OIDC issuer |
| Artifact inventory | SPDX SBOM attached to every build |
| Provenance | `actions/attest-build-provenance` binds the image digest to the workflow and commit |
| Admission control | Kyverno verifies signatures and enforces non-root, read-only root filesystem, no privilege escalation, dropped capabilities, and resource limits |
| Dependency hygiene | Dependabot, Dependency Review, and OpenSSF Scorecard |
| Continuous code analysis | CodeQL `security-and-quality` for JavaScript/TypeScript |
| Ongoing CVE monitoring | Scheduled Trivy scan of the default branch every week |
| Local shift-left checks | Pre-commit runs Gitleaks and Semgrep before a commit leaves the machine |
| Hardened container | Non-root UID 10001, Alpine runtime, read-only root filesystem, dropped capabilities |
| Workload identity | Dedicated ServiceAccount; the service account token is not automounted |
| Availability | PodDisruptionBudget keeps at least one replica available during voluntary disruptions |
| Secret scanning | Gitleaks over full history, with project allowlists only for docs and fixtures |

**Trivy is report-only by default.** Set the repository variable `TRIVY_EXIT_CODE=1` to turn HIGH/CRITICAL findings into a hard gate. This is deliberate: upstream base-image CVEs should not silently block unrelated changes, but the switch is documented and one click away. See [`security/trivy/trivy.yaml`](security/trivy/trivy.yaml).

**Action pinning.** Workflows reference actions by major version tags for readability. For a production fork, pin every action to a commit SHA (Dependabot can maintain the pins) and enable branch protection with required checks.

---

## Design decisions

- **Keyless over key-based signing.** A stored private key is another secret to manage. GitHub OIDC gives a short-lived certificate bound to the workflow identity.
- **Policy as code, not a checklist.** Kyverno makes the "only signed images" rule executable. The policy is versioned with the app.
- **Report first, gate second.** Vulnerability scanning is visible immediately; enforcement is a deliberate opt-in so the pipeline stays useful while upstream CVEs are triaged.
- **Small deploy target.** The service is intentionally boring. The interesting engineering is in the pipeline and the policy boundary.
- **Reproducible local cluster.** kind makes the admission demo runnable on a laptop and in CI without a cloud account.

---

## Roadmap

- Pin all GitHub Actions to commit SHAs and enforce with a policy check.
- Add SLSA Build Level 3 provenance and verify it in Kyverno (`attestations` block).
- Add runtime detection (Falco) and network policy defaults.
- Publish signed SBOM attestations and verify them at admission.
- Add a `cosign verify-attestation` gate to the kind demo.

---

## Development approach

The design, threat model, and verification steps are documented so every control can be explained and reproduced; generated changes were reviewed and tested locally (`npm run lint`, `npm run typecheck`, `npm run test:coverage`) before being committed.

## License

MIT. See [LICENSE](LICENSE).
