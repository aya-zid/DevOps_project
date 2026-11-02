#!/usr/bin/env bash
set -euo pipefail

required=(git node npm docker kubectl kind helm cosign syft trivy)
missing=()

for tool in "${required[@]}"; do
  if ! command -v "$tool" >/dev/null 2>&1; then
    missing+=("$tool")
  fi
done

if [ ${#missing[@]} -gt 0 ]; then
  printf 'Missing required tools: %s\n' "${missing[*]}" >&2
  exit 1
fi

echo "All required tools are installed."
