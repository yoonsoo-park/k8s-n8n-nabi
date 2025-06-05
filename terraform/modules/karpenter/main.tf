# terraform/modules/karpenter/main.tf
# (Add this at the top of the file, before the helm_release resource)

data "aws_eks_cluster" "cluster" {
  name = var.cluster_name # Assumes var.cluster_name is the EKS cluster name
}

data "aws_eks_cluster_auth" "cluster_auth" {
  name = var.cluster_name # Assumes var.cluster_name is the EKS cluster name
}

provider "kubernetes" {
  host                   = data.aws_eks_cluster.cluster.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.cluster_auth.token
}

# (iam.tf content with IAM roles and instance profile is in a separate file)

resource "helm_release" "karpenter" {
  namespace        = var.karpenter_namespace
  create_namespace = true # Ensure the namespace is created if it doesn't exist

  name       = "karpenter"
  repository = "oci://public.ecr.aws/karpenter" # Official Karpenter OCI repository
  chart      = "karpenter"
  version    = var.karpenter_helm_chart_version # e.g., "v0.32.1" - use a variable for version

  # Values to configure Karpenter Helm chart
  # Refer to Karpenter Helm chart documentation for all available options
  set {
    name  = "serviceAccount.create"
    value = "true" # Let the chart create the service account
  }
  set {
    name  = "serviceAccount.name"
    value = var.karpenter_service_account_name
  }
  set {
    name  = "serviceAccount.annotations.eks\.amazonaws\.com/role-arn"
    value = aws_iam_role.karpenter_controller.arn # From iam.tf
  }
  set {
    name  = "settings.aws.clusterName"
    value = var.cluster_name
  }
  set {
    name  = "settings.aws.clusterEndpoint"
    value = var.eks_cluster_endpoint # Passed in from EKS module output
  }
  set {
    name  = "settings.aws.defaultInstanceProfile"
    value = aws_iam_instance_profile.karpenter_node_profile.name # From iam.tf
  }
  set {
    name  = "settings.aws.interruptionQueueName" # For Spot interruption handling
    value = var.enable_spot_interruption_handling ? var.karpenter_sqs_queue_name : ""
  }
  set {
    name = "controller.resources.requests.cpu"
    value = "1"
  }
  set {
    name = "controller.resources.requests.memory"
    value = "1Gi"
  }
  set {
    name = "controller.resources.limits.cpu"
    value = "1"
  }
  set {
    name = "controller.resources.limits.memory"
    value = "1Gi"
  }

  # Wait for the resources to be ready before marking the release as successful
  wait = true
  # How long to wait for the release to be ready (default 5m0s)
  timeout = 600 # 10 minutes

  # If the EKS cluster's OIDC provider is used by Karpenter for IAM roles,
  # ensure Karpenter's SA is annotated correctly. This is handled by serviceAccount.annotations.
  depends_on = [
    aws_iam_role.karpenter_controller,
    aws_iam_instance_profile.karpenter_node_profile
  ]
}

# ... (helm_release.karpenter resource should be above this) ...

resource "kubernetes_manifest" "default_provisioner" {
  # Ensure Helm chart is applied and CRDs are available before creating Provisioner
  depends_on = [helm_release.karpenter]

  manifest = {
    "apiVersion" = var.karpenter_api_version # Or newer API version like v1beta1 if chart supports it
    "kind"       = "Provisioner"
    "metadata" = {
      "name"      = var.default_provisioner_name
      # "namespace" = var.karpenter_namespace # Provisioners are cluster-scoped, not namespaced
    }
    "spec" = {
      "requirements" = [
        { "key" = "karpenter.sh/capacity-type", "operator" = "In", "values" = var.provisioner_capacity_types },
        { "key" = "kubernetes.io/arch", "operator" = "In", "values" = ["amd64"] }, # Example: amd64
        # Add more requirements as needed, e.g., instance category, generation
        # { "key" = "karpenter.k8s.aws/instance-category", "operator" = "In", "values" = ["c", "m", "r"] },
        # { "key" = "karpenter.k8s.aws/instance-generation", "operator" = "Gt", "values" = ["2"] }
      ]
      "limits" = {
        "resources" = {
          "cpu"    = var.provisioner_limits_cpu    # e.g., "1000"
          "memory" = var.provisioner_limits_memory # e.g., "1000Gi"
        }
      }
      "providerRef" = { # For older Karpenter versions (<= v0.31.x or API v1alpha5)
        "name" = aws_iam_instance_profile.karpenter_node_profile.name
        # For newer versions (>= v0.32.x or API v1beta1), use 'provider' block:
        # "provider" = {
        #   "instanceProfile" = aws_iam_instance_profile.karpenter_node_profile.name # Reference the instance profile
        #   "subnetSelector" = {
        #     "karpenter.sh/discovery" = var.cluster_name
        #   }
        #   "securityGroupSelector" = {
        #     "karpenter.sh/discovery" = var.cluster_name
        #     # Or specific tags/IDs: "aws-ids" = var.node_security_group_id
        #   }
        # }
      }
      # For v1beta1 API (Karpenter >= v0.32.x), the provider block is structured differently:
      # "provider" = {
      #   "instanceProfile" = aws_iam_instance_profile.karpenter_node_profile.name
      #   "subnetSelectorTerms" = [
      #     { "tags" = { "karpenter.sh/discovery" = var.cluster_name } }
      #   ]
      #   "securityGroupSelectorTerms" = [
      #     { "tags" = { "karpenter.sh/discovery" = var.cluster_name } }
      #     # Or { "ids" = [var.node_security_group_id] }
      #   ]
      #   # "amiFamily" = "AL2", # Bottlerocket, Ubuntu, etc.
      #   # "tags" = { "CustomTag" = "KarpenterNode" } # Additional tags for nodes
      # }


      "consolidation" = {
        "enabled" = var.provisioner_consolidation_enabled
      }
      "ttlSecondsUntilExpired" = var.provisioner_ttl_seconds_until_expired # e.g., 2592000 for 30 days, or null to disable

      # "kubeletConfiguration" = { # Optional: customize kubelet
      #   "maxPods" = 110
      # }

      "labels" = merge(
        { "karpenter-provisioner" = var.default_provisioner_name },
        var.provisioner_custom_labels
      )

      # "taints" = [
      #   { "key"= "example.com/special-workload", "effect"= "NoSchedule" }
      # ]
    }
  }
}
