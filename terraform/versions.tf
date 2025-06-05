# terraform/versions.tf (ensure this content is merged with existing, e.g. AWS provider)
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    helm = { # Add this block
      source  = "hashicorp/helm"
      version = "~> 2.10" # Use a recent version
    }
    kubernetes = { # Add this block, might be needed for Provisioner CRDs later
      source  = "hashicorp/kubernetes"
      version = "~> 2.20" # Use a recent version
    }
    tls = { # Add this block, was used by EKS module for OIDC thumbprint
      source = "hashicorp/tls"
      version = "~> 4.0"
    }
  }
  required_version = ">= 1.3"
}
