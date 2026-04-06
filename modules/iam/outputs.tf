# IAM Module Outputs
# Outputs are the public API of this module. The environment stack and EKS module
# consume these values rather than referencing IAM resources directly.

output "eks_cluster_role_name" {
  description = "Name of the EKS cluster IAM role"
  value       = aws_iam_role.eks_cluster.name
}

output "eks_cluster_role_arn" {
  description = "ARN of the EKS cluster IAM role"
  value       = aws_iam_role.eks_cluster.arn
}

output "eks_node_role_name" {
  description = "Name of the EKS worker node IAM role"
  value       = aws_iam_role.eks_node.name
}

output "eks_node_role_arn" {
  description = "ARN of the EKS worker node IAM role"
  value       = aws_iam_role.eks_node.arn
}
