#!/usr/bin/env bash
set -euo pipefail

CLUSTER_NAME="homelab"
APP_RELEASE="homelab-api-app"
APP_NAMESPACE="app"
MONITORING_RELEASE="kube-prometheus-stack"
MONITORING_NAMESPACE="monitoring"
ARGOCD_RELEASE="argocd"
ARGOCD_NAMESPACE="argocd"
INGRESS_RELEASE="ingress-nginx"
INGRESS_NAMESPACE="ingress-nginx"
PORT_FORWARD_DIR=".kind-port-forwards"

stop_port_forward() {
  local name="$1"
  local pid_file="${PORT_FORWARD_DIR}/${name}.pid"

  if [[ ! -f "${pid_file}" ]]; then
    return 0
  fi

  local pid
  pid="$(cat "${pid_file}")"
  if kill -0 "${pid}" >/dev/null 2>&1; then
    echo "Stopping '${name}' port-forward (PID ${pid})..."
    kill "${pid}" >/dev/null 2>&1 || true
  fi
  rm -f "${pid_file}"
}

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

stop_port_forward "grafana"
stop_port_forward "prometheus"
stop_port_forward "argocd"

echo "Cleaning up Helm releases in kind-${CLUSTER_NAME}..."
helm uninstall "${APP_RELEASE}" -n "${APP_NAMESPACE}" --kube-context "kind-${CLUSTER_NAME}" >/dev/null 2>&1 || true
helm uninstall "${MONITORING_RELEASE}" -n "${MONITORING_NAMESPACE}" --kube-context "kind-${CLUSTER_NAME}" >/dev/null 2>&1 || true
helm uninstall "${ARGOCD_RELEASE}" -n "${ARGOCD_NAMESPACE}" --kube-context "kind-${CLUSTER_NAME}" >/dev/null 2>&1 || true
helm uninstall "${INGRESS_RELEASE}" -n "${INGRESS_NAMESPACE}" --kube-context "kind-${CLUSTER_NAME}" >/dev/null 2>&1 || true

echo "Deleting Kind cluster '${CLUSTER_NAME}'..."
kind delete cluster --name "${CLUSTER_NAME}"

if [[ -d "${PORT_FORWARD_DIR}" ]]; then
  rm -f "${PORT_FORWARD_DIR}"/*.log >/dev/null 2>&1 || true
  rmdir "${PORT_FORWARD_DIR}" >/dev/null 2>&1 || true
fi

echo "Full cleanup complete."
