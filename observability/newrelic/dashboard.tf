# Dashboard único com quatro páginas: negócio, aplicação, Kubernetes e
# serverless/API Gateway. As consultas usam apenas atributos não sensíveis.

resource "newrelic_one_dashboard" "oficina" {
  count = local.count_enabled

  name        = "Oficina — ${var.environment}"
  permissions = "public_read_write"

  page {
    name = "Negócio"

    widget_billboard {
      title  = "Ordens de serviço criadas (24h)"
      row    = 1
      column = 1
      width  = 4
      height = 3

      nrql_query {
        account_id = var.newrelic_account_id
        query      = "SELECT count(*) AS 'OS criadas' FROM OrdemServicoCriada WHERE ${local.business_filter} SINCE 24 hours ago"
      }
    }

    widget_line {
      title  = "Volume diário de ordens de serviço"
      row    = 1
      column = 5
      width  = 8
      height = 3

      nrql_query {
        account_id = var.newrelic_account_id
        query      = "SELECT count(*) FROM OrdemServicoCriada WHERE ${local.business_filter} TIMESERIES 1 day SINCE 14 days ago"
      }
    }

    widget_bar {
      title  = "Tempo médio por etapa (diagnóstico, execução, finalização)"
      row    = 4
      column = 1
      width  = 6
      height = 3

      nrql_query {
        account_id = var.newrelic_account_id
        query      = "SELECT average(duracaoMilissegundos) / 1000 AS 'segundos' FROM OrdemServicoStatusAlterado WHERE ${local.business_filter} AND statusAnterior IN ('EM_DIAGNOSTICO', 'EM_EXECUCAO', 'AGUARDANDO_PAGAMENTO') FACET statusAnterior SINCE 7 days ago"
      }
    }

    widget_stacked_bar {
      title  = "Transições de status"
      row    = 4
      column = 7
      width  = 6
      height = 3

      nrql_query {
        account_id = var.newrelic_account_id
        query      = "SELECT count(*) FROM OrdemServicoStatusAlterado WHERE ${local.business_filter} FACET statusAnterior, novoStatus TIMESERIES 1 day SINCE 7 days ago"
      }
    }

    widget_line {
      title  = "Falhas no processamento de ordens de serviço"
      row    = 7
      column = 1
      width  = 6
      height = 3

      nrql_query {
        account_id = var.newrelic_account_id
        query      = "SELECT count(*) FROM OrdemServicoProcessamentoFalhou WHERE ${local.business_filter} FACET codigoErro TIMESERIES SINCE 24 hours ago"
      }
    }

    widget_table {
      title  = "Falhas de integração externa"
      row    = 7
      column = 7
      width  = 6
      height = 3

      nrql_query {
        account_id = var.newrelic_account_id
        query      = "SELECT count(*) FROM IntegracaoExternaFalhou WHERE ${local.business_filter} FACET operacao, codigoErro SINCE 24 hours ago"
      }
    }
  }

  page {
    name = "Aplicação"

    widget_line {
      title  = "Throughput (requisições por minuto)"
      row    = 1
      column = 1
      width  = 6
      height = 3

      nrql_query {
        account_id = var.newrelic_account_id
        query      = "SELECT rate(count(*), 1 minute) FROM Transaction WHERE ${local.apm_filter} TIMESERIES SINCE 6 hours ago"
      }
    }

    widget_line {
      title  = "Latência média e P95 (ms)"
      row    = 1
      column = 7
      width  = 6
      height = 3

      nrql_query {
        account_id = var.newrelic_account_id
        query      = "SELECT average(duration) * 1000 AS 'Média', percentile(duration, 95) * 1000 AS 'P95' FROM Transaction WHERE ${local.apm_filter} TIMESERIES SINCE 6 hours ago"
      }
    }

    widget_line {
      title  = "Respostas 4xx e 5xx"
      row    = 4
      column = 1
      width  = 6
      height = 3

      nrql_query {
        account_id = var.newrelic_account_id
        query      = "SELECT filter(count(*), WHERE numeric(http.statusCode) >= 400 AND numeric(http.statusCode) < 500) AS '4xx', filter(count(*), WHERE numeric(http.statusCode) >= 500) AS '5xx' FROM Transaction WHERE ${local.apm_filter} TIMESERIES SINCE 6 hours ago"
      }
    }

    widget_billboard {
      title  = "Taxa de erro (%)"
      row    = 4
      column = 7
      width  = 3
      height = 3

      nrql_query {
        account_id = var.newrelic_account_id
        query      = "SELECT percentage(count(*), WHERE error IS true) FROM Transaction WHERE ${local.apm_filter} SINCE 1 hour ago"
      }
    }

    widget_billboard {
      title  = "Uptime do healthcheck (%)"
      row    = 4
      column = 10
      width  = 3
      height = 3

      nrql_query {
        account_id = var.newrelic_account_id
        query      = "SELECT percentage(count(*), WHERE result = 'SUCCESS') FROM SyntheticCheck WHERE monitorName = '${local.synthetic_monitor_name}' SINCE 24 hours ago"
      }
    }

    widget_table {
      title  = "Transações mais lentas"
      row    = 7
      column = 1
      width  = 6
      height = 3

      nrql_query {
        account_id = var.newrelic_account_id
        query      = "SELECT count(*) AS 'Chamadas', percentile(duration, 95) * 1000 AS 'P95 (ms)' FROM Transaction WHERE ${local.apm_filter} FACET name SINCE 6 hours ago LIMIT 15"
      }
    }

    widget_line {
      title  = "Logs de erro correlacionados (trace.id presente)"
      row    = 7
      column = 7
      width  = 6
      height = 3

      nrql_query {
        account_id = var.newrelic_account_id
        query      = "SELECT count(*) FROM Log WHERE cluster_name = '${local.cluster}' AND namespace_name = '${var.kubernetes_namespace}' AND level IN ('ERROR', 'WARN') FACET level TIMESERIES SINCE 6 hours ago"
      }
    }
  }

  page {
    name = "Kubernetes"

    widget_line {
      title  = "CPU por pod (%)"
      row    = 1
      column = 1
      width  = 6
      height = 3

      nrql_query {
        account_id = var.newrelic_account_id
        query      = "SELECT average(cpuUsedCores / cpuLimitCores) * 100 FROM K8sContainerSample WHERE ${local.workload_filter} FACET podName TIMESERIES SINCE 3 hours ago"
      }
    }

    widget_line {
      title  = "Memória por pod (%)"
      row    = 1
      column = 7
      width  = 6
      height = 3

      nrql_query {
        account_id = var.newrelic_account_id
        query      = "SELECT average(memoryWorkingSetUtilization) FROM K8sContainerSample WHERE ${local.workload_filter} FACET podName TIMESERIES SINCE 3 hours ago"
      }
    }

    widget_line {
      title  = "Réplicas desejadas e disponíveis"
      row    = 4
      column = 1
      width  = 6
      height = 3

      nrql_query {
        account_id = var.newrelic_account_id
        query      = "SELECT latest(podsDesired) AS 'Desejadas', latest(podsAvailable) AS 'Disponíveis' FROM K8sDeploymentSample WHERE ${local.deployment_where} TIMESERIES SINCE 6 hours ago"
      }
    }

    widget_line {
      title  = "HPA: réplicas atuais, desejadas e máximo"
      row    = 4
      column = 7
      width  = 6
      height = 3

      nrql_query {
        account_id = var.newrelic_account_id
        query      = "SELECT latest(currentReplicas) AS 'Atuais', latest(desiredReplicas) AS 'Desejadas', latest(maxReplicas) AS 'Máximo' FROM K8sHpaSample WHERE ${local.workload_filter} TIMESERIES SINCE 6 hours ago"
      }
    }

    widget_billboard {
      title  = "Reinícios de container (6h)"
      row    = 7
      column = 1
      width  = 4
      height = 3

      nrql_query {
        account_id = var.newrelic_account_id
        query      = "SELECT sum(restartCountDelta) FROM K8sContainerSample WHERE ${local.workload_filter} SINCE 6 hours ago"
      }
    }

    widget_table {
      title  = "Pods e status"
      row    = 7
      column = 5
      width  = 4
      height = 3

      nrql_query {
        account_id = var.newrelic_account_id
        query      = "SELECT latest(status) AS 'Status', latest(isReady) AS 'Pronto' FROM K8sPodSample WHERE ${local.workload_filter} FACET podName SINCE 1 hour ago"
      }
    }

    widget_table {
      title  = "Eventos do cluster"
      row    = 7
      column = 9
      width  = 4
      height = 3

      nrql_query {
        account_id = var.newrelic_account_id
        query      = "SELECT count(*) FROM InfrastructureEvent WHERE ${local.cluster_filter} FACET event.reason SINCE 6 hours ago LIMIT 15"
      }
    }
  }

  page {
    name = "Serverless e API Gateway"

    widget_line {
      title  = "Invocações das Lambdas"
      row    = 1
      column = 1
      width  = 6
      height = 3

      nrql_query {
        account_id = var.newrelic_account_id
        query      = "SELECT count(*) FROM Transaction WHERE appName IN (${local.lambda_filter}) AND aws.lambda.arn IS NOT NULL FACET appName TIMESERIES SINCE 6 hours ago"
      }
    }

    widget_line {
      title  = "Duração média e P95 das Lambdas (ms)"
      row    = 1
      column = 7
      width  = 6
      height = 3

      nrql_query {
        account_id = var.newrelic_account_id
        query      = "SELECT average(duration) * 1000 AS 'Média', percentile(duration, 95) * 1000 AS 'P95' FROM Transaction WHERE appName IN (${local.lambda_filter}) AND aws.lambda.arn IS NOT NULL TIMESERIES SINCE 6 hours ago"
      }
    }

    widget_line {
      title  = "Erros e cold starts"
      row    = 4
      column = 1
      width  = 6
      height = 3

      nrql_query {
        account_id = var.newrelic_account_id
        query      = "SELECT filter(count(*), WHERE aws.lambda.coldStart IS true) AS 'Cold starts', filter(count(*), WHERE error IS true) AS 'Erros' FROM Transaction WHERE appName IN (${local.lambda_filter}) AND aws.lambda.arn IS NOT NULL TIMESERIES SINCE 6 hours ago"
      }
    }

    widget_line {
      title  = "Latência do API Gateway (ms)"
      row    = 4
      column = 7
      width  = 6
      height = 3

      nrql_query {
        account_id = var.newrelic_account_id
        query      = "SELECT average(numeric(responseLatency)) AS 'Latência', percentile(numeric(responseLatency), 95) AS 'P95', average(numeric(integrationLatency)) AS 'Integração' FROM Log WHERE ${local.api_gateway_filter} TIMESERIES SINCE 6 hours ago"
      }
    }

    widget_billboard {
      title  = "Respostas do API Gateway"
      row    = 7
      column = 1
      width  = 6
      height = 3

      nrql_query {
        account_id = var.newrelic_account_id
        query      = "SELECT count(*) AS 'Requisições', filter(count(*), WHERE numeric(status) >= 400 AND numeric(status) < 500) AS '4xx', filter(count(*), WHERE numeric(status) >= 500) AS '5xx' FROM Log WHERE ${local.api_gateway_filter} SINCE 6 hours ago"
      }
    }

    widget_table {
      title  = "Erros por função Lambda"
      row    = 7
      column = 7
      width  = 6
      height = 3

      nrql_query {
        account_id = var.newrelic_account_id
        query      = "SELECT count(*) FROM TransactionError WHERE appName IN (${local.lambda_filter}) FACET appName, error.message SINCE 24 hours ago LIMIT 15"
      }
    }
  }

  page {
    name = "RDS PostgreSQL"

    widget_line {
      title  = "CPU do RDS (%)"
      row    = 1
      column = 1
      width  = 6
      height = 3

      nrql_query {
        account_id = var.newrelic_account_id
        query      = "SELECT average(cpuUtilizationPercent) FROM OficinaRdsSample WHERE ${local.rds_filter} TIMESERIES SINCE 6 hours ago"
      }
    }

    widget_line {
      title  = "Conexões do banco"
      row    = 1
      column = 7
      width  = 6
      height = 3

      nrql_query {
        account_id = var.newrelic_account_id
        query      = "SELECT average(databaseConnections) FROM OficinaRdsSample WHERE ${local.rds_filter} TIMESERIES SINCE 6 hours ago"
      }
    }

    widget_line {
      title  = "Armazenamento e memória livres (GiB)"
      row    = 4
      column = 1
      width  = 6
      height = 3

      nrql_query {
        account_id = var.newrelic_account_id
        query      = "SELECT average(freeStorageBytes) / 1073741824 AS 'Armazenamento', average(freeableMemoryBytes) / 1073741824 AS 'Memória' FROM OficinaRdsSample WHERE ${local.rds_filter} TIMESERIES SINCE 6 hours ago"
      }
    }

    widget_line {
      title  = "Latência de leitura e escrita (ms)"
      row    = 4
      column = 7
      width  = 6
      height = 3

      nrql_query {
        account_id = var.newrelic_account_id
        query      = "SELECT average(readLatencySeconds) * 1000 AS 'Leitura', average(writeLatencySeconds) * 1000 AS 'Escrita' FROM OficinaRdsSample WHERE ${local.rds_filter} TIMESERIES SINCE 6 hours ago"
      }
    }

    widget_line {
      title  = "IOPS de leitura e escrita"
      row    = 7
      column = 1
      width  = 6
      height = 3

      nrql_query {
        account_id = var.newrelic_account_id
        query      = "SELECT average(readIops) AS 'Leitura', average(writeIops) AS 'Escrita' FROM OficinaRdsSample WHERE ${local.rds_filter} TIMESERIES SINCE 6 hours ago"
      }
    }

    widget_billboard {
      title  = "Erros PostgreSQL agregados (24h)"
      row    = 7
      column = 7
      width  = 3
      height = 3

      nrql_query {
        account_id = var.newrelic_account_id
        query      = "SELECT sum(postgresErrorCount) FROM OficinaRdsSample WHERE ${local.rds_filter} SINCE 24 hours ago"
      }
    }

    widget_billboard {
      title  = "Consultas lentas agregadas (24h)"
      row    = 7
      column = 10
      width  = 3
      height = 3

      nrql_query {
        account_id = var.newrelic_account_id
        query      = "SELECT sum(slowQueryCount) FROM OficinaRdsSample WHERE ${local.rds_filter} SINCE 24 hours ago"
      }
    }
  }
}
