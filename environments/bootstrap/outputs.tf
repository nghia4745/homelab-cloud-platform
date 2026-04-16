# Bootstrap environment outputs

output "state_bucket_name" {
  description = "S3 bucket name for Terraform state"
  value       = module.state_backend.state_bucket_name
}

output "dynamodb_table_name" {
  description = "DynamoDB table name for Terraform state locking"
  value       = module.state_backend.dynamodb_table_name
}
