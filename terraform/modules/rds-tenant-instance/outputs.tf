output "db_instance_arn" {
  description = "ARN of the RDS instance."
  value       = aws_db_instance.tenant_rds.arn
}

output "db_instance_id" {
  description = "Identifier of the RDS instance."
  value       = aws_db_instance.tenant_rds.id
}

output "db_instance_endpoint" {
  description = "Connection endpoint of the RDS instance."
  value       = aws_db_instance.tenant_rds.endpoint
}

output "db_instance_port" {
  description = "Connection port of the RDS instance."
  value       = aws_db_instance.tenant_rds.port
}

output "db_instance_name" {
  description = "The initial database name created in the RDS instance."
  value       = aws_db_instance.tenant_rds.db_name
}

output "db_master_username" {
  description = "The master username for the RDS instance."
  value       = aws_db_instance.tenant_rds.username
}

output "db_master_password_secret_arn" {
  description = "ARN of the AWS Secrets Manager secret holding the master password."
  value       = local.generate_new_password ? aws_secretsmanager_secret.db_password[0].arn : (local.use_existing_password_secret ? var.rds_master_password_existing_secret_arn : null)
}

output "db_security_group_id" {
  description = "ID of the security group created for the RDS instance."
  value       = aws_security_group.rds_sg.id
}

output "db_subnet_group_name" {
  description = "Name of the DB subnet group."
  value       = aws_db_subnet_group.tenant_rds.name
}
