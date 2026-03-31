resource "terraform_data" "wait_for_vault" {
  provisioner "local-exec" {
    command = "for i in $(seq 1 30); do curl -sSf http://localhost:8200/v1/sys/health >/dev/null && exit 0; sleep 2; done; echo 'Vault is not ready on localhost:8200' >&2; exit 1"
  }
}

resource "vault_kv_secret_v2" "db_creds" {
  depends_on = [terraform_data.wait_for_vault]

  mount = "secret"
  name  = "database/config"

  data_json = jsonencode({
    username = "admin_duke"
    password = var.db_password
  })
}

data "vault_kv_secret_v2" "db_creds" {
  depends_on = [vault_kv_secret_v2.db_creds]

  mount = "secret"
  name  = "database/config"
}
