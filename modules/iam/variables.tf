# IAM Module Variables
# These are the caller-provided inputs for naming, environment scoping, and tagging.
# IAM itself is global within an AWS account, so these values help keep roles organized.

variable "project_name" {
  description = "Project identifier used in naming"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, stage, prod)"
  type        = string
}

variable "tags" {
  description = "Common tags to apply to IAM resources"
  type        = map(string)
  default     = {}
}
