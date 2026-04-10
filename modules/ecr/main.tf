# ECR Module
# This module creates and manages Elastic Container Registry (ECR) repositories

locals {
  # Keep names deterministic and environment-scoped for easier lookup in AWS.
  name_prefix = "${var.project_name}-${var.environment}"

  # Shared tags applied to all repositories; caller-provided tags are preserved.
  common_tags = merge(var.tags, {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
    Module      = "ecr"
  })
}

# Create one repository per logical name.
# Example input: ["app", "worker"] -> homelab-dev-app, homelab-dev-worker
resource "aws_ecr_repository" "this" {
  for_each = toset(var.repository_names)

  name                 = "${local.name_prefix}-${each.value}"
  image_tag_mutability = var.image_tag_mutability
  # In learning/dev environments we often destroy frequently; this avoids manual image cleanup.
  force_delete = true

  # scan_on_push enables ECR's image scanning integration on each push.
  image_scanning_configuration {
    scan_on_push = var.scan_on_push
  }

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-${each.value}"
  })
}

