# Networking Module Variables
# These are the inputs to the module. Callers provide environment-specific values,
# and the resources in main.tf turn those inputs into actual AWS networking.

variable "project_name" {
  description = "Project identifier used in naming"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, stage, prod)"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
}

variable "azs" {
  description = "Availability zones to use"
  type        = list(string)

  validation {
    condition     = length(var.azs) >= 2
    error_message = "At least 2 AZs are required for HA."
  }
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets, one per AZ"
  type        = list(string)

  validation {
    condition     = length(var.public_subnet_cidrs) == length(var.azs)
    error_message = "public_subnet_cidrs length must match azs length."
  }
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets, one per AZ"
  type        = list(string)

  validation {
    condition     = length(var.private_subnet_cidrs) == length(var.azs)
    error_message = "private_subnet_cidrs length must match azs length."
  }
}

variable "enable_nat_gateway" {
  description = "Whether to create NAT gateway(s) for private subnet egress"
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
  description = "Common tags applied to all networking resources"
  type        = map(string)
  default     = {}
}
