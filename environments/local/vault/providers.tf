terraform {
  required_version = ">= 1.14.0"

  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.6.0"
    }
  }
}

provider "docker" {
  host = "unix:///var/run/docker.sock"
}
