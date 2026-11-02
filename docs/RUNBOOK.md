# Runbook

## Prerequisites

| Tool | Version | Used for |
|------|---------|----------|
| Node.js | 20+ | Running and testing the service |
| Docker | 24+ | Building the image |
| kind | 0.20+ | Local cluster |
| kubectl | 1.28+ | Cluster operations |
| Helm | 3.12+ | Installing Kyverno |
| Cosign | 2.x | Verifying signatures |
| Syft | 1.x | Generating SBOMs locally |
| Trivy | 0.50+ | Scanning locally |

Check everything at once:

```bash
./scripts/preflight.sh
```

## Run the service

```bash
cd app
npm ci
npm run lint
npm run typecheck
npm run test:coverage
npm run dev
```

Open `http://localhost:3000/health`. To use a different port:

```bash
PORT=3100 npm run dev
```

## Run the pipeline

1. Push the repository to GitHub as `OWNER/irongate`.
2. The `Supply Chain` workflow runs on every push and pull request.
3. On `main`, the image is published as `ghcr.io/owner/irongate:<sha>` and `:latest`.
4. Set the GHCR package to public for the cluster demo: **Packages → irongate → Package settings → Change visibility → Public**.

### Optional: make Trivy a hard gate

Set the repository variable `TRIVY_EXIT_CODE=1` under **Settings → Secrets and variables → Actions → Variables**. The default is report-only (`0`).

## Verify a signed image

```bash
export GITHUB_REPOSITORY=OWNER/irongate
./scripts/verify-image.sh ghcr.io/owner/irongate:latest
```

Or with Make:

```bash
make verify IMAGE=ghcr.io/owner/irongate:latest
```

A successful verification prints the Cosign bundle, including the certificate identity and issuer.

## Run the end-to-end admission demo

### From GitHub Actions

Run **End-to-End Admission Demo** from the Actions tab. It:

1. Creates a kind cluster.
2. Installs Kyverno.
3. Applies the signature and hardening policies.
4. Deploys the signed image and waits for rollout.
5. Smoke-tests `/health` through a port-forward.
6. Attempts to run `nginx:latest` and fails the job if Kyverno admits it.

### Locally

```bash
export GITHUB_REPOSITORY=OWNER/irongate
make demo IMAGE=ghcr.io/owner/irongate:latest
```

The signed image should roll out. Then prove enforcement:

```bash
kubectl apply -n irongate -f deploy/k8s/unsigned-fixture.yaml
```

The fixture is hardened but unsigned, so the only policy it can violate is signature verification. Expected result: the Pod is rejected by Kyverno with a signature verification error.

Check the app:

```bash
kubectl -n irongate port-forward svc/irongate 8080:80
curl http://127.0.0.1:8080/health
```

## Troubleshooting

| Symptom | Likely cause | Fix |
|---------|--------------|-----|
| `ImagePullBackOff` | GHCR package is private | Make it public, or add an `imagePullSecret` |
| Kyverno rejects the signed image | Package is private, so the signature cannot be fetched | Make the package public |
| `cosign verify` fails | Identity regexp or issuer mismatch | Confirm `GITHUB_REPOSITORY` and that the image was signed by this workflow |
| `latest` tag points to an old image | `docker buildx imagetools create` did not run | Re-run the pipeline on `main` |
| Kind port 30080 is in use | Another service is bound | Change the port mapping or use port-forward |
| Kyverno install times out | Cluster is still starting | Re-run the Helm command; 10 minutes is usually enough |

## Teardown

```bash
kind delete cluster --name irongate
```

Remove local artifacts:

```bash
rm -rf app/node_modules app/dist app/coverage sbom.spdx.json *.sarif
```

## Interview talking points

- **Why sign images?** A tag is mutable and a digest proves nothing about who built it. A signature binds the digest to a workload identity; Kyverno turns that into an admission decision.
- **Why keyless?** There is no long-lived key to leak. The certificate is short-lived and tied to the OIDC identity of the workflow.
- **Why both Trivy and Semgrep?** They answer different questions: Semgrep finds dangerous code patterns, Trivy finds known-vulnerable packages and OS packages.
- **Why an SBOM?** You cannot respond to a new CVE if you do not know what is in the image. The SBOM makes the dependency inventory queryable.
- **Why is the service so small?** The pipeline is the subject. A small target keeps the security controls easy to inspect and reproduce.
- **What is missing for production?** Pinned action SHAs, attestation verification at admission, SLSA Level 3, runtime detection, default-deny network policy, and environment-scoped deploy approvals.

## Useful commands

```bash
# App
cd app && npm run test:coverage

# Local SBOM and scan
make sbom
make scan

# Policies
kubectl get clusterpolicy
kubectl describe clusterpolicy verify-irongate-signatures
kubectl -n irongate get events --sort-by=.lastTimestamp

# Signatures
cosign tree ghcr.io/owner/irongate:latest
```
