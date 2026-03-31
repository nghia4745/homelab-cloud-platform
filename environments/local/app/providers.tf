terraform {
  required_version = ">= 1.14.0"

  required_providers {
    vault = {
      source  = "hashicorp/vault"
      version = "~> 5.8.0"
    }
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.6.0"
    }
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
