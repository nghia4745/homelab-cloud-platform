# S3 backend module variables

variable "project_name" {
  description = "Project identifier used in naming"
  type        = string
}

variable "environment" {
  description = "Environment or stack name (for example: bootstrap, dev, prod)"
  type        = string
}

variable "bucket_name" {
  description = "Optional explicit S3 bucket name for Terraform state. Leave empty to auto-generate."
  type        = string
  default     = ""
}

variable "dynamodb_table_name" {
  description = "Optional explicit DynamoDB table name for state locking. Leave empty to auto-generate."
  type        = string
  default     = ""
}

variable "dynamodb_kms_key_arn" {
  description = "Optional existing CMK ARN for DynamoDB table encryption. Leave empty to create one in this module."
  type        = string
  default     = ""
}

variable "force_destroy" {
  description = "Allow S3 bucket destruction during Terraform destroy (useful for learning env)"
  type        = bool
  default     = false
}

variable "tags" {
  description = "Common tags to apply to resources"
  type        = map(string)
  default     = {}
}
