#!/bin/bash

set -euo pipefail

NAMESPACE="${NAMESPACE:-default}"
IMAGE_NAME="${IMAGE_NAME:-test-api}"
CHART_DIR="${CHART_DIR:-apps/python-api}"
API_DIR="${API_DIR:-python-api}"
TIMEOUT="${TIMEOUT:-300s}"
PAUSE_ARGOCD_AUTOSYNC="${PAUSE_ARGOCD_AUTOSYNC:-true}"

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Missing required command: $1" >&2
    exit 1
  fi
}

require_command minikube
require_command docker
require_command kubectl
require_command helm

echo "Checking Minikube status..."
minikube status >/dev/null

echo "Building ${IMAGE_NAME}:latest inside the Minikube Docker daemon..."
eval "$(minikube -p minikube docker-env)"
docker build -t "${IMAGE_NAME}:latest" "${API_DIR}"

echo "Ensuring namespace ${NAMESPACE} exists..."
kubectl create namespace "${NAMESPACE}" --dry-run=client -o yaml | kubectl apply -f -

echo "Applying Argo CD application metadata if Argo CD is already installed..."
if kubectl get crd applications.argoproj.io >/dev/null 2>&1 && kubectl get namespace argocd >/dev/null 2>&1; then
  kubectl apply -f argocd/applications/python-api.application.yaml
  if [ "${PAUSE_ARGOCD_AUTOSYNC}" = "true" ]; then
    echo "Pausing python-api Argo CD auto-sync so local manifests are not immediately reverted."
    kubectl -n argocd patch application python-api --type merge -p '{"spec":{"syncPolicy":{"automated":null}}}'
  fi
else
  echo "Argo CD is not installed or its CRD is unavailable; skipping Application apply."
fi

echo "Rendering and applying the python-api Helm chart locally..."
helm template python-api "${CHART_DIR}" --namespace "${NAMESPACE}" | kubectl apply -n "${NAMESPACE}" -f -

echo "Restarting API deployments so they pick up the freshly built local image..."
kubectl -n "${NAMESPACE}" rollout restart deployment/test-api-v1 deployment/test-api-v2

echo "Waiting for Postgres, Redis, and API rollouts..."
kubectl -n "${NAMESPACE}" rollout status statefulset/postgres --timeout="${TIMEOUT}"
kubectl -n "${NAMESPACE}" rollout status deployment/redis --timeout="${TIMEOUT}"
kubectl -n "${NAMESPACE}" rollout status deployment/test-api-v1 --timeout="${TIMEOUT}"
kubectl -n "${NAMESPACE}" rollout status deployment/test-api-v2 --timeout="${TIMEOUT}"

echo "Current application pods:"
kubectl -n "${NAMESPACE}" get pods -l 'app in (test-api,postgres,redis)' -o wide

echo
echo "Done. Try:"
echo "  curl http://localhost/test/ready"
echo "  curl http://localhost/test/data"
echo
echo "Note: this applies local manifests directly. Push the argocd branch if you want Argo CD to converge to the same state from Git."
echo "If auto-sync was paused, re-enable it with:"
echo "  kubectl apply -f argocd/applications/python-api.application.yaml"
