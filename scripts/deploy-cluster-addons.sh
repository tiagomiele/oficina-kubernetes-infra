#!/usr/bin/env bash
# Instala de forma idempotente o Metrics Server e o chart oficial
# newrelic/nri-bundle em um cluster EKS já existente.
#
# A license key é lida da variável de ambiente NEW_RELIC_LICENSE_KEY,
# transformada em Secret Kubernetes e nunca é impressa, versionada ou
# gravada em arquivo de values.
#
# Uso:
#   CLUSTER_NAME=oficina-homolog ENVIRONMENT=homolog \
#   NEW_RELIC_LICENSE_KEY=*** ./scripts/deploy-cluster-addons.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
ADDONS_DIR="${REPO_DIR}/kubernetes/addons"

# shellcheck disable=SC1091
source "${ADDONS_DIR}/versions.env"

ENVIRONMENT="${ENVIRONMENT:-homolog}"
AWS_REGION="${AWS_REGION:-us-west-2}"
CLUSTER_NAME="${CLUSTER_NAME:-}"
NEWRELIC_NAMESPACE="${NEWRELIC_NAMESPACE:-newrelic}"
NEWRELIC_SECRET_NAME="${NEWRELIC_SECRET_NAME:-newrelic-license}"
NEWRELIC_SECRET_KEY="licenseKey"
METRICS_SERVER_NAMESPACE="${METRICS_SERVER_NAMESPACE:-kube-system}"
HELM_TIMEOUT="${HELM_TIMEOUT:-10m}"
SKIP_KUBECONFIG="${SKIP_KUBECONFIG:-false}"

log() { printf '==> %s\n' "$1"; }
fail() {
  printf '::error::%s\n' "$1" >&2
  exit 1
}

case "${ENVIRONMENT}" in
homolog | production) ;;
*) fail "ENVIRONMENT deve ser homolog ou production." ;;
esac

[ -n "${CLUSTER_NAME}" ] || fail "CLUSTER_NAME não informado."
[ -n "${NEW_RELIC_LICENSE_KEY:-}" ] || fail "NEW_RELIC_LICENSE_KEY não informada. Cadastre o secret no GitHub Environment ${ENVIRONMENT}."

for binary in aws kubectl helm; do
  command -v "${binary}" >/dev/null 2>&1 || fail "Binário obrigatório ausente: ${binary}."
done

log "Validando credenciais AWS"
aws sts get-caller-identity --output text --query Arn >/dev/null ||
  fail "Credenciais AWS ausentes ou expiradas (ExpiredToken). Renove a sessão do AWS Academy."

if [ "${SKIP_KUBECONFIG}" != "true" ]; then
  log "Configurando kubeconfig de ${CLUSTER_NAME}"
  aws eks update-kubeconfig --region "${AWS_REGION}" --name "${CLUSTER_NAME}" >/dev/null
fi

log "Cluster acessível: $(kubectl version -o json | python3 -c 'import json,sys; print(json.load(sys.stdin)["serverVersion"]["gitVersion"])')"

log "Registrando repositórios Helm"
helm repo add metrics-server "${METRICS_SERVER_CHART_REPO}" >/dev/null
helm repo add newrelic "${NRI_BUNDLE_CHART_REPO}" >/dev/null
helm repo update metrics-server newrelic >/dev/null

log "Instalando Metrics Server ${METRICS_SERVER_CHART_VERSION}"
helm upgrade --install metrics-server metrics-server/metrics-server \
  --version "${METRICS_SERVER_CHART_VERSION}" \
  --namespace "${METRICS_SERVER_NAMESPACE}" \
  --values "${ADDONS_DIR}/metrics-server.values.yaml" \
  --wait --timeout "${HELM_TIMEOUT}"

log "Garantindo namespace ${NEWRELIC_NAMESPACE}"
kubectl create namespace "${NEWRELIC_NAMESPACE}" --dry-run=client -o yaml | kubectl apply -f - >/dev/null

log "Aplicando Secret ${NEWRELIC_SECRET_NAME} (conteúdo nunca é exibido)"
kubectl create secret generic "${NEWRELIC_SECRET_NAME}" \
  --namespace "${NEWRELIC_NAMESPACE}" \
  --from-literal="${NEWRELIC_SECRET_KEY}=${NEW_RELIC_LICENSE_KEY}" \
  --dry-run=client -o yaml |
  kubectl apply -f - >/dev/null

log "Instalando nri-bundle ${NRI_BUNDLE_CHART_VERSION} para ${CLUSTER_NAME}"
helm upgrade --install newrelic-bundle newrelic/nri-bundle \
  --version "${NRI_BUNDLE_CHART_VERSION}" \
  --namespace "${NEWRELIC_NAMESPACE}" \
  --values "${ADDONS_DIR}/nri-bundle.values.yaml" \
  --values "${ADDONS_DIR}/nri-bundle.values.${ENVIRONMENT}.yaml" \
  --set "global.cluster=${CLUSTER_NAME}" \
  --set "global.customAttributes.environment=${ENVIRONMENT}" \
  --set "global.customSecretName=${NEWRELIC_SECRET_NAME}" \
  --set "global.customSecretLicenseKey=${NEWRELIC_SECRET_KEY}" \
  --wait --timeout "${HELM_TIMEOUT}"

log "Deploy dos add-ons concluído"
