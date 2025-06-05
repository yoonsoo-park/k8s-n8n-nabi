variable "project_name" {
  description = "Name of the project, used for tagging and naming resources."
  type        = string
}

variable "environment" {
  description = "Deployment environment (e.g., dev, staging, prod)."
  type        = string
}

variable "cluster_name" {
  description = "Name of the EKS cluster Karpenter will manage."
  type        = string
}

variable "aws_region" {
  description = "AWS region where resources are deployed."
  type        = string
}

variable "eks_oidc_provider_arn" {
  description = "ARN of the EKS OIDC Identity Provider."
  type        = string
}

variable "eks_oidc_provider_url_without_https" { # The OIDC URL without the 'https://' prefix
  description = "URL of the EKS OIDC Identity Provider, without the https:// prefix."
  type        = string
}

variable "karpenter_namespace" {
  description = "Kubernetes namespace where Karpenter is installed."
  type        = string
  default     = "karpenter"
}

variable "karpenter_service_account_name" {
  description = "Kubernetes service account name for Karpenter."
  type        = string
  default     = "karpenter"
}

variable "tags" {
  description = "A map of common tags to apply to all AWS resources."
  type        = map(string)
  default     = {}
}

# Optional: Variable for CloudWatch policy for Karpenter-provisioned nodes
variable "enable_karpenter_node_cloudwatch_metrics" {
  description = "Set to true to attach CloudWatchAgentServerPolicy to the Karpenter node IAM role."
  type        = bool
  default     = false
}

variable "karpenter_helm_chart_version" {
  description = "Version of the Karpenter Helm chart to install."
  type        = string
  default     = "v0.35.0" # Example: Check Karpenter docs for the latest compatible version with your K8s
                          # For EKS 1.28, v0.32.x+ is generally fine. v0.35.0 is a recent one as of late 2023.
}

variable "eks_cluster_endpoint" {
  description = "EKS cluster API server endpoint."
  type        = string
}

variable "enable_spot_interruption_handling" {
  description = "Enable Spot interruption handling features for Karpenter. Requires an SQS queue."
  type        = bool
  default     = false # Default to false to avoid needing SQS queue initially
}

variable "karpenter_sqs_queue_name" {
  description = "Name of the SQS queue for Spot interruption handling. Required if enable_spot_interruption_handling is true."
  type        = string
  default     = "" # User must provide if spot handling is enabled.
}

variable "default_provisioner_name" {
  description = "Name for the default Karpenter Provisioner."
  type        = string
  default     = "default"
}

variable "karpenter_api_version" {
  description = "API version for Karpenter CRDs (e.g., karpenter.sh/v1alpha5 or karpenter.k8s.aws/v1alpha1 for AWSNodeTemplate, karpenter.sh/v1beta1 for Provisioner)."
  type        = string
  default     = "karpenter.sh/v1alpha5" # Adjust based on Karpenter chart version and CRD support
}

variable "provisioner_capacity_types" {
  description = "List of capacity types for the Provisioner (e.g., ["spot", "on-demand"])"
  type        = list(string)
  default     = ["spot", "on-demand"] # Enable Spot by default, with on-demand fallback
}

variable "provisioner_limits_cpu" {
  description = "CPU resource limit for the Provisioner (e.g., "1000")."
  type        = string
  default     = "1000"
}

variable "provisioner_limits_memory" {
  description = "Memory resource limit for the Provisioner (e.g., "1000Gi")."
  type        = string
  default     = "1000Gi"
}

variable "provisioner_consolidation_enabled" {
  description = "Enable consolidation for the Provisioner."
  type        = bool
  default     = true
}

variable "provisioner_ttl_seconds_until_expired" {
  description = "Time-to-live in seconds for nodes launched by this provisioner. Null to disable. (e.g. 2592000 for 30 days)"
  type        = number
  default     = null # No expiry by default
}

variable "provisioner_custom_labels" {
  description = "Custom labels to apply to nodes launched by this provisioner."
  type        = map(string)
  default     = {}
}

# Variable to hold the EKS node security group ID if needed for providerRef/provider block.
# This would typically be an output from the EKS module or a shared SG.
# For now, we assume Karpenter discovers SGs via tags if not explicitly set.
# variable "node_security_group_id" {
#   description = "Security group ID for nodes launched by Karpenter. If not set, relies on subnet's default SG or Karpenter's discovery."
#   type        = string
#   default     = null
# }
