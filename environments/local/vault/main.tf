resource "docker_image" "vault" {
  name         = "hashicorp/vault:latest"
  keep_locally = true
}

resource "docker_container" "vault_server" {
  name  = "vault-server"
  image = docker_image.vault.image_id

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
