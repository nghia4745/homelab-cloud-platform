# Define the Vault Image
resource "docker_image" "vault" {
  name         = "hashicorp/vault:latest"
  keep_locally = true
}

# Define the Vault Container
resource "docker_container" "vault_server" {
  name  = "vault-server"
  image = docker_image.vault.image_id
  
  # Mimic the 'docker run' flags we used earlier
  capabilities {
    add = ["IPC_LOCK"]
  }

  ports {
    internal = 8200
    external = 8200
  }

  env = [
    "VAULT_DEV_ROOT_TOKEN_ID=dev-token",
    "VAULT_ADDR=http://0.0.0.0:8200"
  ]
}

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
