# 1. Define the Provider (The "Plugin" for Docker)
terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.0"
    }
  }
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
}
