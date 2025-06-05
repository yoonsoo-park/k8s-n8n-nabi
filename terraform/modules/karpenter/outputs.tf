output "karpenter_controller_role_arn" {
  description = "ARN of the IAM role for the Karpenter controller."
  value       = aws_iam_role.karpenter_controller.arn
}

output "karpenter_controller_role_name" {
  description = "Name of the IAM role for the Karpenter controller."
  value       = aws_iam_role.karpenter_controller.name
}

output "karpenter_node_instance_profile_arn" {
  description = "ARN of the IAM instance profile for nodes launched by Karpenter."
  value       = aws_iam_instance_profile.karpenter_node_profile.arn
}

output "karpenter_node_instance_profile_name" {
  description = "Name of the IAM instance profile for nodes launched by Karpenter."
  value       = aws_iam_instance_profile.karpenter_node_profile.name
}

output "karpenter_node_role_arn" {
  description = "ARN of the IAM role for nodes launched by Karpenter."
  value       = aws_iam_role.karpenter_node.arn
}
