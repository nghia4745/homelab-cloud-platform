# --------------------------------------------------------
# Terraform Configuration Block
# --------------------------------------------------------
# This block defines the overall Terraform settings, including:
# - required_version: Specifies the minimum Terraform version required for compatibility.
# - required_providers: Locks provider versions to ensure consistent and repeatable deployments,
#   preventing unexpected upgrades that could introduce breaking changes.
# --------------------------------------------------------
terraform {
  required_version = ">= 1.14.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.37.0"
    }
  }
}

# --------------------------------------------------------
# AWS Provider Configuration
# --------------------------------------------------------
# Configures the AWS provider for interacting with AWS services.
# Uses mock credentials for local testing or simulation; replace with real credentials in production.
# Skips various validations to allow for mock or local environments.
# --------------------------------------------------------
provider "aws" {
  region                      = "us-east-1"
  skip_credentials_validation = true
  skip_requesting_account_id  = true
  skip_metadata_api_check     = true
  access_key                  = "mock_access_key"
  secret_key                  = "mock_secret_key"
}
