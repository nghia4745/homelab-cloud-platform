# --------------------------------------------------------
# Terraform Remote Backend Configuration (S3)
# --------------------------------------------------------
# This backend stores Terraform state in S3 for shared/team workflows.
# - bucket: pre-created S3 bucket for state storage
# - key: path/name of the state file inside the bucket
# - region: AWS region where the S3 bucket exists
# - encrypt: enables server-side encryption for state at rest
#
# Optional (recommended for locking):
# - dynamodb_table: DynamoDB table name for state locking
# --------------------------------------------------------
terraform {
  backend "s3" {
    bucket         = "nghia-homelab-tfstate-2026"
    key            = "dev/homelab.tfstate"
    dynamodb_table = "nghia-homelab-tfstate-lock"
    region         = "us-east-1"
    encrypt        = true
  }
}