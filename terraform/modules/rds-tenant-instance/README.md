# Per-Tenant RDS Instance Terraform Module

This Terraform module provisions a dedicated AWS RDS PostgreSQL instance intended for a single tenant.

## Features

- Creates an `aws_db_instance` (PostgreSQL).
- Creates an associated `aws_db_subnet_group`.
- Creates a dedicated `aws_security_group` for the RDS instance.
- Manages the RDS master password securely using AWS Secrets Manager.
- Supports IAM database authentication.
- Configurable instance class, storage, PostgreSQL version, backup settings, and more.

## Credential Management Strategy

This module handles the master user password for the RDS instance with the following strategy:

1.  **Password Generation (Default)**:
    *   If `var.rds_master_password_generate_new` is `true` (default) and `var.rds_master_password_existing_secret_arn` is `null`, the module:
        *   Generates a cryptographically strong random password using the `random_password` resource.
        *   Creates a new AWS Secrets Manager secret (e.g., `rds-<tenant_id>-<environment>-master-password`).
        *   Stores the generated password in this new secret.
    *   The ARN of this newly created secret is available in the `db_master_password_secret_arn` output.

2.  **Using an Existing Secret**:
    *   If `var.rds_master_password_existing_secret_arn` is provided, the module will fetch the master password from this specified AWS Secrets Manager secret.
    *   In this case, `var.rds_master_password_generate_new` should ideally be set to `false` (though the module logic prioritizes the existing secret).
    *   The `db_master_password_secret_arn` output will reflect the provided existing secret ARN.
    *   **Important**: If using an existing secret, the secret's value is assumed to be the plain password string. If the secret stores a JSON object, the Terraform code in `main.tf` that references `data.aws_secretsmanager_secret_version.existing_db_password[0].secret_string` might need adjustment or you'll need to ensure your consuming application (like n8n via ESO) can parse the JSON. The current setup assumes a plain string for existing secrets passed to the `aws_db_instance` `password` argument.

### Integration with Application Deployments (e.g., n8n Helm Chart via ArgoCD)

To securely provide the database credentials to tenant applications (like an n8n instance):

1.  **Retrieve Secret ARN**: After Terraform applies and provisions the RDS instance, obtain the `db_master_password_secret_arn` output value for the specific tenant's database module.

2.  **Use External Secrets Operator (ESO)**:
    *   Deploy an `ExternalSecret` Kubernetes custom resource in the tenant's namespace.
    *   This `ExternalSecret` should:
        *   Reference the `db_master_password_secret_arn`.
        *   Specify an appropriate IAM Role for ESO to assume, which has `secretsmanager:GetSecretValue` permission for this specific secret. (This IAM Role for ESO needs to be configured separately).
        *   Define a `target.name` for the Kubernetes `Secret` that ESO will create/synchronize (e.g., `tenant-a-db-credentials`).
        *   Define `target.template.data` or use default data mapping to specify the key in the Kubernetes `Secret` where the password will be stored (e.g., `POSTGRES_PASSWORD: "{{ .password }}"`).

3.  **Configure Application Helm Chart**:
    *   In the Helm values for the tenant's n8n application (e.g., via ArgoCD Application parameters or a Kustomize overlay):
        *   Set `n8n.config.dbHost` to the RDS instance endpoint (from `db_instance_endpoint` output).
        *   Set `n8n.config.dbUser` to the master username (from `db_master_username` output).
        *   Set `n8n.config.dbPasswordSecretName` to the name of the Kubernetes `Secret` created by ESO (e.g., `tenant-a-db-credentials`).
        *   Set `n8n.config.dbPasswordSecretKey` to the key within that Kubernetes secret (e.g., `POSTGRES_PASSWORD`).
        *   Ensure the bundled PostgreSQL in the n8n chart is disabled (`postgresql.enabled: false`).

This approach ensures that database master passwords are not hardcoded in Terraform configurations or application deployment manifests, leveraging AWS Secrets Manager for secure storage and External Secrets Operator for secure injection into Kubernetes.

## Example Instantiation (Root `main.tf`)

To provision an RDS instance for a specific tenant (e.g., "tenant-alpha") using this module, you would add a block like the following to your main Terraform configuration (e.g., `terraform/main.tf`):

```terraform
# Ensure you have outputs from your VPC and EKS modules available.
# Example: module.vpc.vpc_id, module.vpc.private_subnet_ids, module.eks.cluster_security_group_id

module "rds_tenant_alpha" {
  source = "./modules/rds-tenant-instance" # Path to this module

  tenant_id            = "alpha"
  environment          = var.environment # Assuming a root 'environment' variable (e.g., "dev", "prod")
  project_name         = var.project_name # Assuming a root 'project_name' variable

  vpc_id               = module.vpc.vpc_id
  private_subnet_ids   = module.vpc.private_subnet_ids

  # Use the EKS cluster's primary security group as an allowed source.
  # For production, you might use a more specific security group for your n8n application pods.
  allowed_source_security_group_ids = [module.eks.cluster_security_group_id]

  # RDS specific configurations
  rds_instance_class     = "db.t3.small"
  rds_allocated_storage  = 20
  rds_db_name            = "n8ntenantalpha"
  rds_master_username    = "n8nalphaadmin"
  # By default, generates a new password and stores it in AWS Secrets Manager:
  rds_master_password_generate_new = true
  # To use an existing password from Secrets Manager instead:
  # rds_master_password_generate_new = false
  # rds_master_password_existing_secret_arn = "arn:aws:secretsmanager:REGION:ACCOUNT_ID:secret:your/secret/name-XXXXXX"

  # Environment-specific settings
  rds_multi_az           = var.environment == "prod" ? true : false
  rds_backup_retention_period = var.environment == "prod" ? 14 : 7
  rds_deletion_protection = var.environment == "prod" ? true : false

  tags = merge(var.tags, { # Assuming a root 'tags' variable
    Tenant = "tenant-alpha"
  })

  depends_on = [module.eks] # Ensure EKS cluster (and its SGs) are ready
}

# Outputs from this tenant's DB module can then be used:
# module.rds_tenant_alpha.db_instance_endpoint
# module.rds_tenant_alpha.db_master_password_secret_arn
```
This example demonstrates how to call the module and pass necessary variables, including outputs from VPC and EKS modules. The actual values for instance class, storage, etc., should be adjusted based on the specific tenant's requirements.

## Backup and Restore

*   **Automated Backups**: This module enables automated daily backups by AWS RDS. The retention period for these backups is configurable via the `var.rds_backup_retention_period` variable (defaulting to 7 days). Set to 0 to disable automated backups (not recommended for production).
*   **Final Snapshot**: If `var.rds_deletion_protection` is enabled (recommended for production), a final snapshot of the database will be taken upon deletion of the RDS instance. If deletion protection is disabled, the final snapshot is skipped by default (controlled by `skip_final_snapshot` argument which is set based on `var.rds_deletion_protection`).
*   **Restore Procedures**: Restoring an RDS instance (either Point-in-Time Recovery or from a snapshot) is performed using standard AWS RDS procedures via the AWS Management Console, CLI, or SDK. A restore operation always creates a new RDS instance. Terraform can also be used to provision a new instance from a specified snapshot using the `snapshot_identifier` argument in the `aws_db_instance` resource, which is useful for disaster recovery scenarios.

## Variables

(Refer to `variables.tf` for a full list of input variables.)

## Outputs

(Refer to `outputs.tf` for a full list of outputs.)
