# Dev environment module wiring
# This file is the composition layer: it calls reusable modules and passes
# environment-specific values from variables.tf. No AWS resources are defined
# here directly — all that logic lives inside each module.

# ── Networking ────────────────────────────────────────────────────────────────
# Creates the VPC, subnets (public and private), Internet Gateway, optional
# NAT Gateways, route tables, and the EKS-oriented cluster/node security groups.
# All CIDR ranges and AZ assignments come from dev.auto.tfvars.
module "networking" {
  source = "../../modules/networking"

  project_name = var.project_name
  environment  = var.environment

  vpc_cidr             = var.vpc_cidr
  azs                  = var.azs
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs

  enable_nat_gateway = var.enable_nat_gateway
  single_nat_gateway = var.single_nat_gateway

  cluster_security_group_ingress_cidrs = var.cluster_security_group_ingress_cidrs
  node_security_group_ingress_cidrs    = var.node_security_group_ingress_cidrs

  tags = var.tags
}

# ── IAM ───────────────────────────────────────────────────────────────────────
# Creates the EKS cluster IAM role and worker node IAM role, plus the required
# AWS-managed policy attachments for each. These roles are prerequisite inputs
# for the EKS module (planned next) which provisions the control plane and node groups.
module "iam" {
  source = "../../modules/iam"

  project_name = var.project_name
  environment  = var.environment

  tags = var.tags
}

# ── ECR ───────────────────────────────────────────────────────────────────────
# Creates image repositories used by workloads and CI image publishing.
# Keeping this separate from EKS lets you provision image storage early.
module "ecr" {
  source = "../../modules/ecr"

  project_name = var.project_name
  environment  = var.environment

  repository_names     = var.ecr_repository_names
  force_delete         = var.ecr_force_delete

  tags = var.tags
}
