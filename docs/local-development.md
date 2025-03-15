# Local Development Setup with Minikube

This guide provides step-by-step instructions for running n8n locally using Minikube and Kubernetes. This setup mirrors the production AWS EKS setup but runs entirely on your local machine, making it perfect for development and testing.

## Prerequisites

Before starting, ensure you have:

1. Docker Desktop installed and running
2. The following CLI tools installed:
   ```bash
   # For macOS users (using Homebrew)
   brew install minikube
   brew install kubectl
   ```

## Installation Steps

### 1. Start Minikube

Start a Minikube cluster with sufficient resources for n8n:

```bash
minikube start --memory=4096 --cpus=2
```

This creates a local Kubernetes cluster with:

- 4GB of RAM
- 2 CPU cores
- Docker as the container runtime

### 2. Deploy n8n Components

The deployment uses several Kubernetes manifests located in the `k8s/` directory:

1. Create the n8n namespace:

```bash
kubectl apply -f k8s/base/namespace.yaml
```

2. Create secrets (PostgreSQL and n8n):

```bash
kubectl apply -f k8s/secrets/
```

3. Create persistent volumes:

```bash
kubectl apply -f k8s/base/postgres-pvc.yaml
kubectl apply -f k8s/base/n8n-pvc.yaml
```

4. Deploy PostgreSQL and n8n:

```bash
kubectl apply -f k8s/base/postgres.yaml
kubectl apply -f k8s/base/n8n.yaml
```

### 3. Access n8n Locally

When using Minikube with Docker driver on macOS, there are two ways to access n8n:

#### Option 1: Minikube Service (Recommended)

```bash
minikube service n8n -n n8n
```

This command will:

- Create a tunnel to the service
- Open your default browser with the correct URL
- Keep the tunnel running while the terminal window is open

#### Option 2: Port Forwarding

```bash
kubectl port-forward svc/n8n 5678:5678 -n n8n
```

Then access n8n at: http://localhost:5678

Note: The service is configured as NodePort type with port 30678 for consistent access.

## Configuration Details

### Secret Configuration

The deployment uses two secrets:

1. PostgreSQL Secret (`k8s/secrets/postgres-secret.yaml`):

   - Database user
   - Database password
   - Database name

2. n8n Secret (`k8s/secrets/n8n-secret.yaml`):
   - n8n encryption key
   - Webhook URL
   - Database credentials

All secret values are base64 encoded. To encode a new value:

```bash
echo -n "your-value" | base64
```

### Storage Configuration

Both PostgreSQL and n8n use persistent volume claims with the following configurations:

- Storage Class: standard (Minikube's default)
- Access Mode: ReadWriteOnce
- Storage Size: 10Gi each

### Resource Limits

The n8n deployment is configured with the following resource limits:

- Memory Request: 250Mi
- Memory Limit: 500Mi
- CPU: Automatically managed by Kubernetes

## Maintenance

### Checking Status

Check the status of your pods:

```bash
kubectl get pods -n n8n
```

View logs for n8n:

```bash
kubectl logs -n n8n -l app=n8n
```

View logs for PostgreSQL:

```bash
kubectl logs -n n8n -l app=postgres
```

### Restarting Services

To restart n8n:

```bash
kubectl rollout restart deployment/n8n -n n8n
```

To restart PostgreSQL:

```bash
kubectl rollout restart deployment/postgres -n n8n
```

## Cleanup

To stop and clean up your local development environment:

1. Delete all Kubernetes resources:

```bash
kubectl delete -f k8s/base/
kubectl delete -f k8s/secrets/
```

2. Stop Minikube:

```bash
minikube stop
```

3. Optional: Delete the Minikube cluster entirely:

```bash
minikube delete
```

## Troubleshooting

### Common Issues

1. Connection Refused Errors:

   - Ensure all pods are running: `kubectl get pods -n n8n`
   - Check pod logs for errors: `kubectl logs -n n8n -l app=n8n`
   - Verify the service is exposed: `kubectl get svc -n n8n`

2. Persistent Volume Issues:

   - Check PVC status: `kubectl get pvc -n n8n`
   - Verify Minikube's storage provisioner is running: `kubectl get pods -n kube-system`

3. Database Connection Issues:
   - Verify PostgreSQL pod is running: `kubectl get pods -n n8n -l app=postgres`
   - Check PostgreSQL logs: `kubectl logs -n n8n -l app=postgres`
   - Verify secrets are correctly mounted: `kubectl describe pod -n n8n -l app=n8n`

### Getting Help

If you encounter issues:

1. Check the n8n logs for specific error messages
2. Verify all Kubernetes resources are healthy
3. Consult the n8n community forum or documentation
4. Check the [n8n GitHub repository](https://github.com/n8n-io/n8n) for known issues

## Next Steps

- Explore n8n's [workflow automation features](https://docs.n8n.io/workflows/)
- Learn about [custom nodes](https://docs.n8n.io/nodes/custom-nodes/)
- Set up [authentication](https://docs.n8n.io/hosting/authentication/)
- Configure [environment variables](https://docs.n8n.io/hosting/environment-variables/)
