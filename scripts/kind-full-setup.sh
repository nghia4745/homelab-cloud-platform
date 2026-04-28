#!/usr/bin/env bash
set -euo pipefail

CLUSTER_NAME="homelab"
CLUSTER_CONFIG="kind/cluster.yaml"
APP_RELEASE="homelab-api-app"
APP_NAMESPACE="app"
INGRESS_RELEASE="ingress-nginx"
INGRESS_NAMESPACE="ingress-nginx"

if ! command -v kind >/dev/null 2>&1; then
  echo "Error: kind is required but not installed."
  exit 1
fi

if ! command -v kubectl >/dev/null 2>&1; then
  echo "Error: kubectl is required but not installed."
  exit 1
fi

if ! command -v helm >/dev/null 2>&1; then
  echo "Error: helm is required but not installed."
  exit 1
fi

if [[ ! -f "${CLUSTER_CONFIG}" ]]; then
  echo "Error: cluster config not found at ${CLUSTER_CONFIG}."
  exit 1
fi

if ! kind get clusters 2>/dev/null | grep -qx "${CLUSTER_NAME}"; then
  echo "Creating Kind cluster '${CLUSTER_NAME}'..."
  kind create cluster --config "${CLUSTER_CONFIG}"
else
  echo "Kind cluster '${CLUSTER_NAME}' already exists. Skipping cluster creation."
fi

echo "Using kube context kind-${CLUSTER_NAME}..."
kubectl config use-context "kind-${CLUSTER_NAME}" >/dev/null

echo "Adding/updating ingress-nginx Helm repo..."
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx >/dev/null 2>&1 || true
helm repo update >/dev/null

echo "Installing/upgrading ingress-nginx controller..."
helm upgrade --install "${INGRESS_RELEASE}" ingress-nginx/ingress-nginx \
  --kube-context "kind-${CLUSTER_NAME}" \
  --namespace "${INGRESS_NAMESPACE}" \
  --create-namespace \
  --set controller.service.type=NodePort \
  --set controller.service.nodePorts.http=30080

kubectl rollout status deployment/ingress-nginx-controller \
  -n "${INGRESS_NAMESPACE}" \
  --context "kind-${CLUSTER_NAME}" \
  --timeout=180s

echo "Applying app/dev/monitoring namespaces and network policy..."
kubectl apply -f k8s/namespaces/app.yaml --context "kind-${CLUSTER_NAME}"
kubectl apply -f k8s/namespaces/dev.yaml --context "kind-${CLUSTER_NAME}"
kubectl apply -f k8s/namespaces/monitoring.yaml --context "kind-${CLUSTER_NAME}"
kubectl apply -f k8s/networkpolicy.yaml --context "kind-${CLUSTER_NAME}"

if [[ -z "${GHCR_USERNAME:-}" || -z "${GHCR_TOKEN:-}" ]]; then
  echo "Error: GHCR_USERNAME and GHCR_TOKEN must be set to create ghcr-pull-secret."
  echo "Optional: set GHCR_EMAIL (defaults to you@example.com)."
  exit 1
fi

GHCR_EMAIL_VALUE="${GHCR_EMAIL:-you@example.com}"

echo "Creating/updating GHCR pull secret in namespace '${APP_NAMESPACE}'..."
kubectl create secret docker-registry ghcr-pull-secret \
  --namespace "${APP_NAMESPACE}" \
  --docker-server=ghcr.io \
  --docker-username="${GHCR_USERNAME}" \
  --docker-password="${GHCR_TOKEN}" \
  --docker-email="${GHCR_EMAIL_VALUE}" \
  --dry-run=client -o yaml | kubectl apply --context "kind-${CLUSTER_NAME}" -f -

echo "Installing/upgrading app Helm release..."
helm upgrade --install "${APP_RELEASE}" charts/homelab-api \
  --kube-context "kind-${CLUSTER_NAME}" \
  --namespace "${APP_NAMESPACE}" \
  --values charts/homelab-api/values-dev.yaml

kubectl rollout status deployment/${APP_RELEASE} \
  -n "${APP_NAMESPACE}" \
  --context "kind-${CLUSTER_NAME}" \
  --timeout=180s

echo "Setup complete. Verify endpoint: curl http://localhost:8080/health"
