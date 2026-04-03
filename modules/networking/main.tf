# Networking Module
# This module manages network infrastructure including VPCs, subnets, and security groups

locals {
  # Reuse a consistent prefix so resource names stay predictable across environments.
  name_prefix = "${var.project_name}-${var.environment}"

  # Merge caller-provided tags with module-owned tags.
  # Later maps win, so the module enforces canonical values like Environment.
  common_tags = merge(var.tags, {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
    Module      = "networking"
  })

  # One NAT for cost efficiency in dev, or one per AZ for stronger HA.
  nat_gateway_count = var.enable_nat_gateway ? (var.single_nat_gateway ? 1 : length(var.azs)) : 0
}

# The VPC is the top-level network boundary. Everything else in this module lives inside it.
resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-vpc"
  })
}

# Public subnets are internet-routable once they are associated with a route table
# that points 0.0.0.0/0 at the Internet Gateway.
resource "aws_subnet" "public" {
  for_each = zipmap(var.azs, var.public_subnet_cidrs)

  vpc_id            = aws_vpc.this.id
  cidr_block        = each.value
  availability_zone = each.key

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-public-${each.key}"
  })
}

# Private subnets do not get a direct route to the Internet Gateway.
# They use a NAT Gateway for outbound internet access when enabled.
resource "aws_subnet" "private" {
  for_each = zipmap(var.azs, var.private_subnet_cidrs)

  vpc_id            = aws_vpc.this.id
  cidr_block        = each.value
  availability_zone = each.key

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-private-${each.key}"
  })
}

# The Internet Gateway is the VPC's direct connection to the public internet.
resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-igw"
  })
}

# NAT Gateways require Elastic IPs because they present public egress addresses
# on behalf of resources that stay private inside the VPC.
resource "aws_eip" "nat" {
  count = local.nat_gateway_count

  domain = "vpc"

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-nat-eip-${count.index + 1}"
  })
}

# NAT must live in a public subnet. Private subnets route to it for outbound-only internet access.
resource "aws_nat_gateway" "this" {
  count = local.nat_gateway_count

  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = var.single_nat_gateway ? values(aws_subnet.public)[0].id : values(aws_subnet.public)[count.index].id

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-nat-${count.index + 1}"
  })

  depends_on = [aws_internet_gateway.this]
}

# One shared public route table is enough because every public subnet has the same behavior:
# send internet-bound traffic to the Internet Gateway.
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this.id
  }

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-public-rt"
  })
}

resource "aws_route_table_association" "public" {
  for_each = aws_subnet.public

  subnet_id      = each.value.id
  route_table_id = aws_route_table.public.id
}

# Private route tables either share one NAT route or get one route table per AZ,
# depending on the single_nat_gateway setting.
resource "aws_route_table" "private" {
  count = local.nat_gateway_count

  vpc_id = aws_vpc.this.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.this[count.index].id
  }

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-private-rt-${count.index + 1}"
  })
}

resource "aws_route_table_association" "private" {
  count = length(var.azs)

  subnet_id      = values(aws_subnet.private)[count.index].id
  route_table_id = var.single_nat_gateway ? aws_route_table.private[0].id : aws_route_table.private[count.index].id
}

# These security groups are EKS-oriented defaults kept here for learning purposes.
# A stricter production design may move them into the EKS module later.
resource "aws_security_group" "cluster" {
  name        = "${local.name_prefix}-cluster-sg"
  description = "EKS cluster control plane security group"
  vpc_id      = aws_vpc.this.id

  ingress {
    description = "Allow inbound to EKS control plane"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = var.cluster_security_group_ingress_cidrs
  }

  egress {
    description = "Allow all outbound traffic to worker nodes"
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    cidr_blocks = var.node_security_group_ingress_cidrs
  }

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-cluster-sg"
  })
}

# Worker nodes need a wider TCP range because Kubernetes workloads and response traffic
# often use ephemeral ports rather than only well-known ports like 80 or 443.
resource "aws_security_group" "nodes" {
  name        = "${local.name_prefix}-nodes-sg"
  description = "EKS worker nodes security group"
  vpc_id      = aws_vpc.this.id

  ingress {
    description = "Allow inbound to worker nodes"
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    cidr_blocks = var.node_security_group_ingress_cidrs
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-nodes-sg"
  })
}