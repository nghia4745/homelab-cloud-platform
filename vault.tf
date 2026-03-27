# --------------------------------------------------------
# Vault secret management (KV V2) resources
# --------------------------------------------------------
# - vault_kv_secret_v2 resource: writes credentials to Vault
# - data source: reads credentials from Vault for use by other resources
# - depends_on ensures Vault container exists prior to secret creation
# --------------------------------------------------------
resource "vault_kv_secret_v2" "db_creds" {
  depends_on = [docker_container.vault_server]

  mount = "secret"
  name  = "database/config"

  data_json = jsonencode({
    username = "admin_duke",
    password = var.db_password
  })
}

# TODO: Use ephemeral credentials with a lease instead of static credentials for better security practices
# later on, ignore this deprecation warning for now as we are just demonstrating the concept of Vault integration in Terraform
data "vault_kv_secret_v2" "db_creds" {
  depends_on = [vault_kv_secret_v2.db_creds]

  mount = "secret"
  name  = "database/config"
}
