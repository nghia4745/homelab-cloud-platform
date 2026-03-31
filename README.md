```markdown
# Terraform DevOps Learning Project
![Security Scan](https://github.com/nghia4745/homelab-cloud-platform/actions/workflows/security-scan.yml/badge.svg)

A hands-on Terraform project demonstrating infrastructure-as-code concepts with Docker, Vault secret management, AWS resources, custom security policies, and CI/CD automation.

## 📋 Prerequisites

- Terraform >= 1.14.0
- Docker (running locally)
- HashiCorp Vault (started via Terraform)
- AWS credentials (for mock AWS resources)
- Checkov (for custom security policies)
- Infracost (for cost estimation, optional for CI/CD)

## 🏗️ Project Structure

```
.
├── providers.tf           # Root AWS provider configuration
├── aws.tf                 # AWS resources (S3 bucket + security group)
├── secret.auto.tfvars    # Sensitive variables (auto-loaded, git-ignored)
├── environments/
│   └── local/
│      ├── vault/         # Stack A: local Vault runtime (Docker)
│      └── app/           # Stack B: Vault secrets + nginx app
├── policies/             # Custom Checkov security policies
│   └── tagging_policy.yml # Enforces Owner tag on S3 buckets
├── .github/workflows/    # GitHub Actions CI/CD workflows
│   ├── security-scan.yml # Runs Checkov security scans
│   ├── infracost.yml     # Estimates infrastructure costs on PRs
│   └── drift-detection.yml # Hourly drift detection via Terraform plan
└── README.md             # This file
```

## 🚀 Quick Start

### One-command workflow (recommended)
```bash
make init
make up
```
This initializes both stacks, applies Stack A first (Vault), then applies Stack B (app + secrets).

To tear down everything in the correct order:
```bash
make down
```

### 1. Bootstrap Vault stack (Stack A)
```bash
terraform -chdir=environments/local/vault init
terraform -chdir=environments/local/vault plan
terraform -chdir=environments/local/vault apply
```
This creates and starts the local Vault container on port 8200.

### 2. Deploy app + secrets stack (Stack B)
```bash
terraform -chdir=environments/local/app init
terraform -chdir=environments/local/app plan
terraform -chdir=environments/local/app apply
```
This writes credentials into Vault and starts nginx with Vault-backed environment variables.

### 3. Verify resources
```bash
# Check running Docker containers
docker ps

# Check Vault is running on port 8200
curl http://localhost:8200/v1/sys/health

# Check nginx is running on port 8080
curl http://localhost:8080
```

### 4. Destroy in reverse order
```bash
terraform -chdir=environments/local/app destroy
terraform -chdir=environments/local/vault destroy
```

## 📦 What This Project Creates

### Docker Resources
- **Vault Server**: HashiCorp Vault running in dev mode (port 8200)
  - Stores and manages database credentials
  - Token: `dev-token`
- **Nginx Web Server**: Web server container (port 8080)
  - Receives database credentials from Vault as environment variables

### Vault Resources
- **KV V2 Secret**: Stores database credentials at `secret/database/config`
  - Username: `admin_duke`
  - Password: from `secret.auto.tfvars`

### AWS Resources (Mock)
- **S3 Bucket**: `my-secure-data-bucket-2026` with encryption and public access blocking
  - Server-side encryption enabled (AES256)
  - All public access blocked
- **Security Group**: `allow_web_only` restricted to HTTP traffic
  - Ingress: Allows port 80 (HTTP) only
  - Egress: Allows all outbound traffic

## 🔐 Configuration

### Variables
Edit `secret.auto.tfvars` to customize:
```hcl
db_password = "your-secure-password-here"
```

> ⚠️ **Security Note**: `secret.auto.tfvars` is auto-loaded and should be git-ignored. Keep sensitive values out of version control.

## 🛡️ Security & CI/CD

### Custom Policies
- **Checkov Policy**: `policies/tagging_policy.yml` enforces Owner tags on S3 buckets.

### GitHub Actions Workflows
- **Security Scan**: Runs Checkov on pushes/PRs to main, using custom policies.
- **Infracost Estimate**: Calculates cost diffs on PRs and posts comments.
- **Drift Detection**: Hourly Terraform plan checks for infrastructure drift.

To run locally:
```bash
# Security scan with custom policies
checkov -d . --external-checks-dir policies --framework terraform

# Cost estimate
infracost breakdown --path=.
```

## 📝 Key Terraform Concepts Demonstrated

- **Providers**: Docker, Vault, and AWS plugin configuration
- **Resources**: Creating and managing infrastructure objects
- **Data Sources**: Reading existing Vault secrets
- **Dependencies**: Explicit `depends_on` for sequencing resource creation
- **Variables**: Sensitive input variables for credentials
- **Interpolation**: Referencing resource outputs and data source values
- **Custom Policies**: Writing and applying Checkov security checks
- **CI/CD**: Automating scans, cost estimation, and drift detection

## 🧹 Useful Commands

```bash
# Format all .tf files according to Terraform standards
terraform fmt -recursive

# Validate configuration syntax
terraform validate

# Inspect current state
terraform state list

# See detailed resource information
terraform state show <resource_name>

# Destroy all resources
terraform destroy
```

## ⚠️ Important Notes

### Development Only
- AWS provider uses mock credentials (not real AWS access)
- Vault runs in dev mode (not production-safe)
- S3 bucket and security group are basic examples; production requires additional hardening

### Vault Integration
- Use split stacks to avoid plan-time provider race conditions:
  1) `environments/local/vault` starts Vault
  2) `environments/local/app` writes/reads Vault secrets and starts the app
- Token `dev-token` is hardcoded for dev mode only

### State Management
- Currently uses local state (`.terraform/tfstate`)
- For production: migrate to remote backend (S3, Azure, GCS, etc.)

## 🎓 Learning Resources

- [Terraform Documentation](https://www.terraform.io/docs)
- [Docker Provider](https://registry.terraform.io/providers/kreuzwerker/docker/latest)
- [Vault Provider](https://registry.terraform.io/providers/hashicorp/vault/latest)
- [AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest)
- [Checkov Policies](https://www.checkov.io/5.Custom%20Policies/YAML%20Policies.html)
- [Infracost](https://www.infracost.io/)

## 📄 License

Educational use only.
```
