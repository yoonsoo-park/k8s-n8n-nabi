# Troubleshooting Guide

This guide provides solutions for common issues you might encounter when deploying and running n8n with MCP integration on AWS EKS.

## n8n Issues

### Pod Not Starting

If the n8n pod is not starting, check the logs:

```bash
kubectl logs -f deployment/n8n -n n8n
```

Common issues and solutions:

1. **Database Connection Issues**:

   - Verify PostgreSQL is running: `kubectl get pods -n n8n -l app=postgres`
   - Check PostgreSQL logs: `kubectl logs -f deployment/postgres -n n8n`
   - Verify connection details in secrets: `kubectl describe secret n8n-secret -n n8n`

2. **Resource Limitations**:

   - Check if pod is pending due to insufficient resources: `kubectl describe pod -n n8n -l app=n8n`
   - If resources are limited, increase requests/limits in n8n deployment YAML

3. **n8n-nodes-mcp Installation Failure**:
   - Check if the post-start lifecycle hook is failing during community node installation
   - Verify the node installation manually:
     ```bash
     kubectl exec -it $(kubectl get pod -l app=n8n -n n8n -o jsonpath='{.items[0].metadata.name}') -n n8n -- npm list n8n-nodes-mcp
     ```

### n8n Cannot Connect to MCP Server

If n8n is running but cannot connect to the MCP server:

1. Verify MCP server is running:

   ```bash
   kubectl get pods -n n8n -l app=mcp-server
   kubectl logs -f deployment/mcp-server -n n8n
   ```

2. Check network connectivity:

   ```bash
   kubectl exec -it $(kubectl get pod -l app=n8n -n n8n -o jsonpath='{.items[0].metadata.name}') -n n8n -- curl -v http://mcp-server:1991
   ```

3. Verify environment variables in n8n:
   ```bash
   kubectl exec -it $(kubectl get pod -l app=n8n -n n8n -o jsonpath='{.items[0].metadata.name}') -n n8n -- env | grep MCP
   ```

## MCP Server Issues

### MCP Server Pod Not Starting

If the MCP server pod is not starting:

1. Check the logs:

   ```bash
   kubectl logs -f deployment/mcp-server -n n8n
   ```

2. Verify image is accessible:

   ```bash
   kubectl describe pod -n n8n -l app=mcp-server
   ```

   Look for image pull errors.

3. If using a private registry, verify the image pull secrets are properly configured.

### MCP Tools Not Available

If MCP tools are not appearing in n8n:

1. Verify tools are correctly defined in the MCP server:

   ```bash
   kubectl exec -it $(kubectl get pod -l app=mcp-server -n n8n -o jsonpath='{.items[0].metadata.name}') -n n8n -- ls -la /app/tools
   ```

2. Check the MCP server logs for tool initialization errors:

   ```bash
   kubectl logs -f deployment/mcp-server -n n8n
   ```

3. Test the MCP server directly:
   ```bash
   kubectl port-forward svc/mcp-server 1991:1991 -n n8n
   ```
   Then in another terminal:
   ```bash
   curl -X POST http://localhost:1991/jsonrpc -H "Content-Type: application/json" -d '{"jsonrpc":"2.0","id":1,"method":"toolList","params":{}}'
   ```

## AWS and Kubernetes Issues

### EKS Cluster Issues

1. **Node Group Problems**:

   - Check node status: `kubectl get nodes`
   - Verify node group configuration in AWS Console

2. **Persistent Volume Claims Not Binding**:

   - Check PVC status: `kubectl get pvc -n n8n`
   - Verify storage class exists: `kubectl get storageclass`
   - Check for volume provisioning errors in events: `kubectl get events -n n8n`

3. **Load Balancer Issues**:
   - Check service status: `kubectl get svc -n n8n`
   - Verify AWS load balancer creation: `aws elb describe-load-balancers` or check in AWS Console
   - Ensure proper IAM permissions for EKS service account

## Networking Issues

### DNS Resolution Problems

If services cannot communicate by name:

1. Check CoreDNS is running:

   ```bash
   kubectl get pods -n kube-system -l k8s-app=kube-dns
   ```

2. Test DNS resolution:

   ```bash
   kubectl run -it --rm --restart=Never dns-test --image=busybox -- nslookup mcp-server.n8n.svc.cluster.local
   ```

3. Verify service exists:
   ```bash
   kubectl get svc mcp-server -n n8n
   ```

### Load Balancer Not Accessible

If you cannot access n8n via the load balancer:

1. Check security groups in AWS Console
2. Verify target group health in AWS Console
3. Check service configuration:
   ```bash
   kubectl describe svc n8n -n n8n
   ```

## Data Persistence Issues

If you're losing data between restarts:

1. Verify persistent volumes are correctly mounted:

   ```bash
   kubectl describe pods -n n8n -l app=n8n
   ```

2. Check persistent volume claim status:

   ```bash
   kubectl get pvc -n n8n
   ```

3. For PostgreSQL data issues, check PostgreSQL logs for database corruption or configuration issues:
   ```bash
   kubectl logs -f deployment/postgres -n n8n
   ```

## Getting More Help

If you're still experiencing issues:

1. Check the n8n community forums: https://community.n8n.io/
2. Review AWS EKS documentation: https://docs.aws.amazon.com/eks/
3. Consult the Model Context Protocol documentation: https://modelcontextprotocol.io/
4. Create a detailed issue in the project repository with logs and configuration details
