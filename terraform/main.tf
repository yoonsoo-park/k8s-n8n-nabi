# terraform/main.tf

# --- Instantiate VPC Module ---
module "vpc" {
  source = "./modules/vpc" # Path to the VPC module

  project_name         = var.project_name
  environment          = var.environment
  aws_region           = var.aws_region # Although provider has it, module might use it for AZ construction logic

  vpc_cidr_block       = var.vpc_cidr_block
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
  availability_zones   = var.availability_zones

  enable_nat_gateway   = var.enable_nat_gateway
  single_nat_gateway   = var.single_nat_gateway

  tags                 = var.tags
}

# --- Instantiate EKS Module ---
module "eks" {
  source = "./modules/eks" # Path to the EKS module

  project_name    = var.project_name
  environment     = var.environment
  cluster_name    = "${var.project_name}-cluster-${var.environment}" # Construct cluster name
  cluster_version = "1.28" # Specify desired EKS version, can be a variable too

  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnet_ids
  aws_region         = var.aws_region

  # Logging and Endpoint Access (using defaults from EKS module variables for now, can be exposed here)
  # endpoint_private_access = true
  # endpoint_public_access  = false
  # public_access_cidrs     = ["YOUR_IP/32"] # Example if public access is true

  # Initial Managed Node Group configuration (using defaults from EKS module variables for now)
  enable_initial_node_group = true
  # node_group_instance_types = ["t3.medium"]
  # node_group_desired_size   = 2
  # ec2_ssh_key_name          = "your-ssh-key-name" # Optional: specify if SSH access to nodes is needed

  tags = var.tags

  depends_on = [module.vpc] # Ensure VPC is created before EKS
}

# --- Instantiate Karpenter Module ---
module "karpenter" {
  source = "./modules/karpenter"

  project_name    = var.project_name
  environment     = var.environment
  cluster_name    = module.eks.cluster_name # Output from EKS module
  aws_region      = var.aws_region

  eks_oidc_provider_arn             = module.eks.cluster_oidc_provider_arn # Output from EKS module
  eks_oidc_provider_url_without_https = replace(module.eks.cluster_oidc_issuer_url, "https://", "") # Derive from EKS module output
  eks_cluster_endpoint              = module.eks.cluster_endpoint # Output from EKS module

  # karpenter_namespace and karpenter_service_account_name use defaults in the module

  # Spot interruption handling - disabled by default
  # enable_spot_interruption_handling = true
  # karpenter_sqs_queue_name          = "your-karpenter-spot-queue-name" # Create this queue separately

  tags = var.tags

  depends_on = [module.eks] # Ensure EKS cluster is ready
}
