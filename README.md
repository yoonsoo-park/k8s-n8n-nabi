# n8n-automation: n8n Workflow Platform on AWS EKS

This project provides a complete solution for hosting n8n workflow automation platform on Amazon Web Services (AWS) using Elastic Kubernetes Service (EKS). The setup includes n8n, PostgreSQL, Redis, and all necessary configurations for a production environment.

## Architecture Overview

The architecture consists of:

1. **n8n**: Workflow automation platform with AI capabilities
2. **PostgreSQL**: Database backend for n8n
3. **Redis**: Queue management for n8n workers
4. **AWS EKS**: Kubernetes orchestration for managing the containers

## Prerequisites

Before starting, ensure you have the following:

1. AWS Account with administrative access
2. The following tools installed on your local machine:
   - [AWS CLI](https://aws.amazon.com/cli/)
   - [eksctl](https://eksctl.io/)
   - [kubectl](https://kubernetes.io/docs/tasks/tools/)
   - [git](https://git-scm.com/)
   - [Docker](https://www.docker.com/) (for container management)

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
eksctl create cluster --name n8n-automation --region your-aws-region
```

### 3. Deploy to Kubernetes

Apply configurations in this order:

```bash
kubectl apply -f k8s/base/namespace.yaml
kubectl apply -f k8s/secrets/
kubectl apply -f k8s/base/postgres-pvc.yaml
kubectl apply -f k8s/base/n8n-pvc.yaml
kubectl apply -f k8s/base/postgres.yaml
kubectl apply -f k8s/base/n8n.yaml
```

### 4. Access n8n

Get the Load Balancer URL:

```bash
kubectl get svc -n n8n
```

Create a DNS record pointing to the Load Balancer URL.

## Workflow Automation

This project provides a robust n8n workflow automation platform with the following capabilities:

1. **Visual Workflow Builder**: Create complex automation workflows using n8n's intuitive interface
2. **Database Integration**: Persistent storage of workflows and execution history via PostgreSQL
3. **Queue Management**: Redis-powered queue system for handling concurrent workflow executions
4. **Worker Scaling**: Multiple n8n worker instances for improved performance

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
eksctl delete cluster --name n8n-automation --region your-aws-region
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

# n8n MCP Server

This repository contains an implementation of a Model Context Protocol (MCP) server that integrates with n8n. The MCP server allows AI systems (like Claude) to discover and use n8n workflows as "tools".

## What is MCP?

Model Context Protocol (MCP) is an open standard that lets AI systems (LLMs) discover and use external tools and data via a unified interface. An MCP server exposes a set of "tools" (functions or actions) that an AI can invoke.

## What is n8n?

n8n is a popular open-source workflow automation tool. By integrating it with MCP, an AI agent can trigger n8n workflows or manage them using natural language.

## Local Development Setup

### Prerequisites

- Docker and Docker Compose installed
- Node.js 18+ (for running the test script outside Docker)

### Running the MCP Server with n8n

1. Clone this repository:

   ```bash
   git clone https://github.com/yourusername/n8n-nabi.git
   cd n8n-nabi
   ```

2. Start the containers using Docker Compose:

   ```bash
   docker-compose up --scale n8n-worker=2
   ```

   This will start:

   - n8n on http://localhost:5678
   - MCP server on http://localhost:1991

3. Wait for both services to start up (usually takes about 30 seconds)

4. Access n8n at http://localhost:5678 and create a simple workflow to test with.

### Testing the MCP Server

There are two ways to test the MCP server:

#### Option 1: Using the test script

Install dependencies for the test script:

```bash
npm install axios
```

Run the test script:

```bash
node test-mcp-server.js
```

The script will attempt to list all workflows from n8n via the MCP server and display the results.

#### Option 2: Using curl

You can also test the MCP server directly using curl:

```bash
curl -X POST http://localhost:1991/mcp \
  -H "Content-Type: application/json" \
  -d '{
    "jsonrpc": "2.0",
    "id": "1",
    "method": "tool",
    "params": {
      "name": "n8n_list_workflows",
      "parameters": {}
    }
  }'
```

## Available MCP Tools

The MCP server currently provides the following tools:

### n8n_list_workflows

Lists all workflows available in n8n.

Parameters:

- `active` (optional, boolean): Filter workflows by active status

Example:

```json
{
  "jsonrpc": "2.0",
  "id": "1",
  "method": "tool",
  "params": {
    "name": "n8n_list_workflows",
    "parameters": {
      "active": true
    }
  }
}
```

### http_request

Makes HTTP requests to external APIs. This tool is useful for testing general HTTP connectivity.

Parameters:

- `method` (required, string): The HTTP method to use (GET, POST, PUT, DELETE)
- `url` (required, string): The URL to send the request to
- `headers` (optional, object): HTTP headers to include in the request
- `data` (optional, object): Data to send in the request body (for POST/PUT)

## Shutting Down

To stop the containers:

```bash
docker-compose down
```

To stop and remove all data:

```bash
docker-compose down -v
```
