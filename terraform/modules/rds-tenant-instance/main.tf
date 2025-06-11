locals {
  db_identifier_prefix = substr("${var.project_name}-${var.tenant_id}-${var.environment}-rds", 0, 50) # Max 63 chars for identifier, keep some room
  db_identifier        = lower(replace(local.db_identifier_prefix, "_", "-")) # Ensure lowercase and hyphens

  # Determine if we are using an existing secret or generating a new one
  use_existing_password_secret = var.rds_master_password_existing_secret_arn != null
  generate_new_password        = var.rds_master_password_generate_new && !local.use_existing_password_secret

  # Common tags merged with module-specific ones
  common_tags = merge(
    var.tags,
    {
      "Name"        = local.db_identifier
      "TenantID"    = var.tenant_id
      "Environment" = var.environment
      "Project"     = var.project_name
      "Module"      = "rds-tenant-instance"
    }
  )
}

resource "random_password" "master_password" {
  count = local.generate_new_password ? 1 : 0

  length           = 16
  special          = true
  override_special = "_%@" # Only use specific special characters if needed, or remove for broader set
  min_upper        = 1
  min_lower        = 1
  min_numeric      = 1
  min_special      = 1
}

resource "aws_secretsmanager_secret" "db_password" {
  count = local.generate_new_password ? 1 : 0

  name        = "${local.db_identifier}-master-password"
  description = "Master password for RDS instance ${local.db_identifier}"
  tags        = local.common_tags
}

resource "aws_secretsmanager_secret_version" "db_password_version" {
  count = local.generate_new_password ? 1 : 0

  secret_id     = aws_secretsmanager_secret.db_password[0].id
  secret_string = random_password.master_password[0].result
}

data "aws_secretsmanager_secret_version" "existing_db_password" {
  count = local.use_existing_password_secret ? 1 : 0

  secret_id = var.rds_master_password_existing_secret_arn
}

resource "aws_db_subnet_group" "tenant_rds" {
  name       = "${local.db_identifier}-sng"
  subnet_ids = var.private_subnet_ids
  tags       = local.common_tags
}

resource "aws_security_group" "rds_sg" {
  name        = "${local.db_identifier}-sg"
  description = "Security group for RDS instance ${local.db_identifier}"
  vpc_id      = var.vpc_id
  tags        = local.common_tags

  ingress {
    description       = "Allow PostgreSQL access from specified SGs"
    from_port         = 5432
    to_port           = 5432
    protocol          = "tcp"
    security_groups   = var.allowed_source_security_group_ids
  }

  egress { # Typically, RDS might not need broad egress, but default allows all.
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_db_instance" "tenant_rds" {
  identifier             = local.db_identifier
  engine                 = "postgres"
  engine_version         = var.rds_engine_version
  instance_class         = var.rds_instance_class
  allocated_storage      = var.rds_allocated_storage
  storage_type           = var.rds_storage_type
  iops                   = var.rds_storage_type == "io1" || var.rds_storage_type == "gp3" ? var.rds_iops : null

  db_name                = var.rds_db_name
  username               = var.rds_master_username
  password               = local.generate_new_password ? random_password.master_password[0].result : (local.use_existing_password_secret ? data.aws_secretsmanager_secret_version.existing_db_password[0].secret_string : null)
  # The password logic assumes if using existing secret, the secret value *is* the password string directly.
  # If the existing secret stores a JSON object (e.g. {"username": "user", "password": "pw"}),
  # then it should be: jsondecode(data.aws_secretsmanager_secret_version.existing_db_password[0].secret_string).password
  # or jsondecode(data.aws_secretsmanager_secret_version.existing_db_password[0].secret_string)[var.rds_master_username]
  # For now, assuming the existing secret's value IS the password.

  db_subnet_group_name   = aws_db_subnet_group.tenant_rds.name
  vpc_security_group_ids = [aws_security_group.rds_sg.id]

  multi_az               = var.rds_multi_az
  backup_retention_period= var.rds_backup_retention_period
  skip_final_snapshot    = var.rds_deletion_protection ? false : true # Skip if deletion protection is off
  deletion_protection    = var.rds_deletion_protection
  publicly_accessible    = false # Should always be false for private DBs

  iam_database_authentication_enabled = var.rds_iam_database_authentication_enabled
  enabled_cloudwatch_logs_exports     = var.rds_enabled_cloudwatch_logs_exports

  apply_immediately      = false # Set to true if changes should apply immediately (can cause downtime)
  port                   = 5432  # Default PostgreSQL port

  tags = local.common_tags

  # Ensure Secrets Manager secret is created before RDS tries to use password from it (if generated)
  depends_on = [
    aws_secretsmanager_secret_version.db_password_version,
  ]

  lifecycle {
    # Prevent accidental replacement if sensitive fields like db_name or username are changed without a plan.
    # prevent_destroy = true # Consider enabling for production critical databases
    ignore_changes = [
      # If password is managed in Secrets Manager and rotated, Terraform shouldn't try to resync it.
      # This is important if using an existing secret that might be updated externally.
      # Or if we generate it once and then manage rotations outside TF.
      password,
    ]
  }
}
