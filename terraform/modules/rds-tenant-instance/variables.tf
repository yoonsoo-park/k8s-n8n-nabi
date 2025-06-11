variable "tenant_id" {
  description = "Unique identifier for the tenant (used for naming and tagging resources)."
  type        = string
}

variable "environment" {
  description = "Deployment environment (e.g., dev, staging, prod)."
  type        = string
}

variable "project_name" {
  description = "Name of the overall project for consistent tagging."
  type        = string
}

variable "vpc_id" {
  description = "ID of the VPC where the RDS instance will be deployed."
  type        = string
}

variable "private_subnet_ids" {
  description = "List of private subnet IDs for the DB subnet group. Must span at least two AZs for Multi-AZ."
  type        = list(string)
}

variable "allowed_source_security_group_ids" {
  description = "List of security group IDs allowed to connect to the RDS instance on the PostgreSQL port."
  type        = list(string)
}

variable "rds_instance_class" {
  description = "Instance class for the RDS instance (e.g., db.t3.small, db.m5.large)."
  type        = string
  default     = "db.t3.micro"
}

variable "rds_allocated_storage" {
  description = "Allocated storage in GiB for the RDS instance."
  type        = number
  default     = 20
}

variable "rds_storage_type" {
  description = "Storage type for the RDS instance (e.g., gp2, gp3, io1)."
  type        = string
  default     = "gp3"
}

variable "rds_iops" {
  description = "The amount of provisioned IOPS. Only applicable for 'io1' and 'gp3' storage types."
  type        = number
  default     = null # For gp3, if null, AWS provides baseline based on storage. Can be set to e.g. 3000.
}

variable "rds_engine_version" {
  description = "PostgreSQL engine version for the RDS instance."
  type        = string
  default     = "15.5" # Use a recent patch version
}

variable "rds_db_name" {
  description = "Initial database name to create in the RDS instance."
  type        = string
  default     = "n8ntenantdb"
}

variable "rds_master_username" {
  description = "Master username for the RDS instance."
  type        = string
  default     = "n8nadmin"
  validation {
    condition     = can(regex("^[a-zA-Z][a-zA-Z0-9_]*$", var.rds_master_username)) && length(var.rds_master_username) >= 1 && length(var.rds_master_username) <= 16 && !can(regex("^(pg_|PG_|Pg_)", var.rds_master_username))
    error_message = "Master username must begin with a letter, contain only alphanumeric characters and underscores, be 1-16 characters long, and not be a reserved prefix like 'pg_'."
  }
}

variable "rds_master_password_existing_secret_arn" {
  description = "ARN of an existing AWS Secrets Manager secret containing the master password. If provided, `rds_master_password_generate_new` should be false."
  type        = string
  default     = null
}

variable "rds_master_password_generate_new" {
  description = "If true, a new master password will be generated and stored in AWS Secrets Manager. `rds_master_password_existing_secret_arn` must be null."
  type        = bool
  default     = true
}

variable "rds_multi_az" {
  description = "Specifies if the RDS instance is multi-AZ. Recommended for production."
  type        = bool
  default     = false # Change to true for production environments
}

variable "rds_backup_retention_period" {
  description = "Backup retention period in days (0 to disable automated backups, 1-35)."
  type        = number
  default     = 7
  validation {
    condition     = var.rds_backup_retention_period >= 0 && var.rds_backup_retention_period <= 35
    error_message = "Backup retention period must be between 0 and 35 days."
  }
}

variable "rds_deletion_protection" {
  description = "If the DB instance should have deletion protection enabled. Recommended for production."
  type        = bool
  default     = false # Change to true for production environments
}

variable "rds_iam_database_authentication_enabled" {
  description = "Specifies whether IAM DB authentication is enabled."
  type        = bool
  default     = true
}

variable "rds_enabled_cloudwatch_logs_exports" {
  description = "List of log types to export to CloudWatch Logs (e.g., postgresql, upgrade)."
  type        = list(string)
  default     = ["postgresql", "upgrade"]
}

variable "tags" {
  description = "A map of tags to apply to all resources created by this module."
  type        = map(string)
  default     = {}
}
