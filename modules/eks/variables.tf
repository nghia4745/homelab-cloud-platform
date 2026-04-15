# EKS Module Variables

# Core naming context shared across modules. This helps ensure consistent resource naming and tagging.
variable "project_name" {
  description = "Project identifier used in naming"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, stage, prod)"
  type        = string
}

# Cluster control plane settings
variable "cluster_name" {
  description = "EKS cluster name. If empty, module builds one from project and environment"
  type        = string
  default     = ""
}

variable "cluster_version" {
  description = "Kubernetes version for the EKS control plane"
  type        = string
  default     = "1.32"
}

variable "cluster_role_arn" {
  description = "IAM role ARN used by the EKS control plane"
  type        = string
}

# Networking inputs from modules/networking
# The EKS module consumes existing network infrastructure instead of creating its own.
variable "private_subnet_ids" {
  description = "Private subnet IDs where EKS control plane and node groups run"
  type        = list(string)
}

variable "cluster_security_group_id" {
  description = "Security group ID attached to the EKS control plane"
  type        = string
}

# API endpoint access controls
variable "endpoint_private_access" {
  description = "Whether the EKS API endpoint is accessible from within the VPC"
  type        = bool
  default     = true
}

variable "endpoint_public_access" {
  description = "Whether the EKS API endpoint is publicly accessible"
  type        = bool
  default     = false
}

variable "public_access_cidrs" {
  description = "CIDR blocks allowed to reach the public EKS API endpoint"
  type        = list(string)
  default     = []

  validation {
    condition     = !var.endpoint_public_access || length(var.public_access_cidrs) > 0
    error_message = "public_access_cidrs must contain at least one explicit CIDR when endpoint_public_access is true."
  }
}

# Managed node group settings
# These control the compute capacity that actually runs Pods in the cluster.
variable "node_group_name" {
  description = "Managed node group name. If empty, module builds one from project and environment"
  type        = string
  default     = ""
}

variable "node_role_arn" {
  description = "IAM role ARN used by EKS worker nodes"
  type        = string
}

variable "node_instance_types" {
  description = "EC2 instance types for worker nodes"
  type        = list(string)
  default     = ["t3.medium"]
}

variable "node_capacity_type" {
  description = "Node capacity type: ON_DEMAND or SPOT"
  type        = string
  default     = "ON_DEMAND"

  validation {
    condition     = contains(["ON_DEMAND", "SPOT"], var.node_capacity_type)
    error_message = "node_capacity_type must be either ON_DEMAND or SPOT."
  }
}

variable "node_disk_size" {
  description = "Disk size in GiB for each node"
  type        = number
  default     = 20
}

variable "node_desired_size" {
  description = "Desired number of worker nodes"
  type        = number
  default     = 2
}

variable "node_min_size" {
  description = "Minimum number of worker nodes"
  type        = number
  default     = 1
}

variable "node_max_size" {
  description = "Maximum number of worker nodes"
  type        = number
  default     = 3
}

# Shared tags applied to both the control plane and node group resources.

variable "tags" {
  description = "Common tags to apply to EKS resources"
  type        = map(string)
  default     = {}
}
