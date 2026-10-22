output "vpc_id" {
  description = "ID da VPC compartilhada."
  value       = aws_vpc.main.id
}

output "public_subnet_ids" {
  description = "IDs das subnets públicas ordenadas por zona."
  value       = [for subnet in values(aws_subnet.public) : subnet.id]
}

output "private_subnet_ids" {
  description = "IDs das subnets privadas ordenadas por zona."
  value       = [for subnet in values(aws_subnet.private) : subnet.id]
}

output "eks_cluster_name" {
  description = "Nome do cluster EKS."
  value       = aws_eks_cluster.main.name
}

output "eks_cluster_endpoint" {
  description = "Endpoint da API Kubernetes."
  value       = aws_eks_cluster.main.endpoint
}

output "eks_cluster_security_group_id" {
  description = "Security group gerenciado pelo EKS, autorizado no RDS."
  value       = aws_eks_cluster.main.vpc_config[0].cluster_security_group_id
}

output "kubectl_config_command" {
  description = "Comando para configurar o kubectl."
  value       = "aws eks update-kubeconfig --region ${var.aws_region} --name ${aws_eks_cluster.main.name}"
}
