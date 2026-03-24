#!/usr/bin/env bash
set -euo pipefail

ARGOCD_VERSION="${ARGOCD_VERSION:-stable}"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

echo "==> Creating argocd namespace..."
kubectl apply -f "${REPO_ROOT}/argocd/bootstrap/argocd-namespace.yaml"

echo "==> Installing ArgoCD (version: ${ARGOCD_VERSION})..."
INSTALL_MANIFEST="https://raw.githubusercontent.com/argoproj/argo-cd/${ARGOCD_VERSION}/manifests/install.yaml"

# Resolve the exact image tag being used
ARGOCD_IMAGE=$(curl -sSL "${INSTALL_MANIFEST}" | grep 'image: quay.io/argoproj/argocd' | head -1 | awk '{print $2}')
echo "==> ArgoCD image: ${ARGOCD_IMAGE}"

# Pre-pull the image and load it into the local cluster to avoid registry access at runtime
echo "==> Pre-pulling image via Docker..."
docker pull "${ARGOCD_IMAGE}"

if kubectl config current-context | grep -q '^kind-'; then
  CLUSTER_NAME=$(kubectl config current-context | sed 's/^kind-//')
  echo "==> Loading image into kind cluster '${CLUSTER_NAME}'..."
  kind load docker-image "${ARGOCD_IMAGE}" --name "${CLUSTER_NAME}"
elif kubectl config current-context | grep -q '^k3d-'; then
  CLUSTER_NAME=$(kubectl config current-context | sed 's/^k3d-//')
  echo "==> Loading image into k3d cluster '${CLUSTER_NAME}'..."
  k3d image import "${ARGOCD_IMAGE}" --cluster "${CLUSTER_NAME}"
else
  echo "==> Skipping image load (not a kind/k3d cluster — assuming registry is reachable)"
fi

curl -sSL "${INSTALL_MANIFEST}" | kubectl apply --server-side -n argocd -f -

echo "==> Waiting for ArgoCD server to be ready..."
kubectl rollout status deployment/argocd-server -n argocd --timeout=300s

echo "==> Waiting for ArgoCD application-controller to be ready..."
kubectl rollout status statefulset/argocd-application-controller -n argocd --timeout=300s

echo "==> Waiting for ArgoCD repo-server to be ready..."
kubectl rollout status deployment/argocd-repo-server -n argocd --timeout=300s

echo "==> Applying root App of Apps..."
kubectl apply -f "${REPO_ROOT}/argocd/apps/root-app.yaml"

echo ""
echo "==> ArgoCD bootstrap complete!"
echo ""
echo "To get the initial admin password, run:"
echo "  kubectl get secret argocd-initial-admin-secret -n argocd -o jsonpath='{.data.password}' | base64 -d && echo"
echo ""
echo "To access the ArgoCD UI via port-forward, run:"
echo "  kubectl port-forward svc/argocd-server -n argocd 8080:443"
echo ""
echo "Then open: https://localhost:8080  (username: admin)"
