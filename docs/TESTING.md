# Testing

## Test layers

| Layer | Tool | Command |
|-------|------|---------|
| Unit | Vitest | `npm run test` |
| Coverage | Vitest + v8 | `npm run test:coverage` |
| Lint | ESLint | `npm run lint` |
| Types | TypeScript | `npm run typecheck` |
| Secrets | Gitleaks | CI and pre-commit |
| SAST | Semgrep | CI and pre-commit |
| Code analysis | CodeQL | CI |
| Dependencies | Dependency Review and Dependabot | CI |
| Image | Trivy | CI |
| Admission | Kyverno and kind | End-to-End Admission Demo |

## Running tests

```bash
cd app
npm ci
npm run test:coverage
```

The suite covers the Fastify request handlers. `src/server.ts` is excluded from coverage because it is the process entrypoint; its behavior is exercised by the container health check in the admission demo.

## Coverage thresholds

`app/vitest.config.ts` enforces:

- lines: 80%
- functions: 80%
- branches: 70%
- statements: 80%

Keep these thresholds in place when adding routes.

## Adding tests

- Put tests in `app/test/*.test.ts`.
- Build the app with `buildApp()` rather than starting a server.
- Use `app.inject()` for HTTP-level tests.
- Cover both success and failure paths for new routes.

## CI

The `Supply Chain` workflow runs lint, typecheck, and coverage before the image build. A failure in any of those jobs prevents the build, scan, and signing stages.

## Local limitations

Windows can run the Node.js service and tests natively. The shell scripts and the kind/Kyverno demo require WSL2 or Git Bash, and the demo needs Docker Desktop with WSL2 integration. If Docker is unavailable, run the `End-to-End Admission Demo` workflow from GitHub Actions.
