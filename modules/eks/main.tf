# EKS Module
# This module provisions an Amazon EKS (Elastic Kubernetes Service) cluster
# and a managed node group. It consumes outputs from modules/networking
# (subnet IDs, security group ID) and modules/iam (cluster and node role ARNs).

locals {
  # Build names from project/environment unless the caller provides an override.
  cluster_name    = var.cluster_name != "" ? var.cluster_name : "${var.project_name}-${var.environment}-eks"
  node_group_name = var.node_group_name != "" ? var.node_group_name : "${var.project_name}-${var.environment}-nodes"

  # Apply a consistent tag set across both resources for easier filtering in AWS.
  common_tags = merge(var.tags, {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
    Module      = "eks"
  })
}

# The EKS cluster is the Kubernetes control plane managed by AWS.
# You do not see or manage the control plane EC2 instances - AWS handles that.
# You only configure networking, IAM, and access settings.
resource "aws_eks_cluster" "this" {
  name     = local.cluster_name
  version  = var.cluster_version
  role_arn = var.cluster_role_arn

  # vpc_config tells EKS which subnets and security groups to attach the control plane to.
  vpc_config {
    subnet_ids              = var.private_subnet_ids
    security_group_ids      = [var.cluster_security_group_id]
    endpoint_private_access = var.endpoint_private_access
    endpoint_public_access  = var.endpoint_public_access
    public_access_cidrs     = var.public_access_cidrs
  }

  tags = merge(local.common_tags, {
    Name = local.cluster_name
  })
}

resource "aws_launch_template" "node_group" {
  name_prefix            = "${local.node_group_name}-"
  update_default_version = true
  vpc_security_group_ids = [var.node_security_group_id]

  block_device_mappings {
    device_name = "/dev/xvda"

    ebs {
      volume_size           = var.node_disk_size
      volume_type           = "gp3"
      delete_on_termination = true
      encrypted             = true
    }
  }
}

# Managed node group: AWS-managed EC2 instances that register as Kubernetes worker nodes.
# The node group depends on the cluster existing first; the implicit reference to the
# aws_eks_cluster.this.name creates that dependency automatically.
resource "aws_eks_node_group" "this" {
  cluster_name    = aws_eks_cluster.this.name
  node_group_name = local.node_group_name
  node_role_arn   = var.node_role_arn
  subnet_ids      = var.private_subnet_ids

  instance_types = var.node_instance_types
  capacity_type  = var.node_capacity_type

  # scaling_config controls how many nodes exist at any point in time.
  scaling_config {
    desired_size = var.node_desired_size
    min_size     = var.node_min_size
    max_size     = var.node_max_size
  }

  # update_config controls how many nodes can be unavailable during a rolling update.
  update_config {
    max_unavailable = 1
  }

  launch_template {
    id      = aws_launch_template.node_group.id
    version = aws_launch_template.node_group.latest_version
  }

  tags = merge(local.common_tags, {
    Name = local.node_group_name
  })
}
