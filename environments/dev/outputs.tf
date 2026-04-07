# Dev environment outputs
# Re-export key values from networking and IAM modules so they are visible after apply.

output "vpc_id" {
  description = "VPC ID created by networking module"
  value       = module.networking.vpc_id
}

output "public_subnet_ids" {
  description = "Public subnet IDs created by networking module"
  value       = module.networking.public_subnet_ids
}

output "private_subnet_ids" {
  description = "Private subnet IDs created by networking module"
  value       = module.networking.private_subnet_ids
}

output "cluster_security_group_id" {
  description = "EKS cluster security group ID from networking module"
  value       = module.networking.cluster_security_group_id
}

output "node_security_group_id" {
  description = "EKS node security group ID from networking module"
  value       = module.networking.node_security_group_id
}

output "eks_cluster_role_arn" {
  description = "EKS cluster IAM role ARN from IAM module"
  value       = module.iam.eks_cluster_role_arn
}

output "eks_node_role_arn" {
  description = "EKS node IAM role ARN from IAM module"
  value       = module.iam.eks_node_role_arn
}
