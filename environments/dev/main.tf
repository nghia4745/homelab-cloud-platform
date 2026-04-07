# Dev environment module wiring
# This stack composes reuseable modules into one deployable environment.

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

module "iam" {
  source = "../../modules/iam"

  project_name = var.project_name
  environment  = var.environment

  tags = var.tags
}
