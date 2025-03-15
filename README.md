# n8n-nabi: n8n with MCP Integration on AWS EKS

This project provides a complete solution for hosting n8n with Model Context Protocol (MCP) integration on Amazon Web Services (AWS) using Elastic Kubernetes Service (EKS). The setup includes n8n, an MCP server, PostgreSQL, and all necessary configurations for a production environment.

## Architecture Overview

The architecture consists of:

1. **n8n**: Workflow automation platform with AI capabilities
2. **MCP Server**: Provides standardized tools for AI agents
3. **PostgreSQL**: Database backend for n8n
4. **AWS EKS**: Kubernetes orchestration for managing the containers

## Prerequisites

Before starting, ensure you have the following:

1. AWS Account with administrative access
2. The following tools installed on your local machine:
   - [AWS CLI](https://aws.amazon.com/cli/)
   - [eksctl](https://eksctl.io/)
   - [kubectl](https://kubernetes.io/docs/tasks/tools/)
   - [git](https://git-scm.com/)
   - [Docker](https://www.docker.com/) (for building MCP server image)

## Quick Start

### 1. Configure AWS CLI

```bash
aws configure
```

Enter your AWS credentials:

- AWS Access Key ID
- AWS Secret Access Key
- Default region
- Default output format (json)

### 2. Create EKS Cluster

```bash
eksctl create cluster --name n8n-mcp --region your-aws-region
```

### 3. Build and Push MCP Server Docker Image

```bash
cd mcp-server
docker build -t your-registry/mcp-server:latest .
docker push your-registry/mcp-server:latest
```

Update the image name in `k8s/base/mcp-server.yaml` to match your registry URL.

### 4. Deploy to Kubernetes

Apply configurations in this order:

```bash
kubectl apply -f k8s/base/namespace.yaml
kubectl apply -f k8s/secrets/
kubectl apply -f k8s/base/postgres-pvc.yaml
kubectl apply -f k8s/base/n8n-pvc.yaml
kubectl apply -f k8s/base/postgres.yaml
kubectl apply -f k8s/base/mcp-server.yaml
kubectl apply -f k8s/base/n8n.yaml
```

### 5. Access n8n

Get the Load Balancer URL:

```bash
kubectl get svc -n n8n
```

Create a DNS record pointing to the Load Balancer URL.

## MCP Integration

This project includes the Model Context Protocol (MCP) server that provides standardized tools for AI agents in n8n. The integration works as follows:

1. MCP server runs as a separate container providing tool endpoints
2. n8n connects to the MCP server using the n8n-nodes-mcp community node
3. AI Agent node in n8n can use tools provided by the MCP server

### Available MCP Tools

The MCP server includes the following tools:

- HTTP Request Tool: Make HTTP requests to external APIs
- Add more tools by creating additional JavaScript files in `mcp-server/tools/`

## Local Development

For local testing using Minikube, see the [local development guide](docs/local-development.md).

## AWS Deployment Options

The recommended deployment is EKS, but other options include:

- EC2 with Docker
- ECS with Fargate
- Hybrid approach with managed services (ECS/Fargate + RDS + ElastiCache)

For more details, see the [AWS deployment guide](docs/aws-deployment.md).

## Maintenance and Operations

### Monitoring

Monitor your deployment with:

- AWS CloudWatch
- Kubernetes Dashboard
- n8n execution logs

### Scaling

Scale n8n horizontally by increasing replicas:

```bash
kubectl scale deployment n8n --replicas=3 -n n8n
```

### Cleanup

To delete all resources:

```bash
kubectl delete -f k8s/base/
kubectl delete -f k8s/secrets/
eksctl delete cluster --name n8n-mcp --region your-aws-region
```

## Security Considerations

1. Enable HTTPS using AWS Certificate Manager
2. Configure network policies to restrict communication
3. Use AWS IAM roles for service accounts
4. Store secrets in AWS Secrets Manager or HashiCorp Vault

## Troubleshooting

For common issues and solutions, see the [troubleshooting guide](docs/troubleshooting.md).

## References

- [n8n Documentation](https://docs.n8n.io/)
- [Model Context Protocol](https://modelcontextprotocol.io/)
- [AWS EKS Documentation](https://docs.aws.amazon.com/eks/)
