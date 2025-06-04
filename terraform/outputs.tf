# terraform/outputs.tf

output "vpc_id" {
  description = "The ID of the created VPC."
  value       = module.vpc.vpc_id
}

output "private_subnet_ids" {
  description = "List of private subnet IDs in the VPC."
  value       = module.vpc.private_subnet_ids
}

output "public_subnet_ids" {
  description = "List of public subnet IDs in the VPC."
  value       = module.vpc.public_subnet_ids
}

output "eks_cluster_name" {
  description = "The name of the EKS cluster."
  value       = module.eks.cluster_name
}

output "eks_cluster_endpoint" {
  description = "The endpoint for the EKS Kubernetes API server."
  value       = module.eks.cluster_endpoint
}

output "eks_cluster_oidc_issuer_url" {
  description = "The OIDC Identity Provider Issuer URL for the EKS cluster."
  value       = module.eks.cluster_oidc_issuer_url
}

output "eks_cluster_oidc_provider_arn" {
  description = "The ARN of the IAM OIDC Identity Provider for the EKS cluster."
  value       = module.eks.cluster_oidc_provider_arn
}

output "eks_cluster_security_group_id" {
  description = "The ID of the EKS cluster's primary security group."
  value       = module.eks.cluster_security_group_id
}
