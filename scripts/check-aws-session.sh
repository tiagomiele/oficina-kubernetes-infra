#!/usr/bin/env bash
# Falha explicitamente quando as credenciais temporárias do AWS Academy estão
# ausentes ou expiradas. Nenhum valor de credencial é impresso.

set -euo pipefail

fail() {
  printf '::error::%s\n' "$1" >&2
  exit 1
}

for variable in AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY; do
  [ -n "${!variable:-}" ] || fail "${variable} não configurada no GitHub Environment."
done

if [ -z "${AWS_SESSION_TOKEN:-}" ]; then
  echo "::warning::AWS_SESSION_TOKEN vazio. Sessões do AWS Academy sempre exigem token temporário."
fi

command -v aws >/dev/null 2>&1 || fail "AWS CLI não disponível no runner."

if ! identity="$(aws sts get-caller-identity --output json 2>&1)"; then
  case "${identity}" in
  *ExpiredToken*)
    fail "Credenciais expiradas (ExpiredToken). Reinicie o Learner Lab e atualize os secrets do GitHub Environment."
    ;;
  *InvalidClientTokenId* | *SignatureDoesNotMatch*)
    fail "Credenciais inválidas. Atualize AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY e AWS_SESSION_TOKEN."
    ;;
  *)
    fail "Falha ao validar a sessão AWS: ${identity}"
    ;;
  esac
fi

account="$(printf '%s' "${identity}" | python3 -c 'import json,sys; print(json.load(sys.stdin)["Account"])')"
arn="$(printf '%s' "${identity}" | python3 -c 'import json,sys; print(json.load(sys.stdin)["Arn"])')"

echo "Sessão AWS válida na conta ${account}."

if [ -n "${GITHUB_STEP_SUMMARY:-}" ]; then
  {
    echo "## Sessão AWS"
    echo
    echo "- conta: ${account}"
    echo "- identidade: ${arn}"
  } >>"${GITHUB_STEP_SUMMARY}"
fi
