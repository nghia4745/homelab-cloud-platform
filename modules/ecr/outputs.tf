# ECR Module Outputs
# Expose repository identifiers so other stacks can push images to them
# or grant pull permissions to workloads.
#
# Output maps are keyed by the logical repository name from var.repository_names
# so callers can reference values predictably (example: module.ecr.repository_urls["app"]).

output "repository_names" {
  description = "Names of the ECR repositories"
  value       = { for repo_name, repo in aws_ecr_repository.this : repo_name => repo.name }
}

output "repository_arns" {
  description = "ARNs of the ECR repositories"
  value       = { for repo_name, repo in aws_ecr_repository.this : repo_name => repo.arn }
}

output "repository_urls" {
  description = "Repository URLs used for docker push and pull"
  value       = { for repo_name, repo in aws_ecr_repository.this : repo_name => repo.repository_url }
}

