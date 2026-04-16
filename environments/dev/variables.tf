# Dev environment variables
# This file defines the input contract for the dev stack.
# Values are typically provided via dev.auto.tfvars and then passed from
# environments/dev/main.tf into reusable modules.

# Core environment identity and provider settings

variable "project_name" {
  description = "Project identifier used in naming"
  type        = string
}

variable "environment" {
  description = "Environment"
  type        = string
  default     = "dev"
}

variable "aws_region" {
  description = "AWS region for the dev environment"
  type        = string
}

# Shared tagging metadata passed through to all modules

variable "tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default     = {}
}

# Networking inputs consumed by modules/networking

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
}

variable "azs" {
  description = "Availability zones to use"
  type        = list(string)
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets, one per AZ"
  type        = list(string)
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets, one per AZ"
  type        = list(string)
}

variable "enable_nat_gateway" {
  description = "Whether to create NAT gateway(s)"
  type        = bool
  default     = true
}

variable "single_nat_gateway" {
  description = "Use single shared NAT gateway instead of one per AZ"
  type        = bool
  default     = true
}

# Security group source ranges for cluster and worker node traffic

variable "cluster_security_group_ingress_cidrs" {
  description = "CIDRs allowed to reach EKS control plane SG"
  type        = list(string)
  default     = ["10.0.0.0/8"]
}

variable "node_security_group_ingress_cidrs" {
  description = "CIDRs allowed to reach EKS worker nodes SG"
  type        = list(string)
  default     = ["10.0.0.0/8"]
}

# ECR module inputs (repository names and image behavior)

variable "ecr_repository_names" {
  description = "Logical ECR repository names to create (for example: app, worker)"
  type        = list(string)
  default     = ["app"]
}

variable "ecr_force_delete" {
  description = "Allow Terraform to delete ECR repositories that still contain images (convenient for dev, keep false for production)"
  type        = bool
  default     = true
}

# EKS module inputs (cluster and node group settings, plus networking inputs passed through from modules/networking)
# These tune Kubernetes version and worker node sizing without exposing the
# lower-level networking and IAM dependencies directly to the caller.

variable "eks_cluster_version" {
  description = "Kubernetes version for EKS cluster"
  type        = string
  default     = "1.32"
}

variable "eks_node_instance_types" {
  description = "EC2 instance types for EKS worker nodes"
  type        = list(string)
  default     = ["t3.small"]
}

variable "eks_node_capacity_type" {
  description = "Node capacity type: ON_DEMAND or SPOT"
  type        = string
  default     = "ON_DEMAND"

  validation {
    condition     = contains(["ON_DEMAND", "SPOT"], var.eks_node_capacity_type)
    error_message = "eks_node_capacity_type must be either ON_DEMAND or SPOT."
  }
}

variable "eks_node_desired_size" {
  description = "Desired number of EKS worker nodes"
  type        = number
  default     = 1
}

variable "eks_node_min_size" {
  description = "Minimum number of EKS worker nodes"
  type        = number
  default     = 0
}

variable "eks_node_max_size" {
  description = "Maximum number of EKS worker nodes"
  type        = number
  default     = 1
}

variable "eks_endpoint_private_access" {
  description = "Whether EKS API endpoint is accessible only within the VPC"
  type        = bool
  default     = true
}

variable "eks_endpoint_public_access" {
  description = "Whether EKS API endpoint is accessible from the public internet"
  type        = bool
  default     = false
}

variable "eks_public_access_cidrs" {
  description = "CIDRs allowed to access EKS API endpoint when public access is enabled"
  type        = list(string)
  default     = []
}