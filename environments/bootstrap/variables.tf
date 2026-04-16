# Bootstrap environment variables

variable "aws_region" {
  description = "AWS region where backend infrastructure is created"
  type        = string
}

variable "project_name" {
  description = "Project identifier used in naming"
  type        = string
}

variable "environment" {
  description = "Environment label for bootstrap resources"
  type        = string
  default     = "bootstrap"
}

variable "state_bucket_name" {
  description = "Optional explicit state bucket name. Leave empty for generated name."
  type        = string
  default     = ""
}

variable "lock_table_name" {
  description = "Optional explicit lock table name. Leave empty for generated name."
  type        = string
  default     = ""
}

variable "force_destroy" {
  description = "Allow backend resources to be destroyed"
  type        = bool
  default     = false
}

variable "tags" {
  description = "Common tags to apply to backend resources"
  type        = map(string)
  default     = {}
}