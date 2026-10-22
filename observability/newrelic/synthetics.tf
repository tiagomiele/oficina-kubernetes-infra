# Monitor sintético do healthcheck público.
#
# Enquanto a URL do LoadBalancer não existir, synthetic_monitor_enabled
# permanece false e nenhum recurso é criado.

resource "newrelic_synthetics_monitor" "healthcheck" {
  count = local.count_enabled == 1 && local.synthetic_monitor_created ? 1 : 0

  account_id       = var.newrelic_account_id
  name             = local.synthetic_monitor_name
  type             = "SIMPLE"
  status           = "ENABLED"
  period           = var.synthetic_monitor_period
  uri              = var.health_check_url
  locations_public = var.synthetic_monitor_locations

  treat_redirect_as_failure = false
  verify_ssl                = startswith(var.health_check_url, "https://")

  tag {
    key    = "environment"
    values = [var.environment]
  }

  tag {
    key    = "cluster"
    values = [local.cluster]
  }
}

# Condição de alerta associada ao monitor sintético, criada junto com ele.
resource "newrelic_nrql_alert_condition" "synthetic_healthcheck" {
  count = local.count_enabled == 1 && local.synthetic_monitor_created ? 1 : 0

  account_id                   = var.newrelic_account_id
  policy_id                    = local.policy_id
  type                         = "static"
  name                         = "${local.name} — monitor sintético falhando"
  description                  = "O monitor sintético do healthcheck retornou falha."
  enabled                      = true
  aggregation_method           = "event_flow"
  aggregation_window           = 60
  aggregation_delay            = local.thresholds.condition_evaluation_delay_s
  violation_time_limit_seconds = local.thresholds.violation_time_limit_seconds

  nrql {
    query = "SELECT filter(count(*), WHERE result != 'SUCCESS') FROM SyntheticCheck WHERE monitorId = '${one(newrelic_synthetics_monitor.healthcheck[*].id)}'"
  }

  critical {
    operator              = "above_or_equals"
    threshold             = local.thresholds.synthetic_failures
    threshold_duration    = 300
    threshold_occurrences = "all"
  }
}
