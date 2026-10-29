#!/usr/bin/env bash
# Verifica o rollout dos add-ons e imprime um resumo sem expor segredos.

set -euo pipefail

NEWRELIC_NAMESPACE="${NEWRELIC_NAMESPACE:-newrelic}"
METRICS_SERVER_NAMESPACE="${METRICS_SERVER_NAMESPACE:-kube-system}"
APP_NAMESPACE="${APP_NAMESPACE:-oficina}"
ROLLOUT_TIMEOUT="${ROLLOUT_TIMEOUT:-5m}"
SUMMARY_FILE="${GITHUB_STEP_SUMMARY:-/dev/stdout}"

section() {
  printf '\n## %s\n\n' "$1" | tee -a "${SUMMARY_FILE}" >/dev/null
  printf '==> %s\n' "$1"
}

capture() {
  local output
  output="$("$@" 2>&1 || true)"
  printf '%s\n' "${output}"
  {
    # shellcheck disable=SC2016
    printf '```text\n%s\n```\n' "${output}"
  } >>"${SUMMARY_FILE}"
}

section "Metrics Server"
kubectl rollout status deployment/metrics-server \
  --namespace "${METRICS_SERVER_NAMESPACE}" --timeout "${ROLLOUT_TIMEOUT}"
capture kubectl get deployment metrics-server --namespace "${METRICS_SERVER_NAMESPACE}"

section "Namespace New Relic"
capture kubectl get pods --namespace "${NEWRELIC_NAMESPACE}" -o wide

section "DaemonSets e Deployments do nri-bundle"
capture kubectl get daemonset,deployment --namespace "${NEWRELIC_NAMESPACE}"

section "Secret da license key (somente metadados)"
capture kubectl get secret newrelic-license --namespace "${NEWRELIC_NAMESPACE}" \
  -o "custom-columns=NAME:.metadata.name,TYPE:.type,KEYS:.data[*]"

section "Aplicação e HPA"
capture kubectl get pods --namespace "${APP_NAMESPACE}"
capture kubectl get hpa --namespace "${APP_NAMESPACE}"

section "Métricas de recursos"
capture kubectl top nodes
capture kubectl top pods --namespace "${APP_NAMESPACE}"
