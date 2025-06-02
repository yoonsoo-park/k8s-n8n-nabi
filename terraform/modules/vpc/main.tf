locals {
  # Merge common tags with any module-specific tags
  common_tags = merge(
    var.tags,
    {
      "Project"     = var.project_name
      "Environment" = var.environment
      "Terraform"   = "true"
      "Module"      = "vpc"
    }
  )
  num_azs = length(var.availability_zones)
}

resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr_block
  enable_dns_hostnames = true
  enable_dns_support   = true
  tags                 = merge(local.common_tags, { Name = "${var.project_name}-vpc-${var.environment}" })
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
  tags   = merge(local.common_tags, { Name = "${var.project_name}-igw-${var.environment}" })
}

resource "aws_subnet" "public" {
  count                   = local.num_azs
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidrs[count.index]
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = true # Typically true for public subnets hosting LBs or NAT GWs

  tags = merge(local.common_tags, {
    Name                                  = "${var.project_name}-public-subnet-${var.availability_zones[count.index]}"
    "kubernetes.io/role/elb"              = "1" # For AWS Load Balancer Controller discovery
    "kubernetes.io/cluster/${var.project_name}-${var.environment}" = "shared" # For EKS cluster resource sharing
  })
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  tags   = merge(local.common_tags, { Name = "${var.project_name}-public-rt-${var.environment}" })

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }
}

resource "aws_route_table_association" "public" {
  count          = local.num_azs
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_eip" "nat" {
  count = var.enable_nat_gateway ? (var.single_nat_gateway ? 1 : local.num_azs) : 0
  # Using 'tags' instead of 'domain'
  tags  = merge(local.common_tags, { Name = "${var.project_name}-nat-eip-${count.index}-${var.environment}" })
  # depends_on = [aws_internet_gateway.main] # Not strictly necessary for EIP but good practice if issues arise
}

resource "aws_nat_gateway" "main" {
  count         = var.enable_nat_gateway ? (var.single_nat_gateway ? 1 : local.num_azs) : 0
  allocation_id = aws_eip.nat[count.index].id
  # NAT GW must be in a public subnet
  subnet_id     = aws_subnet.public[var.single_nat_gateway ? 0 : count.index].id

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-nat-gw-${var.single_nat_gateway ? "shared" : var.availability_zones[count.index]}"
  })

  depends_on = [aws_internet_gateway.main] # Ensure IGW is created before NAT GW
}

resource "aws_subnet" "private" {
  count                   = local.num_azs
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.private_subnet_cidrs[count.index]
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = false

  tags = merge(local.common_tags, {
    Name                                  = "${var.project_name}-private-subnet-${var.availability_zones[count.index]}"
    "kubernetes.io/role/internal-elb"     = "1" # For internal load balancers
    "kubernetes.io/cluster/${var.project_name}-${var.environment}" = "shared" # For EKS cluster resource sharing
    "karpenter.sh/discovery"              = "${var.project_name}-${var.environment}" # For Karpenter discovery
  })
}

resource "aws_route_table" "private" {
  count  = var.enable_nat_gateway ? local.num_azs : 0 # Only create route tables if NAT GW is enabled
  vpc_id = aws_vpc.main.id
  tags   = merge(local.common_tags, { Name = "${var.project_name}-private-rt-${var.availability_zones[count.index]}" })

  route {
    cidr_block     = "0.0.0.0/0"
    # Route to the NAT Gateway in the same AZ if not single_nat_gateway, else route to the single NAT GW
    nat_gateway_id = aws_nat_gateway.main[var.single_nat_gateway ? 0 : count.index].id
  }
}

resource "aws_route_table_association" "private" {
  count          = var.enable_nat_gateway ? local.num_azs : 0
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[count.index].id
}

# Default security group for the VPC.
# Often, specific security groups are created for EKS cluster, nodes, and LBs.
# This output can be used by other modules.
resource "aws_default_security_group" "default" {
  vpc_id = aws_vpc.main.id

  # Example: Allow all outbound, restrict inbound (default behavior is usually all outbound allow)
  # It's generally better to manage specific EKS SG rules in the EKS module.
  # For now, we'll just manage its tags.
  tags = merge(local.common_tags, {
    Name = "${var.project_name}-default-sg-${var.environment}"
  })
}
