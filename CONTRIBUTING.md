# Contributing

Thanks for taking the time to improve DevOps Security Pipeline.

## Prerequisites

- Node.js 22 (see `app/.nvmrc`)
- npm
- Git
- Optional for the end-to-end demo: Docker, kind, kubectl, Helm, Cosign, Syft, Trivy

On Windows, the application and tests run natively. The scripts in `scripts/` are Bash; run them from WSL2 or Git Bash. If PowerShell blocks `npm.ps1`, use `npm.cmd`.

## Local setup

```bash
cd app
npm ci
npm run dev
```

Run the quality gates before opening a pull request:

```bash
npm run lint
npm run typecheck
npm run test:coverage
```

Install and run the pre-commit hooks once:

```bash
python -m pip install pre-commit
pre-commit install
pre-commit run --all-files
```

## Pull requests

1. Create a branch: `git switch -c type/short-description`.
2. Keep changes focused and update documentation when behavior changes.
3. Run the local checks above.
4. Open a pull request using the template.
5. Ensure the Supply Chain, CodeQL, Dependency Review, and OpenSSF Scorecard checks pass.

## Commit messages

Use Conventional Commits:

```text
feat: add readiness endpoint
fix: reject unsigned images
ci: update Trivy action
docs: clarify local demo
```

## Security changes

- Never commit credentials, tokens, or private keys.
- Do not weaken a security check to make a build pass.
- For vulnerabilities, follow `SECURITY.md` instead of opening a public issue.
- If you change the Dockerfile or Kubernetes manifests, run the kind demo or the End-to-End Admission Demo workflow.

## Code style

- TypeScript strict mode is enabled.
- ESLint is the source of truth for lint rules.
- Keep the service small and the pipeline explicit.
- Add tests for behavior changes; coverage thresholds are in `app/vitest.config.ts`.

## License

By contributing, you agree that your contribution is licensed under the MIT License.
