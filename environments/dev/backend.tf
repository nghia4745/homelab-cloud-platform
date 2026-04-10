# Dev environment backend configuration
# Remote state is stored in S3 (durable, versioned) and locked via DynamoDB so
# concurrent applies cannot corrupt state. The unique key per stack (dev/homelab.tfstate)
# means all environments can share the same bucket and lock table without colliding.

terraform {
  backend "s3" {
    bucket         = "nghia-homelab-tfstate-2026"
    key            = "dev/homelab.tfstate"
    dynamodb_table = "nghia-homelab-tfstate-lock"
    region         = "us-east-1"
    encrypt        = true
  }
}