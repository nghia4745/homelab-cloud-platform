#!/usr/bin/env bash
set -euo pipefail

CLUSTER_NAME="homelab"
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

if ! kind get clusters 2>/dev/null | grep -qx "${CLUSTER_NAME}"; then
  echo "Kind cluster '${CLUSTER_NAME}' does not exist. Nothing to clean up."
  exit 0
fi

echo "Cleaning up Helm releases in kind-${CLUSTER_NAME}..."
helm uninstall "${APP_RELEASE}" -n "${APP_NAMESPACE}" --kube-context "kind-${CLUSTER_NAME}" >/dev/null 2>&1 || true
helm uninstall "${INGRESS_RELEASE}" -n "${INGRESS_NAMESPACE}" --kube-context "kind-${CLUSTER_NAME}" >/dev/null 2>&1 || true

echo "Deleting Kind cluster '${CLUSTER_NAME}'..."
kind delete cluster --name "${CLUSTER_NAME}"

echo "Full cleanup complete."
