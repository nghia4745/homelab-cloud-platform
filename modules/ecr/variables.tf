# ECR Module Variables

# Inputs follow the same pattern as other modules:
# - project/env naming context
# - module-specific behavior toggles
# - shared tag map from the caller

variable "project_name" {
  description = "Project identifier used in naming"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, stage, prod)"
  type        = string
}

variable "repository_names" {
  description = "List of ECR repositories, logical repository suffixes to create (example: app, worker)"
  type        = list(string)
}

variable "image_tag_mutability" {
  description = "Tag overwrite policy for images: MUTABLE or IMMUTABLE"
  type        = string
  default     = "MUTABLE"
}

variable "scan_on_push" {
  description = "Enable basic vulnerability scanning when images are pushed"
  type        = bool
  default     = false
}

variable "tags" {
  description = "Tags to apply to the ECR repositories"
  type        = map(string)
  default     = {}
}
