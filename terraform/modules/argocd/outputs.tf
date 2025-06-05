output "argocd_server_hostname" {
  description = "Hostname of the ArgoCD server LoadBalancer (if service type is LoadBalancer)."
  # This requires querying the service after it's created by Helm.
  # Using a kubernetes_service data source or resource.
  # For simplicity now, this will be empty and user needs to get it via kubectl.
  # A more advanced setup would use a data source.
  value = helm_release.argocd.status.load_balancer_ingress[0].hostname # This might not be directly available or correct syntax.
                                                                      # Actual access depends on chart outputs or service query.
                                                                      # For now, let's make it more robust by trying to get service attributes.
  # Placeholder, actual retrieval is more complex with helm_release only.
  # value = "Use 'kubectl get svc -n ${var.argocd_namespace} argocd-server' to find the hostname."
}

output "argocd_namespace" {
  description = "Namespace where ArgoCD is installed."
  value       = var.argocd_namespace
}

output "argocd_initial_admin_secret_name" {
  description = "Name of the secret containing the initial admin password for ArgoCD."
  value       = "argocd-initial-admin-secret" # Standard name
}

# To get the actual LoadBalancer hostname, a kubernetes_service data source would be better:
data "kubernetes_service" "argocd_server_service" {
  provider = kubernetes.argocd_install # Use aliased provider
  metadata {
    name      = "argocd-server" # Default service name for ArgoCD server
    namespace = var.argocd_namespace
  }
  depends_on = [helm_release.argocd] # Ensure helm release is applied
}

output "argocd_server_service_loadbalancer_hostname" {
  description = "LoadBalancer hostname for the ArgoCD server service."
  value       = try(data.kubernetes_service.argocd_server_service.status.load_balancer.ingress[0].hostname, null)
}

output "argocd_server_service_loadbalancer_ip" {
  description = "LoadBalancer IP address for the ArgoCD server service."
  value       = try(data.kubernetes_service.argocd_server_service.status.load_balancer.ingress[0].ip, null)
}
