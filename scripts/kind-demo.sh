#!/usr/bin/env bash
set -euo pipefail

IMAGE="${1:?usage: kind-demo.sh <signed-image>}"
REPO="${GITHUB_REPOSITORY:?set GITHUB_REPOSITORY=owner/repo}"
CLUSTER="irongate"

for tool in docker kind kubectl helm; do
  command -v "$tool" >/dev/null 2>&1 || {
    echo "$tool is required" >&2
    exit 1
  }
done

if ! kind get clusters | grep -qx "$CLUSTER"; then
  kind create cluster --name "$CLUSTER" --config deploy/kind/kind-config.yaml
fi

helm repo add kyverno https://kyverno.github.io/kyverno/ >/dev/null
helm repo update >/dev/null
helm upgrade --install kyverno kyverno/kyverno \
  --namespace kyverno --create-namespace \
  --set admissionController.replicas=1 \
  --wait --timeout 10m

kubectl create namespace irongate --dry-run=client -o yaml | kubectl apply -f -
sed -e "s|GITHUB_REPOSITORY_PLACEHOLDER|${REPO}|g" \
  security/kyverno/verify-signed-images.yaml | kubectl apply -f -
kubectl apply -f security/kyverno/require-hardening.yaml

sed -e "s|IMAGE_PLACEHOLDER|${IMAGE}|g" \
  deploy/k8s/deployment.yaml | kubectl apply -n irongate -f -
kubectl apply -n irongate -f deploy/k8s/service.yaml

kubectl -n irongate rollout status deployment/irongate --timeout=240s

echo
echo "Signed image admitted."
echo "Try an unsigned image (it should be rejected):"
echo "  kubectl apply -n irongate -f deploy/k8s/unsigned-fixture.yaml"
echo "App: http://localhost:30080"
