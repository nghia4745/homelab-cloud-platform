# IAM Module
# This module manages Identity and Access Management resources for EKS

locals {
  # Keep names deterministic across environments so role ownership is obvious in AWS.
  name_prefix = "${var.project_name}-${var.environment}"

  # Reuse a common tag set across all IAM resources. Later maps win, so the module
  # can enforce canonical tags like Environment and ManagedBy.
  common_tags = merge(var.tags, {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
    Module      = "iam"
  })
}

# IAM policy documents are used here to build JSON safely in Terraform instead of
# hand-writing JSON strings. This one defines who is allowed to assume the cluster role.
data "aws_iam_policy_document" "eks_cluster_assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["eks.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

# The cluster role is assumed by the EKS control plane service itself.
# Trust policy answers "who can assume this role?" while policy attachments answer
# "what can this role do after it is assumed?"
resource "aws_iam_role" "eks_cluster" {
  name               = "${local.name_prefix}-eks-cluster-role"
  assume_role_policy = data.aws_iam_policy_document.eks_cluster_assume_role.json

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-eks-cluster-role"
  })
}

# Managed policy attachment: the simplest way to give AWS-managed permissions to the role.
# This is easier to start with than custom inline policies and matches common EKS examples.
resource "aws_iam_role_policy_attachment" "eks_cluster_amazon_eks_cluster_policy" {
  role       = aws_iam_role.eks_cluster.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

# Worker nodes are EC2 instances, so the trusted principal here is ec2.amazonaws.com.
data "aws_iam_policy_document" "eks_node_assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

# The node role is assumed by EC2 instances in the EKS node group.
resource "aws_iam_role" "eks_node" {
  name               = "${local.name_prefix}-eks-node-role"
  assume_role_policy = data.aws_iam_policy_document.eks_node_assume_role.json

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-eks-node-role"
  })
}

# Worker node policy: lets EC2 nodes register with and participate in the cluster.
resource "aws_iam_role_policy_attachment" "eks_node_amazon_eks_worker_node_policy" {
  role       = aws_iam_role.eks_node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

# ECR read-only access: lets nodes pull container images for Pods.
resource "aws_iam_role_policy_attachment" "eks_node_amazon_ec2_container_registry_pull_only" {
  role       = aws_iam_role.eks_node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

# CNI policy: gives the VPC CNI plugin the rights needed to manage pod networking.
resource "aws_iam_role_policy_attachment" "eks_node_amazon_eks_cni_policy" {
  role       = aws_iam_role.eks_node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}
