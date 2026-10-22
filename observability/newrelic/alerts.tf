# Política e condições de alerta. Os limiares vêm de var.alert_thresholds e
# variam por ambiente.

resource "newrelic_alert_policy" "main" {
  count = local.count_enabled

  name                = "Oficina — ${var.environment}"
  incident_preference = var.alert_incident_preference
}

locals {
  policy_id = one(newrelic_alert_policy.main[*].id)

  # Condições estáticas: cada entrada gera um newrelic_nrql_alert_condition.
  alert_conditions = {
    healthcheck_indisponivel = {
      description = "Healthcheck público falhou no monitor sintético."
      query       = "SELECT filter(count(*), WHERE result != 'SUCCESS') FROM SyntheticCheck WHERE monitorName = '${local.synthetic_monitor_name}'"
      operator    = "above_or_equals"
      threshold   = local.thresholds.synthetic_failures
      duration    = 300
    }

    taxa_de_erro_alta = {
      description = "Percentual de transações com erro acima do limite."
      query       = "SELECT percentage(count(*), WHERE error IS true) FROM Transaction WHERE ${local.apm_filter}"
      operator    = "above"
      threshold   = local.thresholds.error_rate_percent
      duration    = local.thresholds.condition_duration_seconds
    }

    latencia_p95_alta = {
      description = "Percentil 95 de latência da API acima do limite."
      query       = "SELECT percentile(duration, 95) * 1000 FROM Transaction WHERE ${local.apm_filter}"
      operator    = "above"
      threshold   = local.thresholds.latency_p95_ms
      duration    = local.thresholds.condition_duration_seconds
    }

    falha_processamento_os = {
      description = "Falhas no processamento de ordens de serviço."
      query       = "SELECT count(*) FROM OrdemServicoProcessamentoFalhou WHERE ${local.business_filter}"
      operator    = "above_or_equals"
      threshold   = local.thresholds.os_processing_failures
      duration    = 300
    }

    falha_integracao_recorrente = {
      description = "Falhas recorrentes em integrações externas."
      query       = "SELECT count(*) FROM IntegracaoExternaFalhou WHERE ${local.business_filter}"
      operator    = "above_or_equals"
      threshold   = local.thresholds.integration_failures
      duration    = 600
    }

    pod_indisponivel = {
      description = "Réplicas disponíveis abaixo do desejado no deployment da aplicação."
      query       = "SELECT latest(podsDesired - podsAvailable) FROM K8sDeploymentSample WHERE ${local.deployment_where}"
      operator    = "above"
      threshold   = 0
      duration    = 300
    }

    reinicios_repetidos = {
      description = "Containers reiniciando repetidamente."
      query       = "SELECT sum(restartCountDelta) FROM K8sContainerSample WHERE ${local.workload_filter}"
      operator    = "above_or_equals"
      threshold   = local.thresholds.container_restarts
      duration    = 600
    }

    cpu_alta = {
      description = "Uso de CPU do container próximo do limite."
      query       = "SELECT average(cpuUsedCores / cpuLimitCores) * 100 FROM K8sContainerSample WHERE ${local.workload_filter}"
      operator    = "above"
      threshold   = local.thresholds.container_cpu_percent
      duration    = local.thresholds.condition_duration_seconds
    }

    memoria_alta = {
      description = "Uso de memória do container próximo do limite."
      query       = "SELECT average(memoryWorkingSetUtilization) FROM K8sContainerSample WHERE ${local.workload_filter}"
      operator    = "above"
      threshold   = local.thresholds.container_memory_percent
      duration    = local.thresholds.condition_duration_seconds
    }

    hpa_no_maximo = {
      description = "HPA atingiu o número máximo de réplicas."
      query       = "SELECT latest(desiredReplicas - maxReplicas) FROM K8sHpaSample WHERE ${local.workload_filter}"
      operator    = "above_or_equals"
      threshold   = 0
      duration    = 600
    }

    falha_lambda_recorrente = {
      description = "Erros recorrentes nas Lambdas de autenticação."
      query       = "SELECT count(*) FROM TransactionError WHERE appName IN (${local.lambda_filter})"
      operator    = "above_or_equals"
      threshold   = local.thresholds.lambda_errors
      duration    = 600
    }

    api_gateway_5xx = {
      description = "Respostas 5xx recorrentes no API Gateway."
      query       = "SELECT filter(count(*), WHERE numeric(status) >= 500) FROM Log WHERE ${local.api_gateway_filter}"
      operator    = "above_or_equals"
      threshold   = local.thresholds.api_gateway_5xx_errors
      duration    = 300
    }

    api_gateway_latencia = {
      description = "P95 da latência total do API Gateway acima do limite."
      query       = "SELECT percentile(numeric(responseLatency), 95) FROM Log WHERE ${local.api_gateway_filter}"
      operator    = "above"
      threshold   = local.thresholds.api_gateway_latency_ms
      duration    = local.thresholds.condition_duration_seconds
    }

    rds_cpu_alta = {
      description = "CPU média do RDS acima do limite."
      query       = "SELECT average(cpuUtilizationPercent) FROM OficinaRdsSample WHERE ${local.rds_filter}"
      operator    = "above"
      threshold   = local.thresholds.rds_cpu_percent
      duration    = local.thresholds.condition_duration_seconds
    }

    rds_conexoes_altas = {
      description = "Número médio de conexões do RDS acima do limite."
      query       = "SELECT average(databaseConnections) FROM OficinaRdsSample WHERE ${local.rds_filter}"
      operator    = "above"
      threshold   = local.thresholds.rds_connections
      duration    = local.thresholds.condition_duration_seconds
    }

    rds_armazenamento_baixo = {
      description = "Armazenamento livre do RDS abaixo do limite."
      query       = "SELECT average(freeStorageBytes) / 1073741824 FROM OficinaRdsSample WHERE ${local.rds_filter}"
      operator    = "below"
      threshold   = local.thresholds.rds_free_storage_gib
      duration    = local.thresholds.condition_duration_seconds
    }

    rds_erros_postgresql = {
      description = "Erros PostgreSQL detectados na janela de coleta do RDS."
      query       = "SELECT latest(postgresErrorCount) FROM OficinaRdsSample WHERE ${local.rds_filter}"
      operator    = "above_or_equals"
      threshold   = local.thresholds.rds_postgres_errors
      duration    = 300
    }
  }
}

resource "newrelic_nrql_alert_condition" "conditions" {
  for_each = local.count_enabled == 1 ? local.alert_conditions : {}

  account_id                   = var.newrelic_account_id
  policy_id                    = local.policy_id
  type                         = "static"
  name                         = "${local.name} — ${replace(each.key, "_", " ")}"
  description                  = each.value.description
  enabled                      = true
  aggregation_method           = "event_flow"
  aggregation_window           = 60
  aggregation_delay            = local.thresholds.condition_evaluation_delay_s
  violation_time_limit_seconds = local.thresholds.violation_time_limit_seconds

  nrql {
    query = each.value.query
  }

  critical {
    operator              = each.value.operator
    threshold             = each.value.threshold
    threshold_duration    = each.value.duration
    threshold_occurrences = "all"
  }
}

# Ausência de telemetria: nenhum dado do cluster recebido dentro da janela.
resource "newrelic_nrql_alert_condition" "telemetria_ausente" {
  count = local.count_enabled

  account_id                   = var.newrelic_account_id
  policy_id                    = local.policy_id
  type                         = "static"
  name                         = "${local.name} — telemetria ausente"
  description                  = "O cluster parou de enviar telemetria para o New Relic."
  enabled                      = true
  aggregation_method           = "event_flow"
  aggregation_window           = 60
  aggregation_delay            = local.thresholds.condition_evaluation_delay_s
  violation_time_limit_seconds = local.thresholds.violation_time_limit_seconds

  expiration_duration            = local.thresholds.telemetry_expiration_seconds
  open_violation_on_expiration   = true
  close_violations_on_expiration = true

  nrql {
    query = "SELECT count(*) FROM K8sClusterSample WHERE ${local.cluster_filter}"
  }

  critical {
    operator              = "below"
    threshold             = 1
    threshold_duration    = 300
    threshold_occurrences = "all"
  }
}
