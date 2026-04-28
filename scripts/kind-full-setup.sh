#!/usr/bin/env bash
set -euo pipefail

CLUSTER_NAME="homelab"
CLUSTER_CONFIG="kind/cluster.yaml"
APP_RELEASE="homelab-api-app"
APP_NAMESPACE="app"
MONITORING_RELEASE="kube-prometheus-stack"
MONITORING_NAMESPACE="monitoring"
MONITORING_VALUES="charts/monitoring/values-kind.yaml"
INGRESS_RELEASE="ingress-nginx"
INGRESS_NAMESPACE="ingress-nginx"
PORT_FORWARD_DIR=".kind-port-forwards"
ENABLE_PORT_FORWARDS="${ENABLE_PORT_FORWARDS:-true}"
GRAFANA_LOCAL_PORT="${GRAFANA_LOCAL_PORT:-13000}"
PROMETHEUS_LOCAL_PORT="${PROMETHEUS_LOCAL_PORT:-9090}"

start_port_forward() {
  local name="$1"
  local namespace="$2"
  local service="$3"
  local local_port="$4"
  local remote_port="$5"
  local pid_file="${PORT_FORWARD_DIR}/${name}.pid"
  local log_file="${PORT_FORWARD_DIR}/${name}.log"

  mkdir -p "${PORT_FORWARD_DIR}"

  if [[ -f "${pid_file}" ]]; then
    local existing_pid
    existing_pid="$(cat "${pid_file}")"
    if kill -0 "${existing_pid}" >/dev/null 2>&1; then
      echo "Port-forward '${name}' already running (PID ${existing_pid}) on localhost:${local_port}."
      return 0
    fi
    rm -f "${pid_file}"
  fi

  if lsof -tiTCP:"${local_port}" -sTCP:LISTEN >/dev/null 2>&1; then
    echo "Warning: localhost:${local_port} is already in use. Skipping '${name}' port-forward."
    return 0
  fi

  nohup kubectl --context "kind-${CLUSTER_NAME}" -n "${namespace}" \
    port-forward "svc/${service}" "${local_port}:${remote_port}" >"${log_file}" 2>&1 &
  local pf_pid=$!
  sleep 1

  if kill -0 "${pf_pid}" >/dev/null 2>&1; then
    echo "Started '${name}' port-forward on localhost:${local_port} (PID ${pf_pid})."
    echo "${pf_pid}" >"${pid_file}"
  else
    echo "Warning: failed to start '${name}' port-forward. Check ${log_file}."
  fi
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

if [[ ! -f "${CLUSTER_CONFIG}" ]]; then
  echo "Error: cluster config not found at ${CLUSTER_CONFIG}."
  exit 1
fi

if [[ ! -f "${MONITORING_VALUES}" ]]; then
  echo "Error: monitoring values file not found at ${MONITORING_VALUES}."
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
echo "Adding/updating prometheus-community Helm repo..."
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts >/dev/null 2>&1 || true
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

echo "Installing/upgrading monitoring stack..."
helm upgrade --install "${MONITORING_RELEASE}" prometheus-community/kube-prometheus-stack \
  --kube-context "kind-${CLUSTER_NAME}" \
  --namespace "${MONITORING_NAMESPACE}" \
  --create-namespace \
  --values "${MONITORING_VALUES}"

kubectl rollout status deployment/${MONITORING_RELEASE}-operator \
  -n "${MONITORING_NAMESPACE}" \
  --context "kind-${CLUSTER_NAME}" \
  --timeout=180s

kubectl rollout status deployment/${MONITORING_RELEASE}-grafana \
  -n "${MONITORING_NAMESPACE}" \
  --context "kind-${CLUSTER_NAME}" \
  --timeout=180s

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
  --values charts/homelab-api/values-dev.yaml \
  --set serviceMonitor.enabled=true \
  --set grafanaDashboard.enabled=true

kubectl rollout status deployment/${APP_RELEASE} \
  -n "${APP_NAMESPACE}" \
  --context "kind-${CLUSTER_NAME}" \
  --timeout=180s

echo "Setup complete."
echo "Verify app endpoint: curl http://localhost:8080/health"

if [[ "${ENABLE_PORT_FORWARDS}" == "true" ]]; then
  echo "Starting background port-forwards..."
  start_port_forward "grafana" "${MONITORING_NAMESPACE}" "${MONITORING_RELEASE}-grafana" "${GRAFANA_LOCAL_PORT}" "80"
  start_port_forward "prometheus" "${MONITORING_NAMESPACE}" "${MONITORING_RELEASE}-prometheus" "${PROMETHEUS_LOCAL_PORT}" "9090"
  echo "Grafana URL: http://localhost:${GRAFANA_LOCAL_PORT}"
  echo "Prometheus URL: http://localhost:${PROMETHEUS_LOCAL_PORT}"
else
  echo "Background port-forwards disabled (ENABLE_PORT_FORWARDS=${ENABLE_PORT_FORWARDS})."
  echo "Access Grafana manually: kubectl -n monitoring port-forward svc/kube-prometheus-stack-grafana ${GRAFANA_LOCAL_PORT}:80"
  echo "Access Prometheus manually: kubectl -n monitoring port-forward svc/kube-prometheus-stack-prometheus ${PROMETHEUS_LOCAL_PORT}:9090"
fi
