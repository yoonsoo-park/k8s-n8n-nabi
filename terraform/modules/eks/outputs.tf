output "cluster_name" {
  description = "The name of the EKS cluster."
  value       = aws_eks_cluster.main.name
}

output "cluster_arn" {
  description = "The Amazon Resource Name (ARN) of the EKS cluster."
  value       = aws_eks_cluster.main.arn
}

output "cluster_endpoint" {
  description = "The endpoint for your EKS Kubernetes API server."
  value       = aws_eks_cluster.main.endpoint
}

output "cluster_version" {
  description = "The Kubernetes version of the EKS cluster."
  value       = aws_eks_cluster.main.version
}

output "cluster_oidc_issuer_url" {
  description = "The OIDC Identity Provider Issuer URL for the EKS cluster."
  value       = aws_eks_cluster.main.identity[0].oidc[0].issuer
}

output "cluster_oidc_provider_arn" {
  description = "The ARN of the IAM OIDC Identity Provider for the EKS cluster."
  value       = aws_iam_openid_connect_provider.cluster_oidc.arn
}

output "cluster_security_group_id" {
  description = "The ID of the EKS cluster's primary security group."
  value       = aws_security_group.cluster.id
}

output "cluster_iam_role_arn" {
  description = "The ARN of the IAM role created for the EKS cluster."
  value       = aws_iam_role.cluster.arn
}

output "node_group_iam_role_arn" {
  description = "The ARN of the IAM role created for the EKS managed node group."
  value       = aws_iam_role.node_group.arn # Assumes aws_iam_role.node_group is defined
}
