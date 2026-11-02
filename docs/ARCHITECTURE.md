# Architecture

## Components

```text
┌─────────────────────────────────────────────────────────────────────┐
│ GitHub                                                              │
│                                                                     │
│  Pull request ──► Dependency Review                                 │
│       │                                                             │
│       ▼                                                             │
│  Supply Chain workflow                                              │
│   ├─ Semgrep + Gitleaks                                             │
│   ├─ ESLint + tsc + Vitest                                          │
│   ├─ docker build ──► GHCR                                          │
│   ├─ Syft SBOM ──► artifact                                         │
│   ├─ Trivy fs + image ──► SARIF ──► code scanning                   │
│   ├─ Cosign keyless sign ──► registry signature                     │
│   └─ build provenance attestation ──► registry                       │
│                                                                     │
└──────────────────────────────┬──────────────────────────────────────┘
                               │ pull by digest/tag
                               ▼
┌─────────────────────────────────────────────────────────────────────┐
│ kind cluster                                                        │
│                                                                     │
│  Kyverno admission webhook                                          │
│   ├─ verify signature (keyless, GitHub OIDC issuer)                  │
│   ├─ reject :latest                                                 │
│   └─ require non-root + read-only rootfs + limits                    │
│                               │                                     │
│                               ▼                                     │
│  devops-pipeline namespace: Deployment (2 replicas) ──► Service :30080     │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

## Responsibilities

| Component | Responsibility |
|-----------|----------------|
| Fastify service | Serve `/`, `/health`, `/metrics`; expose a minimal, hardened deploy target |
| Supply Chain workflow | Produce a tested, scanned, signed, and attested image |
| CodeQL workflow | Run semantic `security-and-quality` analysis for JavaScript/TypeScript |
| Scheduled scan workflow | Re-scan the default branch weekly for newly disclosed CVEs |
| Pre-commit hooks | Run Gitleaks, Semgrep, and file-hygiene checks before a commit is created |
| Syft | Record the contents of the image as an SPDX SBOM |
| Trivy | Report HIGH/CRITICAL vulnerabilities in the source and image |
| Cosign | Sign the image with a short-lived certificate derived from GitHub OIDC |
| GitHub attestations | Bind the image digest to the workflow, commit, and repository |
| Kyverno | Enforce signature and hardening policy at admission time |
| kind | Provide a disposable, reproducible cluster for the end-to-end demo |

## Trust boundaries

1. **Untrusted input:** pull requests, commits, dependency updates, and the contents of the git history.
2. **CI identity:** the workflow is trusted only for the duration of the run and only with the permissions declared on each job.
3. **Registry:** stores the image, signature, attestation, and SBOM. The cluster trusts the registry only as a transport; the signature is the trust anchor.
4. **Cluster boundary:** Kyverno decides whether an image may run. Runtime hardening limits the blast radius after admission.

## Data flow

Locally, pre-commit runs Gitleaks and Semgrep before a commit is created.

1. A push or pull request triggers `supply-chain.yml`.
2. Static analysis and secret scanning run in parallel with the test job.
3. The `supply-chain` job builds the image. On `main`, it pushes to GHCR, signs with Cosign, moves the `latest` tag, and attests provenance.
4. Trivy and Syft run against the image. Reports are uploaded as SARIF and artifacts.
5. On `main`, `kind-verify.yml` can be run manually to create a cluster, install Kyverno, deploy the signed image, and prove that an unsigned image is denied.
6. `codeql.yml` runs CodeQL on pushes, pull requests, and a weekly schedule.
7. `scheduled-scan.yml` re-scans the default branch every week so new CVEs are visible even without a code change.

## Decisions

### ADR-1: Keyless signing instead of a stored private key

**Decision:** Use Cosign keyless signing with GitHub OIDC.

**Rationale:** A long-lived signing key is another high-value secret. Keyless signing binds the signature to a short-lived certificate whose identity is the workflow. Verification pins both the identity and the issuer, so a signature from another repository or workflow does not pass.

**Trade-off:** The cluster needs network access to the Sigstore transparency log and Fulcio during verification. A fully air-gapped deployment would need a different trust root.

### ADR-2: Policy as code with Kyverno

**Decision:** Encode the admission rules as Kyverno `ClusterPolicy` resources in the repository.

**Rationale:** Documentation drifts; policy does not. The same manifest is used locally and in CI, and changes are reviewed like application code.

**Trade-off:** Kyverno is another control-plane component to operate. For a small cluster, Pod Security Admission covers some hardening rules but cannot verify image signatures.

### ADR-3: Report-only vulnerability scanning by default

**Decision:** Trivy runs with `exit-code: 0` unless the repository variable `TRIVY_EXIT_CODE=1` is set.

**Rationale:** A new HIGH finding in an upstream base image should be visible without blocking unrelated work. Teams can opt into enforcement once the baseline is triaged.

**Trade-off:** A vulnerable image can be published while the gate is off. The switch and the trade-off are documented, and the SARIF results are always uploaded.

### ADR-4: Small service, serious pipeline

**Decision:** Keep the application intentionally small.

**Rationale:** The project is about supply-chain controls. A simple service makes the pipeline stages and the admission boundary easy to inspect and reproduce.

## Failure modes

| Failure | Behavior | Recovery |
|---------|----------|----------|
| Semgrep, Gitleaks, or tests fail | Pipeline stops before build | Fix the finding in a new commit |
| Trivy finds HIGH/CRITICAL | Reports uploaded; build continues unless `TRIVY_EXIT_CODE=1` | Triage the CVE or update the base image |
| Cosign signing fails | Pipeline fails after build | Check `id-token: write` and `packages: write` permissions |
| Signature verification fails | Pipeline fails | Confirm the identity regexp and issuer match the workflow |
| Kyverno rejects the image | Pod is not created; policy event recorded | Verify the image was signed by the expected workflow |
| Image pull fails in kind | Pods stay in `ImagePullBackOff` | Make the GHCR package public or add `imagePullSecrets` |

## Future work

- Verify provenance attestations at admission, not just signatures.
- Publish and verify a signed SBOM.
- Add SLSA Build Level 3 provenance.
- Add runtime detection and default-deny network policy.
