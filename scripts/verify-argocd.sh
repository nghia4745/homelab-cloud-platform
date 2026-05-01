#!/usr/bin/env bash
set -euo pipefail

if ! command -v kubectl >/dev/null 2>&1; then
  echo "Error: kubectl is required but not installed."
  exit 1
fi

CONTEXT="${KUBE_CONTEXT:-$(kubectl config current-context)}"
ARGOCD_NAMESPACE="${ARGOCD_NAMESPACE:-argocd}"
ARGOCD_APP_NAME="${ARGOCD_APP_NAME:-homelab-api}"
APP_NAMESPACE="${APP_NAMESPACE:-app}"
APP_DEPLOYMENT="${APP_DEPLOYMENT:-homelab-api-app}"
VALUES_FILE="${VALUES_FILE:-charts/homelab-api/values.yaml}"

failures=0
app_revision=""

pass() {
  echo "PASS: $1"
}

fail() {
  echo "FAIL: $1"
  failures=$((failures + 1))
}

warn() {
  echo "WARN: $1"
}

echo "Context: ${CONTEXT}"

if [[ ! -f "${VALUES_FILE}" ]]; then
  fail "Values file not found: ${VALUES_FILE}"
fi

if ! kubectl --context "${CONTEXT}" -n "${ARGOCD_NAMESPACE}" get pods >/dev/null 2>&1; then
  fail "ArgoCD namespace '${ARGOCD_NAMESPACE}' is not reachable in context '${CONTEXT}'"
else
  pod_lines="$(kubectl --context "${CONTEXT}" -n "${ARGOCD_NAMESPACE}" get pods -o jsonpath='{range .items[*]}{.metadata.name}{" "}{range .status.containerStatuses[*]}{.ready}{" "}{end}{"\n"}{end}')"
  if [[ -z "${pod_lines}" ]]; then
    fail "No ArgoCD pods found in namespace '${ARGOCD_NAMESPACE}'"
  elif echo "${pod_lines}" | grep -q "false"; then
    fail "Some ArgoCD pods are not ready"
    echo "${pod_lines}"
  else
    pass "All ArgoCD pods are ready"
  fi
fi

if ! kubectl --context "${CONTEXT}" -n "${ARGOCD_NAMESPACE}" get applications.argoproj.io "${ARGOCD_APP_NAME}" >/dev/null 2>&1; then
  fail "ArgoCD application '${ARGOCD_APP_NAME}' not found in namespace '${ARGOCD_NAMESPACE}'"
else
  sync_status="$(kubectl --context "${CONTEXT}" -n "${ARGOCD_NAMESPACE}" get applications.argoproj.io "${ARGOCD_APP_NAME}" -o jsonpath='{.status.sync.status}')"
  health_status="$(kubectl --context "${CONTEXT}" -n "${ARGOCD_NAMESPACE}" get applications.argoproj.io "${ARGOCD_APP_NAME}" -o jsonpath='{.status.health.status}')"
  revision="$(kubectl --context "${CONTEXT}" -n "${ARGOCD_NAMESPACE}" get applications.argoproj.io "${ARGOCD_APP_NAME}" -o jsonpath='{.status.sync.revision}')"
  app_revision="${revision}"

  if [[ "${sync_status}" == "Synced" ]]; then
    pass "Application sync status is Synced"
  else
    fail "Application sync status is '${sync_status}'"
  fi

  if [[ "${health_status}" == "Healthy" ]]; then
    pass "Application health status is Healthy"
  else
    fail "Application health status is '${health_status}'"
  fi

  if [[ -n "${revision}" ]]; then
    pass "Application revision: ${revision}"
  else
    fail "Application revision is empty"
  fi
fi

if ! kubectl --context "${CONTEXT}" -n "${APP_NAMESPACE}" get deploy "${APP_DEPLOYMENT}" >/dev/null 2>&1; then
  fail "Deployment '${APP_DEPLOYMENT}' not found in namespace '${APP_NAMESPACE}'"
else
  deployed_image="$(kubectl --context "${CONTEXT}" -n "${APP_NAMESPACE}" get deploy "${APP_DEPLOYMENT}" -o jsonpath='{.spec.template.spec.containers[0].image}')"
  updated_replicas="$(kubectl --context "${CONTEXT}" -n "${APP_NAMESPACE}" get deploy "${APP_DEPLOYMENT}" -o jsonpath='{.status.updatedReplicas}')"
  replicas="$(kubectl --context "${CONTEXT}" -n "${APP_NAMESPACE}" get deploy "${APP_DEPLOYMENT}" -o jsonpath='{.status.replicas}')"

  desired_tag=""
  if [[ -f "${VALUES_FILE}" ]]; then
    desired_tag="$(awk '/^  tag: / {print $2; exit}' "${VALUES_FILE}")"
  fi

  deployed_tag="${deployed_image##*:}"

  if [[ -n "${deployed_image}" ]]; then
    pass "Deployment image: ${deployed_image}"
  else
    fail "Deployment image is empty"
  fi

  if [[ -n "${desired_tag}" ]]; then
    local_head=""
    if command -v git >/dev/null 2>&1; then
      local_head="$(git rev-parse HEAD 2>/dev/null || true)"
    fi

    if [[ -n "${app_revision}" && -n "${local_head}" && "${local_head}" != "${app_revision}" ]]; then
      warn "Local HEAD (${local_head}) differs from ArgoCD revision (${app_revision}); skipping strict values tag match check"
    elif [[ "${deployed_tag}" == "${desired_tag}" ]]; then
      pass "Deployed image tag matches values file (${desired_tag})"
    else
      fail "Image tag mismatch (deployed=${deployed_tag}, desired=${desired_tag})"
    fi
  else
    fail "Could not read desired tag from ${VALUES_FILE}"
  fi

  if [[ -n "${updated_replicas}" && -n "${replicas}" && "${updated_replicas}" == "${replicas}" ]]; then
    pass "Rollout complete (${updated_replicas}/${replicas} updated)"
  else
    fail "Rollout incomplete (${updated_replicas:-0}/${replicas:-0} updated)"
  fi
fi

echo
if [[ "${failures}" -eq 0 ]]; then
  echo "ArgoCD verification successful."
  exit 0
fi

echo "ArgoCD verification failed with ${failures} issue(s)."
exit 1