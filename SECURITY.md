# Security Policy

## Supported versions

This project is a demonstration project. The `main` branch is the only supported version.

## Reporting a vulnerability

Do not open a public issue for a security problem. Use GitHub's private vulnerability reporting (**Security → Report a vulnerability**).

Include the affected version or commit, a reproduction, and the impact you believe is possible. Expect an acknowledgement within a few days.

---

## Threat model

### Assets

- Source code and git history, including any accidentally committed credentials.
- CI identity: the `GITHUB_TOKEN`, the OIDC token issued to the workflow, and the resulting signing identity.
- The container image, its digest, SBOM, and provenance attestation.
- The Kubernetes cluster and the workloads it runs.

### Trust boundaries

1. **Contributor → GitHub.** Pull requests, dependency changes, and commits are untrusted input.
2. **GitHub Actions → registry.** The workflow has short-lived, scoped credentials and signs the artifact it built.
3. **Registry → cluster.** The cluster must not run an image unless it came from the expected workflow.
4. **Cluster → runtime.** A compromised container must not be able to escalate privileges or write to its root filesystem.

### Threats and controls

| Threat | Impact | Control |
|--------|--------|---------|
| Credentials committed to the repo | Account or cluster compromise | Gitleaks over full history and in pre-commit; `.gitleaks.toml` only allowlists docs and fixtures |
| Vulnerable dependency or base image | Exploitation at runtime | Trivy filesystem and image scans plus a weekly scheduled scan; Dependabot; Dependency Review; SBOM |
| Malicious code pattern | Injection or RCE | Semgrep `p/ci` plus project rules for `eval`, shell execution, and hardcoded secrets; CodeQL semantic analysis |
| Tampered or spoofed image | Running attacker-controlled code | Cosign keyless signing bound to the workflow identity; `cosign verify` with identity and issuer |
| Unsigned image deployed to the cluster | Policy bypass | Kyverno `verifyImages` with keyless attestor; unsigned Pods are rejected |
| Over-privileged container | Container escape or host compromise | Non-root, read-only root filesystem, no privilege escalation, all capabilities dropped, seccomp `RuntimeDefault` |
| CI token abuse | Repository or registry takeover | Per-job least-privilege permissions; no persisted checkout credentials; OIDC instead of long-lived keys |
| Vulnerable dependency update merged | Supply-chain compromise | Dependency Review blocks high-severity changes; Dependabot keeps versions current; OpenSSF Scorecard tracks posture |

### Non-goals

- Runtime threat detection (Falco, eBPF) and incident response.
- Multi-tenant isolation and cluster hardening beyond the demo namespace.
- Application secret management at runtime.
- mTLS between services.
- Protecting against a compromised GitHub Actions runner or a compromised upstream action.

---

## Hardening checklist for a real deployment

- Pin every GitHub Action to a commit SHA and let Dependabot maintain the pins.
- Enable branch protection, required reviews, required status checks, and signed commits.
- Set the repository variable `TRIVY_EXIT_CODE=1` to make HIGH/CRITICAL findings a hard gate.
- Use a private registry with `imagePullSecrets` and Kyverno `imageRegistryCredentials`.
- Verify **attestations**, not only signatures, and require SLSA provenance.
- Add a default-deny `NetworkPolicy` and separate namespaces per environment.
- Use GitHub Environments with required reviewers for production deploys.
- Enable audit logging, runtime detection, and alerting on admission denials.
- Rotate credentials, scope tokens per job, and never store a Cosign private key.
