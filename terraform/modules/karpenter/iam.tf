# --- IAM Role and Policy for Karpenter Controller ---
resource "aws_iam_role" "karpenter_controller" {
  name = "${var.project_name}-karpenter-controller-${var.cluster_name}-${var.environment}"
  tags = merge(var.tags, {
    Name = "${var.project_name}-karpenter-controller-${var.cluster_name}-${var.environment}"
  })

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Federated = var.eks_oidc_provider_arn
        },
        Action = "sts:AssumeRoleWithWebIdentity",
        Condition = {
          StringEquals = {
            # Condition to ensure only the Karpenter service account in the specified namespace can assume this role
            "${var.eks_oidc_provider_url_without_https}:sub" = "system:serviceaccount:${var.karpenter_namespace}:${var.karpenter_service_account_name}",
            "${var.eks_oidc_provider_url_without_https}:aud" = "sts.amazonaws.com"
          }
        }
      }
    ]
  })
}

resource "aws_iam_policy" "karpenter_controller_policy" {
  name        = "${var.project_name}-karpenter-controller-policy-${var.cluster_name}-${var.environment}"
  description = "IAM policy for the Karpenter controller for cluster ${var.cluster_name}"
  tags = merge(var.tags, {
    Name = "${var.project_name}-karpenter-controller-policy-${var.cluster_name}-${var.environment}"
  })

  # Based on Karpenter documentation for required permissions
  # This policy can be further restricted based on observed CloudTrail events after initial setup.
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect   = "Allow",
        Action = [
          "ec2:CreateFleet",
          "ec2:CreateLaunchTemplate",
          "ec2:CreateTags",
          "ec2:DeleteLaunchTemplate",
          "ec2:DescribeAvailabilityZones",
          "ec2:DescribeInstanceTypeOfferings",
          "ec2:DescribeInstanceTypes",
          "ec2:DescribeInstances",
          "ec2:DescribeLaunchTemplates",
          "ec2:DescribeSecurityGroups",
          "ec2:DescribeSpotPriceHistory",
          "ec2:DescribeSpotInstanceRequests", // Added for better Spot visibility
          "ec2:DescribeSubnets",
          "ec2:RunInstances",
          "ec2:TerminateInstances",
          "ec2:DeleteTags", # Added to allow Karpenter to remove its tags
          "eks:DescribeCluster",
          "iam:PassRole",
          "iam:CreateInstanceProfile", # If Karpenter needs to create one
          "iam:TagInstanceProfile",    # If Karpenter needs to create one
          "iam:AddRoleToInstanceProfile", # If Karpenter needs to create one
          "iam:RemoveRoleFromInstanceProfile", # If Karpenter needs to create one
          "iam:DeleteInstanceProfile", # If Karpenter needs to create one
          "iam:GetInstanceProfile", # To check existence
          "ssm:GetParameter", # For AMI discovery via SSM
          "pricing:GetProducts" # For pricing information
        ],
        Resource = "*" # Some actions require "*" - this can be refined
      },
      # Allow tagging only for resources created by Karpenter, if possible using conditions
      # This is a simplified version; more complex conditions can be added.
      {
         Effect = "Allow",
         Action = "ec2:TagResources", # Specific tagging action
         Resource = "*", # Can be restricted further if needed
         Condition = {
            "ForAllValues:StringEquals" = {
                "aws:TagKeys" = [
                    "karpenter.sh/provisioner-name",
                    "Name"
                    # Add other tags Karpenter is expected to manage
                ]
            },
            "StringEquals" = {
                "ec2:CreateAction" = [
                    "RunInstances",
                    "CreateFleet"
                ]
            }
         }
      },
      { // New statement for SQS permissions
        "Effect": "Allow",
        "Action": [
          "sqs:GetQueueAttributes",
          "sqs:GetQueueUrl",
          "sqs:ReceiveMessage", // For Karpenter to receive termination notices
          "sqs:DeleteMessage",  // After processing a message
          "sqs:SendMessage"     // Potentially for sending messages, though less common for Karpenter itself
        ],
        // Restrict this to the specific SQS queue(s) Karpenter will use, if known.
        // For now, using "*" but this should be scoped down with the actual SQS queue ARN.
        // "Resource": "arn:aws:sqs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:${var.karpenter_sqs_queue_name}"
        // Using var.aws_region and var.karpenter_sqs_queue_name. Account ID needs to be available.
        // For a generic policy in a module, "*" might be used, or the specific ARN passed in.
        // For now, let's use "*" and note it should be restricted.
        "Resource": "*" // TODO: Restrict this to the specific SQS queue ARN for Spot interruptions
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "karpenter_controller_attach" {
  role       = aws_iam_role.karpenter_controller.name
  policy_arn = aws_iam_policy.karpenter_controller_policy.arn
}

# --- IAM Role and Instance Profile for Nodes launched by Karpenter ---
resource "aws_iam_role" "karpenter_node" {
  name = "${var.project_name}-karpenter-node-role-${var.cluster_name}-${var.environment}"
  tags = merge(var.tags, {
    Name = "${var.project_name}-karpenter-node-role-${var.cluster_name}-${var.environment}"
  })

  assume_role_policy = jsonencode({
    Version   = "2012-10-17",
    Statement = [
      {
        Effect    = "Allow",
        Principal = { Service = "ec2.amazonaws.com" },
        Action    = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "karpenter_node_eks_worker_node_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.karpenter_node.name
}

resource "aws_iam_role_policy_attachment" "karpenter_node_ec2_container_registry_read_only" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.karpenter_node.name
}

resource "aws_iam_role_policy_attachment" "karpenter_node_eks_cni_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy" # Required for VPC CNI
  role       = aws_iam_role.karpenter_node.name
}

resource "aws_iam_role_policy_attachment" "karpenter_node_ssm_managed_instance_core" {
  # Often useful for SSM agent connectivity, e.g., for Session Manager or patch management
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  role       = aws_iam_role.karpenter_node.name
}

resource "aws_iam_role_policy_attachment" "karpenter_node_cloudwatch_agent_server_policy" {
  count      = var.enable_karpenter_node_cloudwatch_metrics ? 1 : 0
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
  role       = aws_iam_role.karpenter_node.name
}

resource "aws_iam_instance_profile" "karpenter_node_profile" {
  name = "${var.project_name}-karpenter-node-profile-${var.cluster_name}-${var.environment}"
  role = aws_iam_role.karpenter_node.name
  tags = merge(var.tags, {
    Name = "${var.project_name}-karpenter-node-profile-${var.cluster_name}-${var.environment}"
  })
}
