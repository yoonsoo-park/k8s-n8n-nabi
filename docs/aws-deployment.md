# Hosting n8n on AWS with EKS

This guide provides step-by-step instructions for deploying n8n on Amazon Web Services (AWS) using Elastic Kubernetes Service (EKS). This setup uses PostgreSQL as the database backend and includes all necessary configurations for a production environment.

## Prerequisites

Before starting, ensure you have:

1. An AWS account with appropriate permissions
2. The following tools installed on your local machine:
   - AWS CLI
   - kubectl
   - eksctl
   - git

## Installation Steps

### 1. Configure AWS CLI

First, configure your AWS CLI with your credentials:

```bash
aws configure
```

You'll need to provide:

- AWS Access Key ID
- AWS Secret Access Key
- Default region
- Default output format (json recommended)

### 2. Create EKS Cluster

Create a Kubernetes cluster using eksctl:

```bash
eksctl create cluster --name n8n --region your-aws-region --node-type t3.medium --nodes 2
```

This will create:

- A new EKS cluster named "n8n"
- 2 worker nodes of type t3.medium
- All necessary networking components (VPC, subnets, etc.)

### 3. Configure Kubernetes Resources

Clone the n8n Kubernetes configuration repository:

```bash
git clone https://github.com/n8n-io/n8n-kubernetes-hosting.git -b aws
cd n8n-kubernetes-hosting
```

### 4. Configure PostgreSQL

1. Create a secret for PostgreSQL credentials:

```yaml
# postgres-secret.yaml
apiVersion: v1
kind: Secret
metadata:
  name: postgres-secret
  namespace: n8n
type: Opaque
data:
  POSTGRES_USER: bjhuCg== # base64 encoded 'n8n'
  POSTGRES_PASSWORD: bjhuLXBhc3N3b3Jk # base64 encoded 'your-password'
  POSTGRES_DB: bjhu # base64 encoded 'n8n'
```

2. Configure persistent storage for PostgreSQL in `postgres-claim0-persistentvolumeclaim.yaml`

### 5. Configure n8n

1. Create n8n secrets:

```yaml
# n8n-secret.yaml
apiVersion: v1
kind: Secret
metadata:
  name: n8n-secret
  namespace: n8n
type: Opaque
data:
  N8N_ENCRYPTION_KEY: your-base64-encoded-key
  WEBHOOK_URL: your-base64-encoded-webhook-url
  DB_POSTGRESDB_USER: bjhuCg==
  DB_POSTGRESDB_PASSWORD: bjhuLXBhc3N3b3Jk
  DB_POSTGRESDB_DATABASE: bjhu
```

2. Configure persistent storage for n8n in `n8n-claim0-persistentvolumeclaim.yaml`

### 6. Deploy the Application

Apply all Kubernetes manifests:

```bash
kubectl apply -f namespace.yaml
kubectl apply -f .
```

### 7. Configure DNS and Access

1. Get the Load Balancer URL:

```bash
kubectl get svc -n n8n
```

2. Create a DNS record pointing to the Load Balancer URL
3. Access n8n at: http://your-domain:5678

## Resource Scaling

Default resource allocation:

- Memory Request: 250Mi
- Memory Limit: 500Mi
- CPU: Automatically managed by Kubernetes

Adjust these values in `n8n-deployment.yaml` based on your needs:

```yaml
resources:
  requests:
    memory: "250Mi"
  limits:
    memory: "500Mi"
```

## Maintenance

### Updating n8n

To update n8n to a new version:

1. Update the image tag in `n8n-deployment.yaml`
2. Apply the changes:

```bash
kubectl apply -f n8n-deployment.yaml
```

### Backup

1. PostgreSQL data is automatically persisted through AWS EBS volumes
2. Regular backups should be configured through AWS Backup

### Monitoring

Monitor your deployment using:

- AWS CloudWatch
- Kubernetes dashboard
- n8n's built-in monitoring tools

## Cleanup

To delete all resources:

```bash
kubectl delete -f .
eksctl delete cluster --name n8n --region your-aws-region
```

## Security Considerations

1. Enable AWS WAF for the Load Balancer
2. Configure Network Policies
3. Use AWS Secrets Manager for sensitive data
4. Regular security updates
5. Enable AWS CloudTrail for audit logging

## Troubleshooting

Common issues and solutions:

1. Database connection issues:
   - Verify PostgreSQL secrets are correct
   - Check network policies
2. Persistent volume issues:

   - Verify AWS EBS volume status
   - Check storage class availability

3. Load Balancer issues:
   - Verify security group settings
   - Check DNS configuration

For additional support, refer to:

- n8n documentation
- AWS EKS documentation
- Kubernetes documentation
