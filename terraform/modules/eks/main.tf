# terraform/modules/eks/main.tf

# --- IAM Role for EKS Cluster ---
resource "aws_iam_role" "cluster" {
  name = "${var.project_name}-eks-cluster-role-${var.cluster_name}-${var.environment}"

  assume_role_policy = jsonencode({
    Version   = "2012-10-17",
    Statement = [
      {
        Effect    = "Allow",
        Principal = {
          Service = "eks.amazonaws.com"
        },
        Action    = "sts:AssumeRole"
      }
    ]
  })

  tags = merge(var.tags, {
    Name = "${var.project_name}-eks-cluster-role-${var.cluster_name}-${var.environment}"
  })
}

resource "aws_iam_role_policy_attachment" "cluster_amazon_eks_cluster_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.cluster.name
}

# Optional: If your EKS cluster needs to manage VPC resources (e.g. for load balancers)
# This is often required for the AWS Load Balancer Controller.
resource "aws_iam_role_policy_attachment" "cluster_amazon_eks_vpc_resource_controller_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSVPCResourceController" # Corrected policy name
  role       = aws_iam_role.cluster.name
}


# --- IAM Role for EKS Node Group ---
# This role is for managed node groups. Karpenter (EKS-TASK-003) will have its own specific IAM setup.
resource "aws_iam_role" "node_group" {
  name = "${var.project_name}-eks-node-group-role-${var.cluster_name}-${var.environment}"

  assume_role_policy = jsonencode({
    Version   = "2012-10-17",
    Statement = [
      {
        Effect    = "Allow",
        Principal = {
          Service = "ec2.amazonaws.com"
        },
        Action    = "sts:AssumeRole"
      }
    ]
  })

  tags = merge(var.tags, {
    Name = "${var.project_name}-eks-node-group-role-${var.cluster_name}-${var.environment}"
  })
}

resource "aws_iam_role_policy_attachment" "node_group_amazon_eks_worker_node_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.node_group.name
}

resource "aws_iam_role_policy_attachment" "node_group_amazon_ec2_container_registry_read_only" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.node_group.name
}

resource "aws_iam_role_policy_attachment" "node_group_amazon_eks_cni_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.node_group.name
}

# Optional: If nodes need to publish metrics to CloudWatch
resource "aws_iam_role_policy_attachment" "node_group_cloudwatch_agent_server_policy" {
  count      = var.enable_node_group_cloudwatch_metrics ? 1 : 0
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
  role       = aws_iam_role.node_group.name
}

# Placeholder for variables that will be defined in terraform/modules/eks/variables.tf
# These are assumed to be present for this subtask.
# var.project_name
# var.cluster_name
# var.environment
# var.tags
# var.enable_node_group_cloudwatch_metrics (new variable to be added later)

# --- EKS Cluster Security Group ---
resource "aws_security_group" "cluster" {
  name        = "${var.project_name}-eks-cluster-sg-${var.cluster_name}-${var.environment}"
  description = "EKS cluster security group for ${var.cluster_name}"
  vpc_id      = var.vpc_id

  # Ingress rules are often minimal for the cluster SG itself if using node SGs effectively.
  # Nodes will need to communicate with the control plane.
  # This rule allows all traffic from within the SG itself (e.g. nodes to control plane ENIs if they share the SG)
  # More specific rules might be needed depending on network setup and kubectl access patterns.
  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1" # All protocols
    self        = true
    description = "Allow all traffic from within the same security group"
  }

  # If public access to API server is enabled, you might add a rule like:
  # ingress {
  #   from_port   = 443 # HTTPS for EKS API
  #   to_port     = 443
  #   protocol    = "tcp"
  #   cidr_blocks = var.public_access_cidrs
  #   description = "Allow EKS API access from specified CIDRs"
  # }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1" # Allow all outbound traffic
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-eks-cluster-sg-${var.cluster_name}-${var.environment}"
  })
}

# --- EKS Cluster ---
resource "aws_eks_cluster" "main" {
  name     = var.cluster_name
  role_arn = aws_iam_role.cluster.arn
  version  = var.cluster_version

  vpc_config {
    subnet_ids              = var.private_subnet_ids # Control plane ENIs typically in private subnets
    security_group_ids      = [aws_security_group.cluster.id] # Associate the SG created above
    endpoint_private_access = var.endpoint_private_access
    endpoint_public_access  = var.endpoint_public_access
    public_access_cidrs     = var.endpoint_public_access ? var.public_access_cidrs : []
  }

  enabled_cluster_log_types = var.enabled_cluster_log_types

  tags = merge(var.tags, {
    Name        = "${var.project_name}-eks-cluster-${var.cluster_name}-${var.environment}",
    Environment = var.environment,
    Project     = var.project_name
  })

  depends_on = [
    aws_iam_role_policy_attachment.cluster_amazon_eks_cluster_policy,
    aws_iam_role_policy_attachment.cluster_amazon_eks_vpc_resource_controller_policy,
  ]
}

# Output for OIDC provider URL - needed for IRSA
data "tls_certificate" "cluster_oidc" {
  url = aws_eks_cluster.main.identity[0].oidc[0].issuer
}

resource "aws_iam_openid_connect_provider" "cluster_oidc" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.cluster_oidc.certificates[0].sha1_fingerprint]
  url             = aws_eks_cluster.main.identity[0].oidc[0].issuer

  tags = merge(var.tags, {
    Name = "${var.project_name}-eks-oidc-provider-${var.cluster_name}-${var.environment}"
  })
}

# --- Initial EKS Managed Node Group ---
# This node group provides initial compute capacity. Karpenter (EKS-TASK-003) will handle more dynamic scaling.
resource "aws_eks_node_group" "initial" {
  count = var.enable_initial_node_group ? 1 : 0 # Controlled by variable

  cluster_name    = aws_eks_cluster.main.name
  node_group_name = var.node_group_name
  node_role_arn   = aws_iam_role.node_group.arn # Using the node_group role created earlier
  subnet_ids      = var.private_subnet_ids      # Nodes should be in private subnets

  ami_type       = var.node_group_ami_type
  capacity_type  = "ON_DEMAND" # Or SPOT, but ON_DEMAND is safer for initial critical nodes
  disk_size      = var.node_group_disk_size
  instance_types = var.node_group_instance_types

  remote_access {
    ec2_ssh_key = var.ec2_ssh_key_name # Can be null if no SSH access is desired/configured
    # Optionally, restrict source security groups for SSH access:
    # source_security_group_ids = [aws_security_group.ssh_access_sg.id] # Example
  }

  scaling_config {
    desired_size = var.node_group_desired_size
    max_size     = var.node_group_max_size
    min_size     = var.node_group_min_size
  }

  # Ensure the EKS cluster is fully provisioned before creating node group.
  # Especially important if using cluster security group for nodes or CNI dependencies.
  depends_on = [aws_eks_cluster.main]

  labels = merge(
    {
      "eks.amazonaws.com/nodegroup" = var.node_group_name,
      "environment"                 = var.environment,
      "project"                     = var.project_name
    },
    var.node_group_labels # User-defined labels
  )

  dynamic "taint" {
    for_each = var.node_group_taints
    content {
      key    = taint.value.key
      value  = taint.value.value
      effect = taint.value.effect
    }
  }

  tags = merge(var.tags, {
    Name                                                           = "${var.project_name}-eks-nodegroup-${var.node_group_name}-${var.environment}",
    "eks.amazonaws.com/nodegroup-name"                             = var.node_group_name,
    "k8s.io/cluster-autoscaler/${aws_eks_cluster.main.name}"       = "owned", # For cluster-autoscaler discovery if used
    "k8s.io/cluster-autoscaler/enabled"                            = "true"   # For cluster-autoscaler discovery if used
  })

  # Update policy for node group if needed, e.g. for specific CNI versions or features.
  # By default, uses the version of the EKS control plane.
  # version = var.cluster_version # This would pin the K8s version of the nodes

  # launch_template can be used for more advanced customization (e.g. custom AMIs, bootstrap scripts)
  # launch_template {
  #   name    = aws_launch_template.example.name
  #   version = aws_launch_template.example.latest_version
  # }
}
