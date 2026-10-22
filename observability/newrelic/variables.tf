variable "newrelic_account_id" {
  description = "Account id do New Relic. Fornecido pelo workspace HCP Terraform; 0 mantém a configuração válida estaticamente."
  type        = number
  default     = 0
}

variable "newrelic_api_key" {
  description = "User API key do New Relic (NRAK). Nunca versionada."
  type        = string
  sensitive   = true
  default     = ""
}

variable "newrelic_region" {
  description = "Região da conta New Relic."
  type        = string
  default     = "US"

  validation {
    condition     = contains(["US", "EU"], var.newrelic_region)
    error_message = "newrelic_region deve ser US ou EU."
  }
}

variable "observability_enabled" {
  description = "Cria dashboards, políticas e condições. Use false para validar a configuração sem conta New Relic disponível."
  type        = bool
  default     = true
}

variable "project_name" {
  description = "Prefixo dos recursos, alinhado ao repositório de infraestrutura."
  type        = string
  default     = "oficina"

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{2,20}$", var.project_name))
    error_message = "project_name deve usar letras minúsculas, números ou hífen."
  }
}

variable "environment" {
  description = "Ambiente lógico associado ao workspace e ao GitHub Environment."
  type        = string
  default     = "homolog"

  validation {
    condition     = contains(["homolog", "production"], var.environment)
    error_message = "environment deve ser homolog ou production."
  }
}

variable "cluster_name" {
  description = "Nome do cluster EKS monitorado. Vazio usa <project_name>-<environment>."
  type        = string
  default     = ""
}

variable "apm_application_name" {
  description = "Nome da aplicação no APM. Vazio usa <project_name>-backend-<environment>."
  type        = string
  default     = ""
}

variable "kubernetes_namespace" {
  description = "Namespace da aplicação no cluster."
  type        = string
  default     = "oficina"
}

variable "kubernetes_deployment_name" {
  description = "Deployment da aplicação monitorado pelas condições de Kubernetes."
  type        = string
  default     = "oficina-app"
}

variable "lambda_function_names" {
  description = "Funções Lambda de autenticação monitoradas. Vazio usa <project_name>-<environment>-login e -authorizer."
  type        = list(string)
  default     = []
}

variable "api_gateway_name" {
  description = "Nome da HTTP API do API Gateway. Vazio usa <project_name>-<environment>-http-api."
  type        = string
  default     = ""
}

variable "rds_database_identifier" {
  description = "Identificador da instância RDS. Vazio usa <project_name>-<environment>-db."
  type        = string
  default     = ""
}

variable "health_check_url" {
  description = "URL pública do healthcheck exposta pelo LoadBalancer. Enquanto vazia, o monitor sintético não é criado."
  type        = string
  default     = ""

  validation {
    condition     = var.health_check_url == "" || can(regex("^https?://", var.health_check_url))
    error_message = "health_check_url deve começar com http:// ou https://."
  }
}

variable "synthetic_monitor_enabled" {
  description = "Cria o monitor sintético de healthcheck. Requer health_check_url preenchida."
  type        = bool
  default     = false
}

variable "synthetic_monitor_period" {
  description = "Frequência do monitor sintético."
  type        = string
  default     = "EVERY_5_MINUTES"
}

variable "synthetic_monitor_locations" {
  description = "Localidades públicas usadas pelo monitor sintético."
  type        = list(string)
  default     = ["AWS_US_WEST_2", "AWS_US_EAST_1"]
}

variable "alert_thresholds" {
  description = "Limiares por ambiente. Cada chave deve corresponder a um ambiente suportado."
  type = map(object({
    error_rate_percent           = number
    latency_p95_ms               = number
    os_processing_failures       = number
    integration_failures         = number
    container_cpu_percent        = number
    container_memory_percent     = number
    container_restarts           = number
    lambda_errors                = number
    api_gateway_5xx_errors       = number
    api_gateway_latency_ms       = number
    rds_cpu_percent              = number
    rds_connections              = number
    rds_free_storage_gib         = number
    rds_postgres_errors          = number
    synthetic_failures           = number
    telemetry_expiration_seconds = number
    condition_duration_seconds   = number
    condition_evaluation_delay_s = number
    violation_time_limit_seconds = number
  }))

  default = {
    homolog = {
      error_rate_percent           = 10
      latency_p95_ms               = 2000
      os_processing_failures       = 3
      integration_failures         = 3
      container_cpu_percent        = 85
      container_memory_percent     = 85
      container_restarts           = 3
      lambda_errors                = 3
      api_gateway_5xx_errors       = 3
      api_gateway_latency_ms       = 2000
      rds_cpu_percent              = 85
      rds_connections              = 70
      rds_free_storage_gib         = 3
      rds_postgres_errors          = 3
      synthetic_failures           = 1
      telemetry_expiration_seconds = 1200
      condition_duration_seconds   = 300
      condition_evaluation_delay_s = 120
      violation_time_limit_seconds = 86400
    }
    production = {
      error_rate_percent           = 5
      latency_p95_ms               = 1200
      os_processing_failures       = 1
      integration_failures         = 2
      container_cpu_percent        = 80
      container_memory_percent     = 80
      container_restarts           = 2
      lambda_errors                = 2
      api_gateway_5xx_errors       = 2
      api_gateway_latency_ms       = 1200
      rds_cpu_percent              = 80
      rds_connections              = 60
      rds_free_storage_gib         = 5
      rds_postgres_errors          = 1
      synthetic_failures           = 1
      telemetry_expiration_seconds = 900
      condition_duration_seconds   = 180
      condition_evaluation_delay_s = 120
      violation_time_limit_seconds = 86400
    }
  }

  validation {
    condition     = alltrue([for environment in keys(var.alert_thresholds) : contains(["homolog", "production"], environment)])
    error_message = "alert_thresholds só aceita as chaves homolog e production."
  }
}

variable "alert_incident_preference" {
  description = "Agrupamento de incidentes da política de alertas."
  type        = string
  default     = "PER_CONDITION_AND_TARGET"

  validation {
    condition     = contains(["PER_POLICY", "PER_CONDITION", "PER_CONDITION_AND_TARGET"], var.alert_incident_preference)
    error_message = "alert_incident_preference deve ser PER_POLICY, PER_CONDITION ou PER_CONDITION_AND_TARGET."
  }
}

variable "notification_enabled" {
  description = "Cria destino, canal e workflow de notificação. Opcional: sem ele os incidentes continuam visíveis no New Relic."
  type        = bool
  default     = false
}

variable "notification_email" {
  description = "E-mail que recebe as notificações quando notification_enabled é true."
  type        = string
  default     = ""

  validation {
    condition     = var.notification_email == "" || can(regex("^[^@[:space:]]+@[^@[:space:]]+\\.[a-z]{2,}$", var.notification_email))
    error_message = "notification_email deve ser um endereço de e-mail válido."
  }
}
