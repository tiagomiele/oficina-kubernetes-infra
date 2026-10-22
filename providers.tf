data "aws_caller_identity" "current" {}

data "aws_partition" "current" {}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "terraform"
      Repository  = "oficina-kubernetes-infra"
    }
  }
}
