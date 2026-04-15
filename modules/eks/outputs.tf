# EKS Module Outputs
# Expose cluster identifiers and connection info so other modules and
# operators can interact with the Kubernetes cluster.
#
# The certificate authority output is marked sensitive because clients use it
# to establish trust when talking to the Kubernetes API server.

output "cluster_id" {
  description = "EKS cluster ID (same as cluster name)"
  value       = aws_eks_cluster.this.id
}

output "cluster_arn" {
  description = "EKS cluster ARN"
  value       = aws_eks_cluster.this.arn
}

output "cluster_endpoint" {
  description = "EKS cluster API endpoint URL"
  value       = aws_eks_cluster.this.endpoint
}

output "cluster_version" {
  description = "Kubernetes version running on the cluster"
  value       = aws_eks_cluster.this.version
}

output "cluster_certificate_authority_data" {
  description = "Base64-encoded certificate authority data for the cluster"
  value       = aws_eks_cluster.this.certificate_authority[0].data
  sensitive   = true
}

output "node_group_id" {
  description = "EKS node group ID"
  value       = aws_eks_node_group.this.id
}

output "node_group_arn" {
  description = "EKS node group ARN"
  value       = aws_eks_node_group.this.arn
}

output "node_group_status" {
  description = "Status of the EKS node group (CREATING, ACTIVE, DELETING, FAILED, UPDATING, PENDING)"
  value       = aws_eks_node_group.this.status
}
