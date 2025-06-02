variable "project_name" {
  description = "Name of the project, used for tagging resources."
  type        = string
}

variable "environment" {
  description = "Deployment environment (e.g., dev, staging, prod)."
  type        = string
}

variable "vpc_cidr_block" {
  description = "CIDR block for the VPC."
  type        = string
}

variable "public_subnet_cidrs" {
  description = "List of CIDR blocks for public subnets. Must match the number of AZs."
  type        = list(string)
  validation {
    condition     = length(var.public_subnet_cidrs) == length(var.availability_zones)
    error_message = "The number of public_subnet_cidrs must match the number of availability_zones."
  }
}

variable "private_subnet_cidrs" {
  description = "List of CIDR blocks for private subnets. Must match the number of AZs."
  type        = list(string)
  validation {
    condition     = length(var.private_subnet_cidrs) == length(var.availability_zones)
    error_message = "The number of private_subnet_cidrs must match the number of availability_zones."
  }
}

variable "availability_zones" {
  description = "List of Availability Zones to use for subnets."
  type        = list(string)
}

variable "enable_nat_gateway" {
  description = "Enable NAT gateway for private subnets."
  type        = bool
  default     = true
}

variable "single_nat_gateway" {
  description = "Set to true to use a single NAT Gateway for all private subnets (less HA, lower cost). If false, one NAT Gateway per AZ will be created."
  type        = bool
  default     = false
}

variable "tags" {
  description = "A map of tags to add to all resources."
  type        = map(string)
  default     = {}
}
