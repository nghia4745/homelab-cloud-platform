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

  validation {
    condition     = length(distinct(var.repository_names)) == length(var.repository_names)
    error_message = "repository_names must contain distinct values; duplicate repository names are not allowed."
  }

  validation {
    condition = alltrue([
      for name in var.repository_names :
      can(regex("^(?:[a-z0-9]+(?:[._-][a-z0-9]+)*/)*[a-z0-9]+(?:[._-][a-z0-9]+)*$", name))
    ])
    error_message = "Each value in repository_names must be a valid ECR repository name using lowercase letters, numbers, slashes (/), periods (.), underscores (_), and hyphens (-)."
  }
}

variable "image_tag_mutability" {
  description = "Tag overwrite policy for images: MUTABLE or IMMUTABLE"
  type        = string
  default     = "MUTABLE"

  validation {
    condition     = contains(["MUTABLE", "IMMUTABLE"], var.image_tag_mutability)
    error_message = "image_tag_mutability must be either MUTABLE or IMMUTABLE."
  }
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
