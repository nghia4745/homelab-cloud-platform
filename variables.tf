# --------------------------------------------------------
# Input variables for Terraform configuration
# --------------------------------------------------------
# - db_password: sensitive variable for database credentials
#   sensitive = true prevents value from being logged in output
# --------------------------------------------------------
variable "db_password" {
  description = "The database password"
  type        = string
  sensitive   = true
}
