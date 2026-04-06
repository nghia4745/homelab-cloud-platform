terraform {
  backend "s3" {
    bucket         = "nghia-homelab-tfstate-2026"
    key            = "local/local-vault.tfstate"
    dynamodb_table = "nghia-homelab-tfstate-lock"
    region         = "us-east-1"
    encrypt        = true
  }
}
