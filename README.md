```markdown
# Terraform DevOps Learning Project
![Security Scan](https://github.com/nghia4745/homelab-cloud-platform/actions/workflows/security-scan.yml/badge.svg)

A hands-on Terraform project demonstrating infrastructure-as-code concepts with Docker, Vault secret management, AWS resources, custom security policies, and CI/CD automation.

## 📋 Prerequisites

- Terraform >= 1.14.0
- Docker (running locally)
- HashiCorp Vault (started via Terraform)
- AWS credentials configured (`~/.aws/credentials` or environment variables) for real AWS resource provisioning
- Checkov (for custom security policies)
- Infracost (for cost estimation, optional for CI/CD)

## 🏗️ Project Structure

```
.
├── environments/
│   ├── local/
│   │   ├── vault/                 # Stack A: local Vault runtime (Docker)
│   │   └── app/                   # Stack B: Vault secrets + nginx app
│   └── dev/                       # Stack C: real AWS dev environment
│       ├── providers.tf           # AWS provider + version constraints
│       ├── backend.tf             # Remote state (S3 + DynamoDB locking)
│       ├── variables.tf           # Environment-level variable declarations
│       ├── main.tf                # Module wiring — networking and IAM
│       ├── outputs.tf             # Re-exports module outputs after apply
│       └── dev.auto.tfvars        # Concrete values (auto-loaded by Terraform)
├── modules/
│   ├── networking/                # VPC, subnets, IGW, NAT, route tables, SGs
│   ├── iam/                       # EKS cluster and node IAM roles + policy attachments
│   ├── ecr/                       # (planned) container image registry
│   └── eks/                       # (planned) EKS cluster and node groups
├── policies/                      # Custom Checkov security policies
│   └── tagging_policy.yml         # Enforces Owner tag on S3 buckets
├── .github/workflows/             # GitHub Actions CI/CD workflows
│   ├── security-scan.yml          # Runs Checkov security scans
│   ├── infracost.yml              # Estimates infrastructure costs on PRs
│   └── drift-detection.yml        # Hourly drift detection via Terraform plan
├── Makefile                       # Convenience targets for local stacks
└── README.md                      # This file
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

### Dev environment (real AWS)

Ensure AWS credentials are configured, then:
```bash
terraform -chdir=environments/dev init
terraform -chdir=environments/dev plan
terraform -chdir=environments/dev apply
```

> ⚠️ This creates real AWS resources that may incur charges. Review the plan output before confirming.

To clean up:
```bash
terraform -chdir=environments/dev destroy
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

### AWS Resources (Dev Environment)

The `environments/dev` stack provisions real AWS resources using the `modules/networking` and `modules/iam` modules.

- **VPC**: `10.0.0.0/16` with DNS hostname support enabled
- **Public subnets**: one per AZ across `us-east-1a` and `us-east-1b` (for load balancers and internet-facing traffic)
- **Private subnets**: one per AZ across `us-east-1a` and `us-east-1b` (for EKS worker nodes)
- **Internet Gateway**: attached to the VPC for public subnet outbound routing
- **Route tables**: separate public and private route tables with explicit subnet associations
- **Security groups**:
  - Cluster SG: ingress port 443 (EKS control plane API), egress TCP 0–65535 to node CIDR
  - Node SG: ingress TCP 0–65535 (ephemeral ports for workload response traffic)
- **IAM role — EKS cluster**: trusted by `eks.amazonaws.com`, attached `AmazonEKSClusterPolicy`
- **IAM role — EKS nodes**: trusted by `ec2.amazonaws.com`, attached `AmazonEKSWorkerNodePolicy`, `AmazonEC2ContainerRegistryReadOnly`, `AmazonEKS_CNI_Policy`

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
- **Data Sources**: Reading existing Vault secrets and generating IAM policy JSON via `aws_iam_policy_document`
- **Dependencies**: Explicit `depends_on` for sequencing resource creation
- **Variables**: Sensitive input variables for credentials
- **Interpolation**: Referencing resource outputs and data source values
- **Custom Policies**: Writing and applying Checkov security checks
- **CI/CD**: Automating scans, cost estimation, and drift detection
- **Modules**: Reusable, self-contained infrastructure units with a variables / main / outputs contract
- **`locals`**: Internal helper values that keep logic DRY without exposing extra variables to callers
- **`for_each` and `count`**: Creating multiple similar resources from a single block
- **`dynamic` blocks**: Conditionally including nested resource arguments (e.g. NAT routes only when NAT is enabled)
- **`merge()` and `zipmap()`**: Combining tag maps and building maps from parallel key/value lists
- **Remote state**: S3 backend with DynamoDB state locking for safe concurrent operations
- **Split-stack architecture**: Separate Terraform stacks that avoid provider dependency cycles by running independently

## 🌐 Networking Module Notes

The `modules/networking` module was built as a learning exercise to turn Terraform inputs into a reusable AWS network foundation for EKS.

What it creates:
- A VPC with DNS support enabled.
- Public and private subnets across multiple Availability Zones.
- An Internet Gateway for public internet routing.
- Optional NAT Gateway infrastructure so private subnets can reach the internet without becoming publicly addressable.
- Public and private route tables with subnet associations.
- EKS-oriented security groups for the cluster control plane and worker nodes.

What to remember about the design:
- `variables.tf` defines the module contract. These are the values the caller must provide, such as CIDR ranges and AZs.
- `main.tf` contains the implementation. All resources in the same module directory share one Terraform namespace, so resources, locals, and variables can reference one another directly.
- `outputs.tf` defines the module's public API. Other modules do not see internal resources unless they are exposed as outputs.
- `locals` are internal helper values, not caller inputs. They were used here to keep naming and tagging consistent and to avoid repeating the NAT gateway count logic.
- `merge()` was used for tags so module-wide defaults can be reused everywhere, while resource-specific tags like `Name` can override or extend those defaults.

Networking concepts captured in this module:
- A subnet is "public" because its route table sends `0.0.0.0/0` to an Internet Gateway, not because every resource in it gets a public IP.
- Private subnets are kept private by avoiding direct internet routing; when NAT is enabled, they get outbound internet access through the NAT Gateway instead.
- Ingress means traffic coming into a resource; egress means traffic leaving a resource.
- TCP port ranges matter in security groups. Port `443` is a precise service port, while `0-65535` means the full TCP range, including ephemeral ports used for response traffic and dynamic workloads.
- CIDR blocks define IP ranges. The VPC CIDR is the full address space, and subnet CIDRs are smaller, non-overlapping slices inside it.

Implementation choices made during the exercise:
- Public subnets do not auto-assign public IPs by default. That keeps internet exposure explicit at the workload level instead of implicit at the subnet level.
- The NAT gateway count is driven by a local expression so the module can support either a single shared NAT for lower cost or one NAT per AZ for stronger availability.
- Security group rules were tightened after Checkov feedback so the defaults are less permissive and easier to reason about.

## 🔐 IAM Module Notes

The `modules/iam` module was built to provide the AWS identities required by EKS.

What it creates:
- One IAM role for the EKS control plane.
- One IAM role for EKS worker nodes.
- AWS-managed policy attachments for cluster management, worker node operations, image pulls from ECR, and CNI networking.

What to remember about the design:
- IAM roles have two separate concerns:
  - Trust policy: who is allowed to assume the role.
  - Permission policies: what that role is allowed to do after assumption.
- In Terraform, `aws_iam_policy_document` is used to generate trust policy JSON safely instead of embedding raw JSON strings.
- The EKS cluster role trusts `eks.amazonaws.com` because the control plane service assumes it.
- The EKS node role trusts `ec2.amazonaws.com` because worker nodes are EC2 instances.
- AWS-managed policies were used first because they are the fastest safe path to a working baseline; custom policies can come later when permissions need to be narrowed.

Module structure reminders:
- `variables.tf` defines the IAM module inputs: project naming, environment scoping, and tags.
- `main.tf` builds the trust policies, roles, and policy attachments.
- `outputs.tf` exposes names and ARNs so other modules can consume the roles without depending on IAM internals.

Implementation choices made during the exercise:
- Naming follows the same `project-environment` prefix pattern as the networking module so resources are easy to trace in AWS.
- Tags are merged through locals for consistency and to avoid repeating metadata on every role.
- Both role names and ARNs are output because downstream modules often need ARNs for resource arguments, while names are still useful for inspection and debugging.

## 📦 ECR Module Notes

The `modules/ecr` module provides a reusable pattern for container image repositories.

What it creates:
- One ECR repository per logical name in `repository_names`.
- Optional image scanning on push.
- Caller-controlled tag mutability (`MUTABLE` or `IMMUTABLE`).

What to remember about the design:
- Repository names are generated with a `project-environment` prefix for consistency across modules.
- `for_each = toset(var.repository_names)` creates one independent Terraform object per repo name, so references stay stable.
- `force_delete = true` is intentionally set for learning and dev workflows to make `terraform destroy` reliable even when images exist.
- Outputs are maps keyed by logical repository names, which makes downstream usage predictable.

Module structure reminders:
- `variables.tf` defines naming context, repository list, scanning behavior, tag mutability, and shared tags.
- `main.tf` creates repositories and applies consistent tags.
- `outputs.tf` exposes names, ARNs, and repository URLs for consumers.

Implementation choices made during the exercise:
- Default `image_tag_mutability` is `MUTABLE`, which is practical for iterative development and frequent image pushes.
- Default `scan_on_push` is `false` to keep behavior simple by default; it can be enabled per environment.
- Repository outputs are exposed as maps rather than lists to avoid order-coupling and simplify module consumers.

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
- The **local** stacks (`environments/local/`) are Docker-only and do not touch AWS.
- The **dev** stack (`environments/dev/`) uses real AWS credentials and creates real AWS resources. Check your AWS account for billable resources before running `apply`.
- Vault runs in dev mode (not production-safe); tokens and secrets are ephemeral and lost on container restart.
- The dev stack currently disables NAT gateways (`enable_nat_gateway = false`) to minimise cost. Private subnets have no outbound internet until NAT is re-enabled.

### Vault Integration
- Use split stacks to avoid plan-time provider race conditions:
  1) `environments/local/vault` starts Vault
  2) `environments/local/app` writes/reads Vault secrets and starts the app
- Token `dev-token` is hardcoded for dev mode only

### State Management
- The **local** stacks use local state files stored under `.terraform/` within each stack directory.
- The **dev** stack uses an S3 remote backend (`nghia-homelab-tfstate-2026`) with DynamoDB state locking (`nghia-homelab-tfstate-lock`). Each stack writes to a unique key (`dev/homelab.tfstate`, `local/vault/local-vault.tfstate`, etc.) so multiple stacks can share the same bucket without colliding.

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
