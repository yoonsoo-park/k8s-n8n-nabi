# --- Provider Configuration for Kubernetes & Helm ---
data "aws_eks_cluster" "cluster" {
  name = var.cluster_name
}

data "aws_eks_cluster_auth" "cluster_auth" {
  name = var.cluster_name
}

provider "kubernetes" {
  alias                  = "argocd_install" # Alias to avoid conflict if root also has kubernetes provider
  host                   = data.aws_eks_cluster.cluster.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.cluster_auth.token
}

provider "helm" {
  alias = "argocd_install" # Alias for Helm provider
  kubernetes {
    host                   = data.aws_eks_cluster.cluster.endpoint
    cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority[0].data)
    token                  = data.aws_eks_cluster_auth.cluster_auth.token
  }
}

# --- ArgoCD Helm Release ---
resource "helm_release" "argocd" {
  provider = helm.argocd_install # Explicitly use aliased provider

  name       = "argocd"
  repository = var.argocd_helm_repository
  chart      = "argo-cd" # The chart name in the argo-helm repository
  version    = var.argocd_helm_chart_version
  namespace  = var.argocd_namespace

  create_namespace = true

  # Values to customize the ArgoCD installation
  # Refer to the official argo-helm/argo-cd chart values for all options:
  # https://github.com/argoproj/argo-helm/blob/main/charts/argo-cd/values.yaml
  values = [
    # YAML formatted values string or path to values file
    # For simplicity, setting key values directly.
    # A separate values.yaml file is recommended for complex configurations.
    <<YAML
server:
  service:
    type: ${var.argocd_server_service_type}
  # Ingress configuration (optional, enable with var.argocd_server_ingress_enabled)
  ingress:
    enabled: ${var.argocd_server_ingress_enabled}
    hosts: ${jsonencode(var.argocd_server_ingress_hosts)}
    annotations: ${jsonencode(var.argocd_server_ingress_annotations)}
    tls: ${jsonencode(var.argocd_server_ingress_tls)}

# CRD installation handled by the chart
crds:
  install: ${var.argocd_crds_install}
  keep: false # Set to true if you want to prevent CRDs from being uninstalled when the chart is deleted

# High Availability settings
controller:
  replicas: ${var.argocd_ha_enabled ? 2 : 1} # Example for controller
server:
  replicas: ${var.argocd_ha_enabled ? 2 : 1} # Example for server
repoServer:
  replicas: ${var.argocd_ha_enabled ? 2 : 1} # Example for repo server
redis: # ArgoCD chart includes a Redis subchart
  ha:
    enabled: ${var.argocd_ha_enabled}
    # Further Redis HA config might be needed if argocd_ha_enabled is true

# Dex, if used (often enabled by default in chart for SSO)
dex:
  enabled: true # Keep Dex enabled for now, can be configured/disabled later
  # replicas: ${var.argocd_ha_enabled ? 2 : 1} # Example if HA for Dex is needed

# ApplicationSet controller (often bundled)
applicationSet:
  enabled: true
  # replicas: ${var.argocd_ha_enabled ? 2 : 1} # Example if HA for AppSet is needed

# Notifications controller (often bundled)
notifications:
  enabled: true
  # replicas: ${var.argocd_ha_enabled ? 2 : 1} # Example if HA for Notifications is needed

# If AWS LoadBalancer service type, you might want to add annotations for AWS Load Balancer Controller
# server.service.annotations:
#   service.beta.kubernetes.io/aws-load-balancer-type: "nlb" # or "alb"
#   service.beta.kubernetes.io/aws-load-balancer-internal: "false" # for public
#   # ... other ALB/NLB annotations ...

# Default admin password will be in 'argocd-initial-admin-secret'
# For production, consider managing this secret externally or using SSO.
configs:
  secret:
    # create an extra secret object with the argocd-initial-admin-secret name that can be managed by TF
    # This is an alternative to fetching it via kubectl.
    # However, the chart itself creates this secret. Managing it declaratively here can conflict.
    # Best practice is to retrieve it post-install and change it, or use SSO.
    # For now, we rely on the chart's default behavior.
    # initialAdminPassword: "your-secure-password" # Avoid hardcoding, use a variable or random provider if setting here.
    # initialAdminPasswordMtime: "..." # Needed if password is set
    argocdInitialAdminPasswordMtime: null # Ensure this is null or not set if not managing password here
YAML
  ]

  # Wait for resources to be ready
  wait    = true
  timeout = 900 # 15 minutes, ArgoCD can take a while with all components

  # Ensure EKS cluster is ready, and CRDs (if managed separately) are applied.
  # If CRDs are installed by this chart (crds.install=true), this dependency is implicit.
  depends_on = [
    # Potentially, other cluster add-ons like an ingress controller if configuring ingress here.
  ]
}
