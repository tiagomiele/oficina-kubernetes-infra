# A API key e o account id são fornecidos por variáveis sensíveis do workspace
# HCP Terraform (ou pelas variáveis de ambiente NEW_RELIC_API_KEY e
# NEW_RELIC_ACCOUNT_ID). Nenhum valor real é versionado.

provider "newrelic" {
  account_id = var.newrelic_account_id
  api_key    = var.newrelic_api_key
  region     = var.newrelic_region
}
