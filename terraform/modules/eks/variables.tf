variable "project_name" {
  description = "Name of the project, used for tagging and naming resources."
  type        = string
}

variable "environment" {
  description = "Deployment environment (e.g., dev, staging, prod)."
  type        = string
}

variable "cluster_name" {
  description = "Name for the EKS cluster."
  type        = string
}

variable "cluster_version" {
  description = "Desired Kubernetes version for the EKS cluster."
  type        = string
  default     = "1.28" # Example: Use a recent, supported version
}

variable "vpc_id" {
  description = "ID of the VPC where the EKS cluster will be deployed."
  type        = string
}

variable "private_subnet_ids" {
  description = "List of private subnet IDs for EKS control plane ENIs and worker nodes."
  type        = list(string)
}

variable "aws_region" {
  description = "AWS region for deploying resources."
  type        = string
}

variable "enabled_cluster_log_types" {
  description = "A list of desired control plane log types to enable. Valid values: api, audit, authenticator, controllerManager, scheduler."
  type        = list(string)
  default     = ["api", "audit", "authenticator", "controllerManager", "scheduler"]
}

variable "endpoint_private_access" {
  description = "Indicates whether or not the EKS private API server endpoint is enabled."
  type        = bool
  default     = true
}

variable "endpoint_public_access" {
  description = "Indicates whether or not the EKS public API server endpoint is enabled."
  type        = bool
  default     = false # More secure default; can be overridden
}

variable "public_access_cidrs" {
  description = "List of CIDR blocks for public access to the EKS public API server endpoint."
  type        = list(string)
  default     = ["0.0.0.0/0"] # Restrict this if endpoint_public_access is true
}

variable "tags" {
  description = "A map of tags to add to all resources."
  type        = map(string)
  default     = {}
}

# Variable for the optional CloudWatch policy for node groups (from previous step)
variable "enable_node_group_cloudwatch_metrics" {
  description = "Set to true to attach CloudWatchAgentServerPolicy to the node group IAM role."
  type        = bool
  default     = false
}

# Variables for the initial managed node group (to be used in next plan step)
variable "enable_initial_node_group" {
  description = "Set to true to create an initial managed node group."
  type        = bool
  default     = true
}

variable "node_group_name" {
  description = "Name for the initial EKS managed node group."
  type        = string
  default     = "initial-nodes"
}

variable "node_group_instance_types" {
  description = "List of instance types for the EKS managed node group."
  type        = list(string)
  default     = ["t3.medium"]
}

variable "node_group_min_size" {
  description = "Minimum number of nodes in the managed node group."
  type        = number
  default     = 1
}

variable "node_group_max_size" {
  description = "Maximum number of nodes in the managed node group."
  type        = number
  default     = 3
}

variable "node_group_desired_size" {
  description = "Desired number of nodes in the managed node group."
  type        = number
  default     = 2
}

variable "node_group_ami_type" {
  description = "AMI type for the managed node group (e.g., AL2_x86_64, AL2_x86_64_GPU, BOTTLEROCKET_ARM_64)."
  type        = string
  default     = "AL2_x86_64"
}

variable "node_group_disk_size" {
  description = "Disk size in GiB for worker nodes."
  type        = number
  default     = 20
}

variable "ec2_ssh_key_name" {
  description = "Name of the EC2 SSH key to associate with worker nodes for SSH access (optional)."
  type        = string
  default     = null # No SSH key by default
}

variable "node_group_labels" {
  description = "A map of Kubernetes labels to apply to nodes in the node group."
  type        = map(string)
  default     = {}
}

variable "node_group_taints" {
  description = "A list of taints to apply to nodes in the node group. Each taint is a map with keys: key, value, effect."
  type = list(object({
    key    = string
    value  = string
    effect = string
  }))
  default = []
  # Example:
  # default = [
  #   {
  #     key    = "dedicated"
  #     value  = "gpuGroup"
  #     effect = "NO_SCHEDULE"
  #   }
  # ]
}
