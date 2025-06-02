variable "aws_region" {
  description = "AWS region for the deployment."
  type        = string
  default     = "us-east-1" # Or any other sensible default
}

variable "project_name" {
  description = "Name of the project, used for tagging resources."
  type        = string
  default     = "n8n-eks"
}

variable "environment" {
  description = "Deployment environment (e.g., dev, staging, prod)."
  type        = string
  default     = "dev"
}

variable "vpc_cidr_block" {
  description = "CIDR block for the VPC."
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "List of CIDR blocks for public subnets."
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
}

variable "private_subnet_cidrs" {
  description = "List of CIDR blocks for private subnets."
  type        = list(string)
  default     = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]
}

variable "availability_zones" {
  description = "List of Availability Zones to use."
  type        = list(string)
  # Ensure these are valid for the chosen var.aws_region
  # For us-east-1
  default = ["us-east-1a", "us-east-1b", "us-east-1c"]
}

variable "enable_nat_gateway" {
  description = "Enable NAT gateway for private subnets. Set to false for no NAT gateway (e.g. if using VPC endpoints or no internet access needed)."
  type        = bool
  default     = true
}

variable "single_nat_gateway" {
  description = "Controls if a single NAT Gateway is used for all private subnets or one NAT Gateway per AZ."
  type        = bool
  default     = false # Default to one NAT GW per AZ for HA
}

variable "tags" {
  description = "A map of tags to add to all resources."
  type        = map(string)
  default     = {}
}
