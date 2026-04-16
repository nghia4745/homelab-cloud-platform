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
│   ├── bootstrap/                 # Stack 0: backend infrastructure (S3 + DynamoDB)
│   ├── local/
│   │   ├── vault/                 # Stack A: local Vault runtime (Docker)
│   │   └── app/                   # Stack B: Vault secrets + nginx app
│   └── dev/                       # Stack C: real AWS dev environment
│       ├── providers.tf           # AWS provider + version constraints
│       ├── backend.tf             # Remote state (S3 + DynamoDB locking)
│       ├── variables.tf           # Environment-level variable declarations
│       ├── main.tf                # Module wiring — networking, IAM, ECR, and EKS
│       ├── outputs.tf             # Re-exports module outputs after apply
│       └── dev.auto.tfvars        # Concrete values (auto-loaded by Terraform)
├── modules/
│   ├── networking/                # VPC, subnets, IGW, NAT, route tables, SGs
│   ├── iam/                       # EKS cluster and node IAM roles + policy attachments
│   ├── ecr/                       # Container image repositories for workloads
│   ├── eks/                       # EKS control plane and managed node group
│   └── s3/                        # Terraform state backend bucket and lock table
├── policies/                      # Custom Checkov security policies
│   └── tagging_policy.yml         # Enforces Owner tag on S3 buckets
├── .github/workflows/             # GitHub Actions CI/CD workflows
│   ├── security-scan.yml          # Runs Checkov security scans
│   ├── infracost.yml              # Estimates infrastructure costs on PRs
│   ├── drift-detection.yml        # Hourly drift detection via Terraform plan
│   └── terraform-docs.yml         # Verifies generated module docs are up to date
├── Makefile                       # Convenience targets for local stacks
├── scripts/
│   └── generate-terraform-docs.sh # Generates module docs in README via terraform-docs
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

### Bootstrap backend environment (run once first)

Create the remote backend infrastructure used by other stacks:
```bash
terraform -chdir=environments/bootstrap init
terraform -chdir=environments/bootstrap plan
terraform -chdir=environments/bootstrap apply
```

This stack creates:
- S3 bucket for remote Terraform state files
- DynamoDB table for state locking

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

The `environments/dev` stack provisions real AWS resources using the `modules/networking`, `modules/iam`, `modules/ecr`, and `modules/eks` modules.

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
- **ECR repositories**: environment-scoped image registries (currently `app` and `worker`) with immutable tags, scan-on-push enabled, and KMS encryption
- **EKS cluster**: one control plane running Kubernetes `1.32` with public and private API endpoint access enabled
- **EKS managed node group**: worker nodes in private subnets using `t3.medium` instances with min/desired/max scaling of `1/2/3`

## 🔐 Configuration

### Variables
Edit `secret.auto.tfvars` to customize:
```hcl
db_password = "your-secure-password-here"
```

> ⚠️ **Security Note**: `secret.auto.tfvars` is auto-loaded and should be git-ignored. Keep sensitive values out of version control.

For AWS dev stack values, edit `environments/dev/dev.auto.tfvars`.
This controls networking, IAM wiring context, ECR repository names, and EKS cluster/node-group sizing.

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

## 📚 Terraform Docs Automation

Module documentation in this README is generated with `terraform-docs`.

Generate docs locally:
```bash
make docs
```

Check docs are up to date (useful in CI):
```bash
make docs-check
```

<!-- BEGIN_TF_DOCS -->

### modules/networking

## Requirements

No requirements.

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | n/a |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [aws_eip.nat](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eip) | resource |
| [aws_internet_gateway.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/internet_gateway) | resource |
| [aws_nat_gateway.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/nat_gateway) | resource |
| [aws_route_table.private](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route_table) | resource |
| [aws_route_table.public](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route_table) | resource |
| [aws_route_table_association.private](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route_table_association) | resource |
| [aws_route_table_association.public](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route_table_association) | resource |
| [aws_security_group.cluster](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |
| [aws_security_group.nodes](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |
| [aws_subnet.private](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/subnet) | resource |
| [aws_subnet.public](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/subnet) | resource |
| [aws_vpc.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_azs"></a> [azs](#input\_azs) | Availability zones to use | `list(string)` | n/a | yes |
| <a name="input_cluster_security_group_ingress_cidrs"></a> [cluster\_security\_group\_ingress\_cidrs](#input\_cluster\_security\_group\_ingress\_cidrs) | CIDRs allowed to reach EKS control plane SG | `list(string)` | <pre>[<br/>  "10.0.0.0/8"<br/>]</pre> | no |
| <a name="input_enable_nat_gateway"></a> [enable\_nat\_gateway](#input\_enable\_nat\_gateway) | Whether to create NAT gateway(s) for private subnet egress | `bool` | `true` | no |
| <a name="input_environment"></a> [environment](#input\_environment) | Environment name (dev, stage, prod) | `string` | n/a | yes |
| <a name="input_node_security_group_ingress_cidrs"></a> [node\_security\_group\_ingress\_cidrs](#input\_node\_security\_group\_ingress\_cidrs) | CIDRs allowed to reach EKS worker nodes SG | `list(string)` | <pre>[<br/>  "10.0.0.0/8"<br/>]</pre> | no |
| <a name="input_private_subnet_cidrs"></a> [private\_subnet\_cidrs](#input\_private\_subnet\_cidrs) | CIDR blocks for private subnets, one per AZ | `list(string)` | n/a | yes |
| <a name="input_project_name"></a> [project\_name](#input\_project\_name) | Project identifier used in naming | `string` | n/a | yes |
| <a name="input_public_subnet_cidrs"></a> [public\_subnet\_cidrs](#input\_public\_subnet\_cidrs) | CIDR blocks for public subnets, one per AZ | `list(string)` | n/a | yes |
| <a name="input_single_nat_gateway"></a> [single\_nat\_gateway](#input\_single\_nat\_gateway) | Use single shared NAT gateway instead of one per AZ | `bool` | `true` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Common tags applied to all networking resources | `map(string)` | `{}` | no |
| <a name="input_vpc_cidr"></a> [vpc\_cidr](#input\_vpc\_cidr) | CIDR block for the VPC | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_cluster_security_group_id"></a> [cluster\_security\_group\_id](#output\_cluster\_security\_group\_id) | ID of the EKS cluster security group |
| <a name="output_node_security_group_id"></a> [node\_security\_group\_id](#output\_node\_security\_group\_id) | ID of the EKS node security group |
| <a name="output_private_subnet_ids"></a> [private\_subnet\_ids](#output\_private\_subnet\_ids) | List of private subnet IDs |
| <a name="output_public_subnet_ids"></a> [public\_subnet\_ids](#output\_public\_subnet\_ids) | List of public subnet IDs |
| <a name="output_vpc_id"></a> [vpc\_id](#output\_vpc\_id) | ID of the VPC |

### modules/iam

## Requirements

No requirements.

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | 6.39.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [aws_iam_role.eks_cluster](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.eks_node](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy_attachment.eks_cluster_amazon_eks_cluster_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.eks_node_amazon_ec2_container_registry_pull_only](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.eks_node_amazon_eks_cni_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.eks_node_amazon_eks_worker_node_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_policy_document.eks_cluster_assume_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.eks_node_assume_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_environment"></a> [environment](#input\_environment) | Environment name (dev, stage, prod) | `string` | n/a | yes |
| <a name="input_project_name"></a> [project\_name](#input\_project\_name) | Project identifier used in naming | `string` | n/a | yes |
| <a name="input_tags"></a> [tags](#input\_tags) | Common tags to apply to IAM resources | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_eks_cluster_role_arn"></a> [eks\_cluster\_role\_arn](#output\_eks\_cluster\_role\_arn) | ARN of the EKS cluster IAM role |
| <a name="output_eks_cluster_role_name"></a> [eks\_cluster\_role\_name](#output\_eks\_cluster\_role\_name) | Name of the EKS cluster IAM role |
| <a name="output_eks_node_role_arn"></a> [eks\_node\_role\_arn](#output\_eks\_node\_role\_arn) | ARN of the EKS worker node IAM role |
| <a name="output_eks_node_role_name"></a> [eks\_node\_role\_name](#output\_eks\_node\_role\_name) | Name of the EKS worker node IAM role |

### modules/ecr

## Requirements

No requirements.

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | n/a |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [aws_ecr_repository.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecr_repository) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_environment"></a> [environment](#input\_environment) | Environment name (dev, stage, prod) | `string` | n/a | yes |
| <a name="input_force_delete"></a> [force\_delete](#input\_force\_delete) | Allow Terraform to delete repositories that still contain images. Safe for dev/test; leave false for production. | `bool` | `false` | no |
| <a name="input_project_name"></a> [project\_name](#input\_project\_name) | Project identifier used in naming | `string` | n/a | yes |
| <a name="input_repository_names"></a> [repository\_names](#input\_repository\_names) | List of ECR repositories, logical repository suffixes to create (example: app, worker) | `list(string)` | n/a | yes |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags to apply to the ECR repositories | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_repository_arns"></a> [repository\_arns](#output\_repository\_arns) | ARNs of the ECR repositories |
| <a name="output_repository_names"></a> [repository\_names](#output\_repository\_names) | Names of the ECR repositories |
| <a name="output_repository_urls"></a> [repository\_urls](#output\_repository\_urls) | Repository URLs used for docker push and pull |

### modules/eks

## Requirements

No requirements.

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | n/a |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [aws_eks_cluster.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eks_cluster) | resource |
| [aws_eks_node_group.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eks_node_group) | resource |
| [aws_kms_alias.cluster_encryption](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/kms_alias) | resource |
| [aws_kms_key.cluster_encryption](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/kms_key) | resource |
| [aws_kms_key_policy.cluster_encryption](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/kms_key_policy) | resource |
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_cluster_name"></a> [cluster\_name](#input\_cluster\_name) | EKS cluster name. If empty, module builds one from project and environment | `string` | `""` | no |
| <a name="input_cluster_role_arn"></a> [cluster\_role\_arn](#input\_cluster\_role\_arn) | IAM role ARN used by the EKS control plane | `string` | n/a | yes |
| <a name="input_cluster_security_group_id"></a> [cluster\_security\_group\_id](#input\_cluster\_security\_group\_id) | Security group ID attached to the EKS control plane | `string` | n/a | yes |
| <a name="input_cluster_version"></a> [cluster\_version](#input\_cluster\_version) | Kubernetes version for the EKS control plane | `string` | `"1.32"` | no |
| <a name="input_enabled_cluster_log_types"></a> [enabled\_cluster\_log\_types](#input\_enabled\_cluster\_log\_types) | EKS control plane log types to enable | `list(string)` | <pre>[<br/>  "api",<br/>  "audit",<br/>  "authenticator",<br/>  "controllerManager",<br/>  "scheduler"<br/>]</pre> | no |
| <a name="input_endpoint_private_access"></a> [endpoint\_private\_access](#input\_endpoint\_private\_access) | Whether the EKS API endpoint is accessible from within the VPC | `bool` | `true` | no |
| <a name="input_endpoint_public_access"></a> [endpoint\_public\_access](#input\_endpoint\_public\_access) | Whether the EKS API endpoint is publicly accessible | `bool` | `false` | no |
| <a name="input_environment"></a> [environment](#input\_environment) | Environment name (dev, stage, prod) | `string` | n/a | yes |
| <a name="input_node_capacity_type"></a> [node\_capacity\_type](#input\_node\_capacity\_type) | Node capacity type: ON\_DEMAND or SPOT | `string` | `"ON_DEMAND"` | no |
| <a name="input_node_desired_size"></a> [node\_desired\_size](#input\_node\_desired\_size) | Desired number of worker nodes | `number` | `2` | no |
| <a name="input_node_disk_size"></a> [node\_disk\_size](#input\_node\_disk\_size) | Disk size in GiB for each node | `number` | `20` | no |
| <a name="input_node_group_name"></a> [node\_group\_name](#input\_node\_group\_name) | Managed node group name. If empty, module builds one from project and environment | `string` | `""` | no |
| <a name="input_node_instance_types"></a> [node\_instance\_types](#input\_node\_instance\_types) | EC2 instance types for worker nodes | `list(string)` | <pre>[<br/>  "t3.medium"<br/>]</pre> | no |
| <a name="input_node_max_size"></a> [node\_max\_size](#input\_node\_max\_size) | Maximum number of worker nodes | `number` | `3` | no |
| <a name="input_node_min_size"></a> [node\_min\_size](#input\_node\_min\_size) | Minimum number of worker nodes | `number` | `1` | no |
| <a name="input_node_role_arn"></a> [node\_role\_arn](#input\_node\_role\_arn) | IAM role ARN used by EKS worker nodes | `string` | n/a | yes |
| <a name="input_node_security_group_id"></a> [node\_security\_group\_id](#input\_node\_security\_group\_id) | Security group ID attached to EKS worker nodes via launch template | `string` | n/a | yes |
| <a name="input_private_subnet_ids"></a> [private\_subnet\_ids](#input\_private\_subnet\_ids) | Private subnet IDs where EKS control plane and node groups run | `list(string)` | n/a | yes |
| <a name="input_project_name"></a> [project\_name](#input\_project\_name) | Project identifier used in naming | `string` | n/a | yes |
| <a name="input_public_access_cidrs"></a> [public\_access\_cidrs](#input\_public\_access\_cidrs) | CIDR blocks allowed to reach the public EKS API endpoint | `list(string)` | `[]` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Common tags to apply to EKS resources | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_cluster_arn"></a> [cluster\_arn](#output\_cluster\_arn) | EKS cluster ARN |
| <a name="output_cluster_certificate_authority_data"></a> [cluster\_certificate\_authority\_data](#output\_cluster\_certificate\_authority\_data) | Base64-encoded certificate authority data for the cluster |
| <a name="output_cluster_endpoint"></a> [cluster\_endpoint](#output\_cluster\_endpoint) | EKS cluster API endpoint URL |
| <a name="output_cluster_id"></a> [cluster\_id](#output\_cluster\_id) | EKS cluster ID (same as cluster name) |
| <a name="output_cluster_version"></a> [cluster\_version](#output\_cluster\_version) | Kubernetes version running on the cluster |
| <a name="output_node_group_arn"></a> [node\_group\_arn](#output\_node\_group\_arn) | EKS node group ARN |
| <a name="output_node_group_id"></a> [node\_group\_id](#output\_node\_group\_id) | EKS node group ID |
| <a name="output_node_group_status"></a> [node\_group\_status](#output\_node\_group\_status) | Status of the EKS node group (CREATING, ACTIVE, DELETING, FAILED, UPDATING, PENDING) |

### modules/s3

## Requirements

No requirements.

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | n/a |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [aws_dynamodb_table.lock](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/dynamodb_table) | resource |
| [aws_kms_alias.dynamodb](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/kms_alias) | resource |
| [aws_kms_key.dynamodb](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/kms_key) | resource |
| [aws_s3_bucket.state](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket) | resource |
| [aws_s3_bucket_policy.state_tls_only](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_policy) | resource |
| [aws_s3_bucket_public_access_block.state](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_public_access_block) | resource |
| [aws_s3_bucket_server_side_encryption_configuration.state](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_server_side_encryption_configuration) | resource |
| [aws_s3_bucket_versioning.state](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_versioning) | resource |
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |
| [aws_iam_policy_document.state_tls_only](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_region.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_bucket_name"></a> [bucket\_name](#input\_bucket\_name) | Optional explicit S3 bucket name for Terraform state. Leave empty to auto-generate. | `string` | `""` | no |
| <a name="input_dynamodb_kms_key_arn"></a> [dynamodb\_kms\_key\_arn](#input\_dynamodb\_kms\_key\_arn) | Optional existing CMK ARN for DynamoDB table encryption. Leave empty to create one in this module. | `string` | `""` | no |
| <a name="input_dynamodb_table_name"></a> [dynamodb\_table\_name](#input\_dynamodb\_table\_name) | Optional explicit DynamoDB table name for state locking. Leave empty to auto-generate. | `string` | `""` | no |
| <a name="input_environment"></a> [environment](#input\_environment) | Environment or stack name (for example: bootstrap, dev, prod) | `string` | n/a | yes |
| <a name="input_force_destroy"></a> [force\_destroy](#input\_force\_destroy) | Allow bucket/table destruction during Terraform destroy (useful for learning env) | `bool` | `false` | no |
| <a name="input_project_name"></a> [project\_name](#input\_project\_name) | Project identifier used in naming | `string` | n/a | yes |
| <a name="input_tags"></a> [tags](#input\_tags) | Common tags to apply to resources | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_dynamodb_kms_key_arn"></a> [dynamodb\_kms\_key\_arn](#output\_dynamodb\_kms\_key\_arn) | ARN of the CMK used for DynamoDB table encryption |
| <a name="output_dynamodb_table_arn"></a> [dynamodb\_table\_arn](#output\_dynamodb\_table\_arn) | ARN of the DynamoDB table used for Terraform state locking |
| <a name="output_dynamodb_table_name"></a> [dynamodb\_table\_name](#output\_dynamodb\_table\_name) | Name of the DynamoDB table used for Terraform state locking |
| <a name="output_state_bucket_arn"></a> [state\_bucket\_arn](#output\_state\_bucket\_arn) | ARN of the S3 bucket used for Terraform state |
| <a name="output_state_bucket_name"></a> [state\_bucket\_name](#output\_state\_bucket\_name) | Name of the S3 bucket used for Terraform state |

<!-- END_TF_DOCS -->

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

What to remember about the design:
- Repository names are generated with a `project-environment` prefix for consistency across modules.
- `for_each = toset(var.repository_names)` creates one independent Terraform object per repo name, so references stay stable.
- `force_delete = true` is intentionally set for learning and dev workflows to make `terraform destroy` reliable even when images exist.
- Outputs are maps keyed by logical repository names, which makes downstream usage predictable.

Module structure reminders:
- `variables.tf` defines naming context, repository list, scanning behavior, and shared tags.
- `main.tf` creates repositories and applies consistent tags.
- `outputs.tf` exposes names, ARNs, and repository URLs for consumers.

Implementation choices made during the exercise:
- Repository outputs are exposed as maps rather than lists to avoid order-coupling and simplify module consumers.

## ☸️ EKS Module Notes

The `modules/eks` module provisions the Kubernetes control plane and a managed worker node group on top of the networking and IAM modules.

What it creates:
- One EKS cluster control plane.
- One EKS managed node group.
- API endpoint access configuration for public/private connectivity.

What to remember about the design:
- The EKS module does not create its own VPC or IAM roles. It consumes private subnet IDs, security group IDs, and IAM role ARNs from other modules.
- `aws_eks_cluster` and `aws_eks_node_group` are separate resources with different lifecycles. The control plane can stay stable while nodes scale or roll.
- Managed node groups let AWS handle EC2 instance lifecycle tasks like joining nodes to the cluster and replacing unhealthy instances.
- The module uses private subnets for nodes so worker instances are not directly internet-facing.

Module structure reminders:
- `variables.tf` defines cluster settings, endpoint access rules, node group sizing, and dependency inputs from networking/IAM.
- `main.tf` creates the cluster and managed node group, with locals used for consistent names and tags.
- `outputs.tf` exposes cluster connection details such as endpoint, certificate authority data, and node group status.

Implementation choices made during the exercise:
- Cluster and node group names default to the `project-environment` pattern but can be overridden if needed.
- The module uses managed node groups instead of self-managed autoscaling groups to keep the learning path focused on core EKS concepts.
- `max_unavailable = 1` keeps rolling node updates conservative so only one worker is drained at a time.

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
- The **local** stacks (`environments/local/`) run Docker containers locally but **do** require AWS credentials because their Terraform state is stored in the same S3 remote backend as the dev stack.
- The **dev** stack (`environments/dev/`) uses real AWS credentials and creates real AWS resources. Check your AWS account for billable resources before running `apply`.
- Vault runs in dev mode (not production-safe); tokens and secrets are ephemeral and lost on container restart.
- The dev stack currently disables NAT gateways (`enable_nat_gateway = false`) to minimise cost. Private subnets have no outbound internet until NAT is re-enabled.

### Vault Integration
- Use split stacks to avoid plan-time provider race conditions:
  1) `environments/local/vault` starts Vault
  2) `environments/local/app` writes/reads Vault secrets and starts the app
- Token `dev-token` is hardcoded for dev mode only

### State Management
- All stacks (**local** and **dev**) use the same S3 remote backend (`nghia-homelab-tfstate-2026`) with DynamoDB state locking (`nghia-homelab-tfstate-lock`). Each stack writes to a unique key (`dev/homelab.tfstate`, `local/local-vault.tfstate`, `local/local-app.tfstate`, etc.) so multiple stacks can share the same bucket without colliding.

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
