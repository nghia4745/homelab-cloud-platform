# Dev environment variables

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

variable "tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default     = {}
}
