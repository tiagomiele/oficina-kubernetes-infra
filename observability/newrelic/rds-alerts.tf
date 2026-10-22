resource "newrelic_nrql_alert_condition" "rds_telemetria_ausente" {
  count = local.count_enabled

  account_id                   = var.newrelic_account_id
  policy_id                    = local.policy_id
  type                         = "static"
  name                         = "${local.name} — telemetria RDS ausente"
  description                  = "A coleta agendada do RDS parou de publicar eventos no New Relic."
  enabled                      = true
  aggregation_method           = "event_flow"
  aggregation_window           = 300
  aggregation_delay            = local.thresholds.condition_evaluation_delay_s
  violation_time_limit_seconds = local.thresholds.violation_time_limit_seconds

  expiration_duration            = local.thresholds.telemetry_expiration_seconds
  open_violation_on_expiration   = true
  close_violations_on_expiration = true

  nrql {
    query = "SELECT count(*) FROM OficinaRdsSample WHERE ${local.rds_filter}"
  }

  critical {
    operator              = "below"
    threshold             = 1
    threshold_duration    = 300
    threshold_occurrences = "all"
  }
}
