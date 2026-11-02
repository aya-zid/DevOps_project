#!/usr/bin/env bash
set -euo pipefail

IMAGE="${1:?usage: verify-image.sh <image> [owner/repo]}"
REPO="${2:-${GITHUB_REPOSITORY:-}}"

if [ -z "$REPO" ]; then
  echo "Set GITHUB_REPOSITORY (owner/repo) or pass it as the second argument." >&2
  exit 1
fi

cosign verify "$IMAGE" \
  --certificate-identity-regexp "https://github.com/${REPO}/.github/workflows/.*" \
  --certificate-oidc-issuer "https://token.actions.githubusercontent.com"
