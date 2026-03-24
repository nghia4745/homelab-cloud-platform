provider "vault" {
  address = "http://localhost:8200"
  token = "dev-token"
}

# Create a specific secret
resource "vault_kv_secret_v2" "db_creds" {
  mount = "secret"
  name = "database/config"

  data_json = jsonencode({
    username = "admin_duke",
    password = var.db_password
  })
}

# READ the secret from Vault
data "vault_kv_secret_v2" "db_creds" {
  mount = "secret"
  name = "database/config"
}
