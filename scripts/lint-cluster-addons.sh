#!/usr/bin/env bash
# Validação offline dos charts: renderiza os manifests com valores de
# placeholder, sem cluster, sem credenciais e sem license key real.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
ADDONS_DIR="${REPO_DIR}/kubernetes/addons"
OUTPUT_DIR="${OUTPUT_DIR:-$(mktemp -d)}"

# shellcheck disable=SC1091
source "${ADDONS_DIR}/versions.env"

retry() {
  local attempt
  for attempt in 1 2 3; do
    if "$@"; then
      return 0
    fi
    if [[ "${attempt}" -lt 3 ]]; then
      echo "Download Helm falhou (tentativa ${attempt}/3); tentando novamente..." >&2
      sleep $((attempt * 5))
    fi
  done
  return 1
}

helm repo add metrics-server "${METRICS_SERVER_CHART_REPO}" >/dev/null
helm repo add newrelic "${NRI_BUNDLE_CHART_REPO}" >/dev/null
retry helm repo update metrics-server newrelic >/dev/null

echo "==> helm lint / template do Metrics Server ${METRICS_SERVER_CHART_VERSION}"
retry helm template metrics-server metrics-server/metrics-server \
  --version "${METRICS_SERVER_CHART_VERSION}" \
  --namespace kube-system \
  --values "${ADDONS_DIR}/metrics-server.values.yaml" \
  >"${OUTPUT_DIR}/metrics-server.yaml"

for environment in homolog production; do
  echo "==> helm template do nri-bundle ${NRI_BUNDLE_CHART_VERSION} (${environment})"
  retry helm template newrelic-bundle newrelic/nri-bundle \
    --version "${NRI_BUNDLE_CHART_VERSION}" \
    --namespace newrelic \
    --values "${ADDONS_DIR}/nri-bundle.values.yaml" \
    --values "${ADDONS_DIR}/nri-bundle.values.${environment}.yaml" \
    --set "global.cluster=oficina-${environment}" \
    --set "global.customAttributes.environment=${environment}" \
    >"${OUTPUT_DIR}/nri-bundle-${environment}.yaml"

  grep -q "oficina-${environment}" "${OUTPUT_DIR}/nri-bundle-${environment}.yaml" ||
    {
      echo "::error::cluster não propagado no template de ${environment}"
      exit 1
    }
  grep -q "newrelic-license" "${OUTPUT_DIR}/nri-bundle-${environment}.yaml" ||
    {
      echo "::error::Secret externo da license key não referenciado em ${environment}"
      exit 1
    }
done

echo "==> Manifests renderizados em ${OUTPUT_DIR}"
