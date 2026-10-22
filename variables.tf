variable "aws_region" {
  description = "Região AWS usada pelo Learner Lab."
  type        = string
  default     = "us-west-2"
}

variable "project_name" {
  description = "Prefixo dos recursos."
  type        = string
  default     = "oficina"

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{2,20}$", var.project_name))
    error_message = "project_name deve usar letras minúsculas, números ou hífen."
  }
}

variable "environment" {
  description = "Ambiente lógico associado à branch e ao workspace HCP Terraform."
  type        = string
  default     = "homolog"

  validation {
    condition     = contains(["homolog", "production"], var.environment)
    error_message = "environment deve ser homolog ou production."
  }
}

variable "vpc_cidr" {
  description = "CIDR da VPC."
  type        = string
  default     = "10.0.0.0/16"

  validation {
    condition     = can(cidrnetmask(var.vpc_cidr))
    error_message = "vpc_cidr deve ser um CIDR IPv4 válido."
  }
}

variable "availability_zones" {
  description = "Duas zonas de disponibilidade da região do Learner Lab."
  type        = list(string)
  default     = ["us-west-2a", "us-west-2b"]

  validation {
    condition     = length(var.availability_zones) == 2 && length(distinct(var.availability_zones)) == 2
    error_message = "Informe exatamente duas zonas de disponibilidade distintas."
  }
}

variable "public_subnet_cidrs" {
  description = "CIDRs das subnets públicas, na mesma ordem das zonas."
  type        = list(string)
  default     = ["10.0.0.0/24", "10.0.1.0/24"]

  validation {
    condition     = length(var.public_subnet_cidrs) == 2 && alltrue([for cidr in var.public_subnet_cidrs : can(cidrnetmask(cidr))])
    error_message = "Informe dois CIDRs IPv4 válidos para as subnets públicas."
  }
}

variable "private_subnet_cidrs" {
  description = "CIDRs das subnets privadas, na mesma ordem das zonas."
  type        = list(string)
  default     = ["10.0.10.0/24", "10.0.11.0/24"]

  validation {
    condition     = length(var.private_subnet_cidrs) == 2 && alltrue([for cidr in var.private_subnet_cidrs : can(cidrnetmask(cidr))])
    error_message = "Informe dois CIDRs IPv4 válidos para as subnets privadas."
  }
}

variable "cluster_version" {
  description = "Versão do Kubernetes disponível no AWS Academy."
  type        = string
  default     = "1.34"
}

variable "cluster_public_access_cidrs" {
  description = "CIDRs autorizados a acessar o endpoint público do Kubernetes. Restrinja para /32 quando possível."
  type        = list(string)
  default     = ["0.0.0.0/0"]

  validation {
    condition     = length(var.cluster_public_access_cidrs) >= 1 && alltrue([for cidr in var.cluster_public_access_cidrs : can(cidrnetmask(cidr))])
    error_message = "cluster_public_access_cidrs deve conter CIDRs IPv4 válidos."
  }
}

variable "node_instance_types" {
  description = "Tipos de instância permitidos no managed node group."
  type        = list(string)
  default     = ["t3.medium"]
}

variable "node_desired_size" {
  description = "Quantidade desejada de nodes."
  type        = number
  default     = 2
}

variable "node_min_size" {
  description = "Quantidade mínima de nodes."
  type        = number
  default     = 1
}

variable "node_max_size" {
  description = "Quantidade máxima de nodes."
  type        = number
  default     = 3
}

variable "node_disk_size" {
  description = "Disco de cada node em GiB."
  type        = number
  default     = 20
}

variable "cluster_log_retention_days" {
  description = "Retenção dos logs do control plane no CloudWatch."
  type        = number
  default     = 7
}
