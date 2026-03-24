# --------------------------------------------------------
# Docker app resources (nginx web server)
# --------------------------------------------------------
# - docker_image: pulls/keeps the nginx image
# - docker_container: starts nginx container with port mappings + env vars
# --------------------------------------------------------
resource "docker_image" "nginx" {
  name         = "nginx:latest"
  keep_locally = false
}

resource "docker_container" "web_server" {
  image = docker_image.nginx.image_id
  name  = "devops-practice-container"

  ports {
    internal = 80
    external = 8080
  }

  env = [
    "DB_USER=${data.vault_kv_secret_v2.db_creds.data["username"]}",
    "DB_PASS=${data.vault_kv_secret_v2.db_creds.data["password"]}"
  ]
}
