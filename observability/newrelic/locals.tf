locals {
  name                    = "${var.project_name}-${var.environment}"
  count_enabled           = var.observability_enabled ? 1 : 0
  cluster                 = var.cluster_name != "" ? var.cluster_name : local.name
  application             = var.apm_application_name != "" ? var.apm_application_name : "${var.project_name}-backend-${var.environment}"
  api_gateway             = var.api_gateway_name != "" ? var.api_gateway_name : "${local.name}-http-api"
  rds_database_identifier = var.rds_database_identifier != "" ? var.rds_database_identifier : "${local.name}-db"

  lambda_functions = length(var.lambda_function_names) > 0 ? var.lambda_function_names : [
    "${local.name}-login",
    "${local.name}-authorizer",
  ]

  lambda_filter = join(", ", [for function_name in local.lambda_functions : "'${function_name}'"])

  thresholds = var.alert_thresholds[var.environment]

  synthetic_monitor_name    = "${local.name}-healthcheck"
  synthetic_monitor_created = var.synthetic_monitor_enabled && var.health_check_url != ""

  # Filtros reutilizados pelas consultas NRQL de dashboards e alertas.
  apm_filter         = "appName = '${local.application}'"
  business_filter    = "environment = '${var.environment}'"
  cluster_filter     = "clusterName = '${local.cluster}'"
  workload_filter    = "clusterName = '${local.cluster}' AND namespaceName = '${var.kubernetes_namespace}'"
  deployment_where   = "${local.workload_filter} AND deploymentName = '${var.kubernetes_deployment_name}'"
  api_gateway_filter = "logtype = 'api-gateway-access' AND environment = '${var.environment}'"
  rds_filter         = "environment = '${var.environment}' AND databaseIdentifier = '${local.rds_database_identifier}'"
}
