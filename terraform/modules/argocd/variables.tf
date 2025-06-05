variable "project_name" {
  description = "Name of the project, used for context in naming or tagging (though ArgoCD resources are mostly within its namespace)."
  type        = string
}

variable "environment" {
  description = "Deployment environment (e.g., dev, staging, prod)."
  type        = string
}

variable "cluster_name" {
  description = "Name of the EKS cluster where ArgoCD will be installed."
  type        = string
}

variable "aws_region" {
  description = "AWS region where the EKS cluster is deployed."
  type        = string
}

variable "argocd_namespace" {
  description = "Kubernetes namespace to install ArgoCD into."
  type        = string
  default     = "argocd"
}

variable "argocd_helm_chart_version" {
  description = "Version of the ArgoCD Helm chart to install (from argo-helm repository)."
  type        = string
  default     = "5.51.6" # Example: Corresponds to ArgoCD App v2.10.x or similar. Verify latest compatible.
                         # Check https://github.com/argoproj/argo-helm/releases for chart versions.
                         # Chart 5.51.6 uses ArgoCD 2.10.4. This is compatible with K8s 1.28.
}

variable "argocd_helm_repository" {
  description = "ArgoCD Helm chart repository URL."
  type        = string
  default     = "https://argoproj.github.io/argo-helm"
}

variable "argocd_server_service_type" {
  description = "Service type for the ArgoCD server (e.g., LoadBalancer, ClusterIP, NodePort)."
  type        = string
  default     = "LoadBalancer"
}

variable "tags" {
  description = "A map of common tags to apply to any AWS resources created by this module (e.g., LoadBalancer if service type is LoadBalancer)."
  type        = map(string)
  default     = {}
}

# Variable for HA - default to false for initial setup
variable "argocd_ha_enabled" {
  description = "Enable High Availability for ArgoCD components."
  type        = bool
  default     = false
}

variable "argocd_crds_install" {
  description = "Whether the Helm chart should install ArgoCD CRDs."
  type        = bool
  default     = true # Most charts manage their own CRDs
}

variable "argocd_server_ingress_enabled" {
  description = "Enable Ingress for ArgoCD server."
  type        = bool
  default     = false # Default to LoadBalancer service type, Ingress can be added later
}

variable "argocd_server_ingress_hosts" {
  description = "List of hosts for ArgoCD server Ingress."
  type        = list(string)
  default     = [] # e.g., ["argocd.example.com"]
}

variable "argocd_server_ingress_annotations" {
  description = "Annotations for ArgoCD server Ingress."
  type        = map(string)
  default     = {}
}

variable "argocd_server_ingress_tls" {
  description = "TLS configuration for ArgoCD server Ingress. List of objects with 'hosts' and 'secretName'."
  type        = list(any) # list(object({ hosts = list(string), secretName = string }))
  default     = []
}
