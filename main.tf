# 1. Define the Provider (The "Plugin" for Docker)
terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.0"
    }
  }

  # backend "s3" {
  #   bucket         = "my-homelab-terraform-state"
  #   key            = "dev/docker-project.tfstate"
  #   region         = "us-east-1"
  #   encrypt        = true              # Mandatory for security
  #   use_lockfile   = true              # Modern 2026 S3 native locking
  # }
}

provider "docker" {
  # Connects to your local Docker socket
  host = "unix:///var/run/docker.sock"
}

# 2. Define the Image (What to download)
resource "docker_image" "nginx" {
  name         = "nginx:latest"
  keep_locally = false
}

# 3. Define the Container (How to run it)
resource "docker_container" "web_server" {
  image = docker_image.nginx.image_id
  name  = "devops-practice-container"
  
  ports {
    internal = 80
    external = 8080
  }

  # Inject the secrets as env variables
  env = [
    "DB_USER=${data.vault_kv_secret_v2.db_creds.data["username"]}",
    "DB_PASS=${data.vault_kv_secret_v2.db_creds.data["password"]}"
  ]
}
