#!/usr/bin/env bash
set -euo pipefail

ARGOCD_VERSION="${ARGOCD_VERSION:-stable}"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

echo "==> Creating argocd namespace..."
kubectl apply -f "${REPO_ROOT}/argocd/bootstrap/argocd-namespace.yaml"

echo "==> Installing ArgoCD (version: ${ARGOCD_VERSION})..."
kubectl apply -n argocd \
  -f "https://raw.githubusercontent.com/argoproj/argo-cd/${ARGOCD_VERSION}/manifests/install.yaml"

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
