# Terraform DevOps Learning Project
# ![Security Scan](https://github.com/nghia4745/learn-terraform/actions/workflows/security-scan.yml/badge.svg) TODO: revisit badge after adding CI
A hands-on Terraform project demonstrating infrastructure-as-code concepts with Docker, Vault secret management, and AWS resources.

## 📋 Prerequisites

- Terraform >= 1.14.0
- Docker (running locally)
- HashiCorp Vault (started via Terraform)
- AWS credentials (for mock AWS resources)

## 🏗️ Project Structure

```
.
├── providers.tf           # Terraform settings & provider configurations
├── main.tf                # Docker nginx application resources
├── vault_docker.tf        # Docker Vault server resources
├── vault.tf              # Vault secret management (KV V2)
├── variables.tf          # Input variable definitions
├── security.tf           # AWS security group resources
├── vulnerable_aws.tf     # AWS S3 bucket resources (intentionally insecure for learning)
├── secret.auto.tfvars    # Sensitive variables (auto-loaded, git-ignored)
└── README.md             # This file
```

## 🚀 Quick Start

### 1. Initialize Terraform
```bash
terraform init
```
Downloads provider plugins and sets up the `.terraform/` directory.

### 2. Plan the deployment
```bash
terraform plan
```
The `secret.auto.tfvars` file is automatically loaded, so no `-var-file` needed.

### 3. Apply configuration
```bash
terraform apply
```
Creates Docker containers for Vault, nginx, and AWS resources.

### 4. Verify resources
```bash
# Check running Docker containers
docker ps

# Check Vault is running on port 8200
curl http://localhost:8200/v1/sys/health

# Check nginx is running on port 8080
curl http://localhost:8080
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
- **S3 Bucket**: `my-insecure-data-bucket-2026` (intentionally misconfigured for learning)
- **Security Group**: Allows all inbound traffic (intentionally insecure for learning)

## 🔐 Configuration

### Variables
Edit `secret.auto.tfvars` to customize:
```hcl
db_password = "your-secure-password-here"
```

> ⚠️ **Security Note**: `secret.auto.tfvars` is auto-loaded and should be git-ignored. Keep sensitive values out of version control.

## 📝 Key Terraform Concepts Demonstrated

- **Providers**: Docker, Vault, and AWS plugin configuration
- **Resources**: Creating and managing infrastructure objects
- **Data Sources**: Reading existing Vault secrets
- **Dependencies**: Explicit `depends_on` for sequencing resource creation
- **Variables**: Sensitive input variables for credentials
- **Interpolation**: Referencing resource outputs and data source values

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
- Security group allows all traffic (intentionally insecure for learning)

### Vault Integration
- Vault container must start before secrets can be written
- Terraform handles dependency ordering with `depends_on`
- Token `dev-token` is hardcoded for dev mode only

### State Management
- Currently uses local state (`.terraform/tfstate`)
- For production: migrate to remote backend (S3, Azure, GCS, etc.)

## 🎓 Learning Resources

- [Terraform Documentation](https://www.terraform.io/docs)
- [Docker Provider](https://registry.terraform.io/providers/kreuzwerker/docker/latest)
- [Vault Provider](https://registry.terraform.io/providers/hashicorp/vault/latest)
- [AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest)

## 🔄 Next Steps

Phase 2: Local CI/CD & Static Analysis (Current Focus)
- [ ] Automate Security Scanning: Integrate Checkov or Trivy into a local workflow to catch the vulnerabilities in vulnerable_aws.tf.

- [ ] GitHub Actions Integration: Create a .github/workflows/main.yml to run terraform validate and security scans on every push.

- [ ] The Logic Test: Script a secret rotation in Vault and verify that Terraform successfully updates the Nginx container's environment.

- [ ] Local Runner Setup: Configure a GitHub Actions self-hosted runner on the homelab server to execute builds locally.

Phase 3: The Cloud Bridge
- [ ] Remote State Migration: Move the local terraform.tfstate to an encrypted S3 bucket with state locking.

- [ ] Infrastructure "Clean Up": Resolve the security flags in vulnerable_aws.tf and perform a first "clean" deploy to a real cloud provider.

- [ ] Cloud Budgeting: Set up AWS/GCP budget alerts ($5 threshold) to prevent unexpected costs.

Phase 4: Advanced Governance
- [ ] Policy as Code: Implement Open Policy Agent (OPA) or Kyverno to enforce custom tagging and resource standards.

- [ ] Observability Stack: Deploy Prometheus and Grafana to monitor the health of the "Cloud Bridge" infrastructure.

## 📄 License

Educational use only.
