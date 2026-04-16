# Bootstrap environment module wiring
# Creates S3 + DynamoDB resources used by other stacks as remote backend

module "state_backend" {
  source = "../../modules/s3"

  project_name        = var.project_name
  environment         = var.environment
  bucket_name         = var.state_bucket_name
  dynamodb_table_name = var.lock_table_name
  force_destroy       = var.force_destroy

  tags = var.tags
}