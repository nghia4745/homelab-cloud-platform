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

data "aws_caller_identity" "current" {}

data "aws_iam_policy_document" "cluster_encryption_kms" {
  statement {
    sid    = "AllowAccountAdministration"
    effect = "Allow"

    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"]
    }

    actions   = ["kms:*"]
    resources = ["*"]
  }

  statement {
    sid    = "AllowEKSClusterRoleUseOfKey"
    effect = "Allow"

    principals {
      type        = "AWS"
      identifiers = [var.cluster_role_arn]
    }

    actions = [
      "kms:Encrypt",
      "kms:Decrypt",
      "kms:ReEncrypt*",
      "kms:GenerateDataKey*",
      "kms:DescribeKey"
    ]

    resources = ["*"]
  }

  statement {
    sid    = "AllowEKSClusterRoleGrantManagement"
    effect = "Allow"

    principals {
      type        = "AWS"
      identifiers = [var.cluster_role_arn]
    }

    actions = [
      "kms:CreateGrant",
      "kms:ListGrants",
      "kms:RevokeGrant"
    ]

    resources = ["*"]

    condition {
      test     = "Bool"
      variable = "kms:GrantIsForAWSResource"
      values   = ["true"]
    }
  }
}

# KMS key used by the EKS control plane to encrypt Kubernetes Secrets at rest.
resource "aws_kms_key" "cluster_encryption" {
  description             = "KMS key for EKS secrets encryption: ${local.cluster_name}"
  enable_key_rotation     = true
  deletion_window_in_days = 7
  policy                  = data.aws_iam_policy_document.cluster_encryption_kms.json

  tags = merge(local.common_tags, {
    Name = "${local.cluster_name}-secrets-kms"
  })
}

resource "aws_kms_alias" "cluster_encryption" {
  name          = "alias/${local.cluster_name}-secrets"
  target_key_id = aws_kms_key.cluster_encryption.key_id
}

# The EKS cluster is the Kubernetes control plane managed by AWS.
# You do not see or manage the control plane EC2 instances - AWS handles that.
# You only configure networking, IAM, and access settings.
resource "aws_eks_cluster" "this" {
  name     = local.cluster_name
  version  = var.cluster_version
  role_arn = var.cluster_role_arn

  enabled_cluster_log_types = var.enabled_cluster_log_types

  # vpc_config tells EKS which subnets and security groups to attach the control plane to.
  vpc_config {
    subnet_ids              = var.private_subnet_ids
    security_group_ids      = [var.cluster_security_group_id]
    endpoint_private_access = var.endpoint_private_access
    endpoint_public_access  = var.endpoint_public_access
    public_access_cidrs     = var.public_access_cidrs
  }

  encryption_config {
    resources = ["secrets"]
    provider {
      key_arn = aws_kms_key.cluster_encryption.arn
    }
  }

  tags = merge(local.common_tags, {
    Name = local.cluster_name
  })
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
  disk_size      = var.node_disk_size

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

  tags = merge(local.common_tags, {
    Name = local.node_group_name
  })
}