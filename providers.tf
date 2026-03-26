# --------------------------------------------------------
# Terraform settings & provider requirements
# --------------------------------------------------------
# - required_version: ensures the installed terraform is compatible
# - required_providers: pins to provider versions for repeatable plans
#   and avoids incompatible upgrades
# --------------------------------------------------------
terraform {
  required_version = ">= 1.14.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.37.0"
    }
    vault = {
      source  = "hashicorp/vault"
      version = "~> 5.8.0"
    }
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.6.0"
    }
  }

  backend "s3" {
    bucket  = "nghia-homelab-tfstate-2026"
    key     = "dev/homelab.tfstate"
    region  = "us-east-1"
    encrypt = true
  }
}

provider "docker" {
  host = "unix:///var/run/docker.sock"
}

provider "vault" {
  address          = "http://localhost:8200"
  token            = "dev-token"
  skip_child_token = true
}

provider "aws" {
  region                      = "us-east-1"
  skip_credentials_validation = true
  skip_requesting_account_id  = true
  skip_metadata_api_check     = true
  access_key                  = "mock_access_key"
  secret_key                  = "mock_secret_key"
}
