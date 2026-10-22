output "dashboard_permalink" {
  description = "Link do dashboard criado no New Relic."
  value       = one(newrelic_one_dashboard.oficina[*].permalink)
}

output "alert_policy_id" {
  description = "Id da política de alertas."
  value       = local.policy_id
}

output "alert_condition_names" {
  description = "Condições de alerta gerenciadas por este workspace."
  value = sort(concat(
    [for key, condition in local.alert_conditions : key],
    ["telemetria_ausente"],
    local.synthetic_monitor_created ? ["monitor_sintetico"] : [],
  ))
}

output "synthetic_monitor_id" {
  description = "Id do monitor sintético de healthcheck, quando criado."
  value       = one(newrelic_synthetics_monitor.healthcheck[*].id)
}

output "monitored_entities" {
  description = "Entidades correlacionadas pelas consultas NRQL."
  value = {
    cluster     = local.cluster
    namespace   = var.kubernetes_namespace
    deployment  = var.kubernetes_deployment_name
    application = local.application
    api_gateway = local.api_gateway
    lambdas     = local.lambda_functions
  }
}
