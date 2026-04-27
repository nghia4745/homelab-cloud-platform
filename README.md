# Terraform DevOps Learning Project
![Security Scan](https://github.com/nghia4745/homelab-cloud-platform/actions/workflows/security-scan.yaml/badge.svg)

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
│   └── tagging_policy.yaml        # Enforces Owner tag on S3 buckets
├── .github/workflows/             # GitHub Actions CI/CD workflows
│   ├── security-scan.yaml         # Runs Checkov security scans
│   ├── infracost.yaml             # Estimates infrastructure costs on PRs
│   ├── drift-detection.yaml       # Hourly drift detection via Terraform plan
│   ├── build-and-push.yaml        # Builds, scans, and pushes container to GHCR
│   └── integration-test.yaml      # Runs Kind-based Kubernetes integration tests
├── app/                           # Phase 3 sample Flask API
│   ├── main.py                    # /health, /api/greeting, /metrics endpoints
│   └── requirements.txt           # Python runtime dependencies
├── charts/                        # Phase 5: Helm chart for templated deployments
│   └── homelab-api/               # Main application chart
│       ├── Chart.yaml             # Chart metadata and versioning
│       ├── values.yaml            # Base default values
│       ├── values-dev.yaml        # Development environment overrides (2 replicas, info logging)
│       ├── values-prod.yaml       # Production environment overrides (3+ replicas, warning logging)
│       ├── _helpers.tpl           # Named templates for reusable Helm functions
│       └── templates/             # Kubernetes manifest templates
│           ├── configmap.yaml     # ConfigMap template with APP_ENV, LOG_LEVEL
│           ├── deployment.yaml    # Deployment template with probes, resources, image pull
│           ├── service.yaml       # Service template (ClusterIP for Ingress backend)
│           ├── ingress.yaml       # Ingress template for HTTP routing
│           └── hpa.yaml           # HorizontalPodAutoscaler template for auto-scaling
├── kind/
│   └── cluster.yaml               # Kind cluster definition and local port mapping
├── k8s/
│   ├── namespaces/                # Phase 5: Namespace definitions
│   │   ├── app.yaml               # Workload namespace for homelab-api
│   │   ├── dev.yaml               # Staging/development namespace
│   │   └── monitoring.yaml        # Reserved for Phase 6 observability stack
│   ├── networkpolicy.yaml         # Phase 5: Zero-trust network policies
├── Dockerfile                     # Multi-stage container build for app/
├── .dockerignore                  # Excludes unnecessary files from Docker build context
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

### Bootstrap backend environment (run once first)

Create the remote backend infrastructure used by stacks that use the S3 backend:
```bash
terraform -chdir=environments/bootstrap init
terraform -chdir=environments/bootstrap plan
terraform -chdir=environments/bootstrap apply
```

This stack creates:
- S3 bucket for remote Terraform state files
- DynamoDB table for state locking

After apply, wire these output values into each environment `backend.tf`:
```bash
terraform -chdir=environments/bootstrap output state_bucket_name
terraform -chdir=environments/bootstrap output dynamodb_table_name
```

Update backend blocks (for example `environments/dev/backend.tf`) so `bucket` and
`dynamodb_table` match the bootstrap outputs.
```hcl
backend "s3" {
  bucket         = "<state_bucket_name output>"
  key            = "dev/homelab.tfstate"
  dynamodb_table = "<dynamodb_table_name output>"
  region         = "us-east-1"
  encrypt        = true
}
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

## 🐳 Phase 3: Application + Containerization

The project now includes a minimal Flask API and a production-oriented container image build.

### What was added

- `app/main.py`
  - `GET /health`: service health endpoint for container/Kubernetes probes
  - `GET /api/greeting`: simple API response
  - `GET /metrics`: Prometheus-compatible metrics output
  - Custom metric `app_requests_total` labeled by endpoint
- `app/requirements.txt`
  - `flask`, `prometheus-client`, and `gunicorn` are pinned for reproducible builds
- `Dockerfile`
  - Multi-stage build (`builder` -> `runtime`)
  - Runs as non-root user (`appuser`) for safer defaults
  - Exposes container port `8080`
  - Starts app with Gunicorn (`main:app`) instead of Flask dev server

### Why this design

- Multi-stage build keeps runtime image smaller and cleaner.
- Gunicorn is the production WSGI server; Flask dev server is for local dev only.
- `/metrics` makes the app ready for Prometheus/Grafana in a later observability phase.
- Endpoint-level counters validate traffic flow quickly during testing.

### Run the app locally (without Docker)

```bash
cd app
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
python main.py
```

In another terminal:

```bash
curl http://localhost:8080/health
curl http://localhost:8080/api/greeting
curl http://localhost:8080/metrics
```

### Build and run container locally

```bash
docker build -t homelab-api:v1 .
docker run --rm -p 8080:8080 homelab-api:v1
```

Then verify:

```bash
curl http://localhost:8080/health
curl http://localhost:8080/api/greeting
curl http://localhost:8080/metrics
```

### Push to GitHub Container Registry (GHCR)

#### Manual push (one-time verification)

1. Create a GitHub Personal Access Token with `write:packages` scope:
   - Go to https://github.com/settings/tokens
   - Click "Generate new token (classic)"
   - Select scopes: `write:packages`, `read:packages`, `delete:packages`
   - Copy the token

2. Login to GHCR:
   ```bash
   export GITHUB_TOKEN=<your-token>
   echo $GITHUB_TOKEN | docker login ghcr.io -u <your-github-username> --password-stdin
   ```

3. Tag and push:
   ```bash
   export IMAGE_TAG=sha-$(git rev-parse --short=12 HEAD)
   docker tag homelab-api:v1 ghcr.io/nghia4745/homelab-api:$IMAGE_TAG
   docker tag homelab-api:v1 ghcr.io/nghia4745/homelab-api:latest
   docker push ghcr.io/nghia4745/homelab-api:$IMAGE_TAG
   docker push ghcr.io/nghia4745/homelab-api:latest
   ```

4. Verify in GitHub:
   - Visit https://github.com/nghia4745?tab=packages
   - Confirm `homelab-api` package appears with the SHA tag

#### Automated push via GitHub Actions

The `.github/workflows/build-and-push.yaml` workflow automates this process:

- **Runs on**: Self-hosted runner (requires Docker and Buildx available locally)
- **On PR (same repository)**: Builds image and runs Trivy vulnerability scan (no push)
- **On PR from forks**: Job is skipped by guardrail to avoid restricted-token permission failures
- **On push to main/dev**: Builds image, scans with Trivy, pushes both `sha-<short-commit>` and `latest` tags to GHCR

The workflow:
- Uses `docker/setup-buildx-action` for multi-stage build caching
- Runs `aquasecurity/trivy-action` to scan for container vulnerabilities
- Uploads results to GitHub Security tab via `github/codeql-action/upload-sarif`
- Authenticates with `secrets.GITHUB_TOKEN` (built-in, no secrets setup needed)
- Requires these repository permissions:
  - `contents: read`
  - `packages: write`
  - `security-events: write`
  - `actions: read`

**Important**: After the workflow creates the GHCR package, you must grant repository access:

1. Go to your GitHub packages: https://github.com/nghia4745?tab=packages
2. Click the `homelab-api` package
3. Click **Package settings**
4. Under **Manage Actions access**, add repository `nghia4745/homelab-cloud-platform`
5. Enable "Inherit access from repository" if available

Also ensure your repository has workflow permissions enabled:
- Repository → Settings → Actions → General
- Set **Workflow permissions** to `Read and write permissions`

To trigger a push, commit and push to main or dev branch:
```bash
git add .
git commit -m "Phase 3: Containerization and GHCR push"
git push origin dev
```

The workflow will automatically build, scan, and push to GHCR.

## ☸️ Phase 4: Kubernetes Deployment on Kind

Phase 4 established the core Kubernetes architecture on Kind (Pods, Service, Ingress, HPA, and CI validation). The original raw manifests were intentionally removed during Phase 5 cleanup, and deployment now continues via Helm templates.

### What was added

- `kind/cluster.yaml`
  - Defines a two-node Kind cluster (`control-plane` + `worker`)
  - Maps host port `8080` to ingress-nginx NodePort `30080` for local access
- `charts/homelab-api/templates/*`
  - Replaces raw manifests with reusable Helm templates
  - Keeps Deployment/Service/Ingress/HPA/ConfigMap in a single chart
- `k8s/namespaces/app.yaml`
  - Creates the active application namespace
- `ingress-nginx` controller (installed via Helm)
  - Terminates incoming HTTP and forwards traffic to Service `homelab-api`
- `.github/workflows/integration-test.yaml`
  - Creates ephemeral Kind cluster in CI
  - Deploys Helm release and validates `/health`, `/api/greeting`, and `/metrics`

### Prerequisites

**1. Create the Kind cluster**

```bash
kind create cluster --config kind/cluster.yaml
```

**2. Create the `app` namespace**

```bash
kubectl apply -f k8s/namespaces/app.yaml
```

**3. Create the GHCR pull secret**

Required to pull the private image from GHCR:

```bash
kubectl create secret docker-registry ghcr-pull-secret \
  --namespace app \
  --docker-server=ghcr.io \
  --docker-username=<github-username> \
  --docker-password=<github-personal-access-token-with-read:packages> \
  --docker-email=<email>
```

### Apply and verify

```bash
# Deploy/update with Helm chart
helm upgrade --install homelab-api-app charts/homelab-api \
  --namespace app \
  --values charts/homelab-api/values-dev.yaml

# Check rollout and resources
kubectl -n app rollout status deployment/homelab-api-app
kubectl -n app get deploy,pods,svc,ingress,hpa

# Verify ingress controller status
kubectl -n ingress-nginx get deploy,svc,pods

# Verify app endpoints through Kind port mapping
curl http://localhost:8080/health
curl http://localhost:8080/api/greeting
curl http://localhost:8080/metrics
```

### Notes

- `kubectl get hpa` may show `cpu: <unknown>/60%` in Kind until metrics-server is installed.
- With the current setup, application traffic path is:
  `localhost:8080 -> kind control-plane:30080 -> ingress-nginx -> Service:80 -> Pod:8080`

#### Build context optimization

The `.dockerignore` file excludes unnecessary files from the Docker build context, reducing build time and image size:

```
.git
.gitignore
.github
.terraform
.venv
.vscode
terraform.tfstate*
*.tfvars
README.md
modules/
environments/
policies/
```

Only `app/`, `Dockerfile`, and required config files are included in the build context.

## 🎯 Phase 5: Helm + Advanced Kubernetes

Building on the foundational Kubernetes skills from Phase 4, Phase 5 introduces **Helm templating** for production-grade deployments and **advanced networking** with NetworkPolicy and namespace isolation.

### What was added

**Helm Chart Structure** (`charts/homelab-api/`)
- Purpose: Templated deployment system that replaces raw manifests, enabling environment-specific configuration (dev vs prod)
- Chart metadata: `Chart.yaml` defines versioning and chart identity
- Base templates: `deployment.yaml`, `service.yaml`, `ingress.yaml`, `hpa.yaml`, `configmap.yaml` with Helm templating syntax
- Helper functions: `_helpers.tpl` centralizes naming patterns (prevents duplication)
- Values files:
  - `values.yaml`: Base defaults for all deployments
  - `values-dev.yaml`: Local Kind cluster optimization (2 replicas, info logging, 60% CPU, minimal resources)
  - `values-prod.yaml`: High-availability settings (3-8 replicas, warning logging, 50% CPU, higher resource requests)

**Namespace & Network Structure** (`k8s/namespaces/`)
- `app.yaml`: Active workload namespace (hosts homelab-api Helm release)
- `dev.yaml`: Staging namespace for testing candidate releases
- `monitoring.yaml`: Reserved for Phase 6 observability stack (Prometheus, Grafana, Alertmanager)
- Labels: Namespace classification for RBAC and resource policies

**NetworkPolicy** (`k8s/networkpolicy.yaml`)
- Zero-trust networking model: Deny all traffic by default, allow explicit rules only
- **Ingress rule**: Allows traffic from `ingress-nginx` namespace only (HTTP from controller)
- **Egress rule**: Allows DNS queries to `kube-system:53` only (service discovery)
- Blocks: Pod-to-pod communication outside rules, internet egress, cross-namespace traffic
- Learning impact: Enforces least-privilege networking, prevents lateral movement

### Prerequisites

**Create the app namespace and supporting infrastructure**

```bash
# Create namespaces
kubectl apply -f k8s/namespaces/app.yaml
kubectl apply -f k8s/namespaces/dev.yaml
kubectl apply -f k8s/namespaces/monitoring.yaml

# Create GHCR pull secret in app namespace
kubectl create secret docker-registry ghcr-pull-secret \
  --namespace app \
  --docker-server=ghcr.io \
  --docker-username=<github-username> \
  --docker-password=<github-personal-access-token-with-read:packages> \
  --docker-email=<email>

# Apply NetworkPolicy (zero-trust enforcement)
kubectl apply -f k8s/networkpolicy.yaml
```

### Deploy via Helm

**Development environment** (for local Kind testing)
```bash
helm install homelab-api-app charts/homelab-api \
  --namespace app \
  --values charts/homelab-api/values-dev.yaml
```

**Production environment** (for real deployments)
```bash
helm install homelab-api-app charts/homelab-api \
  --namespace app \
  --values charts/homelab-api/values-prod.yaml
```

**Verify deployment**
```bash
# Check Helm release status
helm list -n app

# Inspect rendered templates (without applying)
helm template homelab-api charts/homelab-api -f charts/homelab-api/values-dev.yaml

# Check rollout and resources
kubectl -n app rollout status deployment/homelab-api
kubectl -n app get deploy,pods,svc,ingress,hpa

# Verify app endpoints through Kind port mapping
curl http://localhost:8080/health
curl http://localhost:8080/api/greeting
curl http://localhost:8080/metrics

# Check NetworkPolicy enforcement
kubectl -n app get networkpolicy
```

**Upgrade with different values**
```bash
helm upgrade homelab-api-app charts/homelab-api \
  --namespace app \
  --values charts/homelab-api/values-prod.yaml --dry-run

# Review changes (--dry-run output) before applying
helm upgrade homelab-api-app charts/homelab-api \
  --namespace app \
  --values charts/homelab-api/values-prod.yaml
```

### Key Helm Concepts

**Templates vs Values Separation**
- Templates define Kubernetes YAML structure with placeholder variables (`{{ .Values.replicaCount }}`)
- Values files contain environment-specific data (2 replicas for dev, 3 for prod)
- This separation enables single-source-of-truth templating: one template, many deployments

**Conditional Rendering**
- `{{ if .Values.hpa.enabled }}` conditionally includes HPA only when enabled
- Allows feature toggle without modifying template files

**Named Templates (Helpers)**
- `_helpers.tpl` defines reusable patterns like `fullname` (combines release + chart name)
- Prevents naming conflicts and ensures consistency across all resources

**Release Management**
- `helm install` creates a new release (idempotent name tracking)
- `helm upgrade` updates an existing release (changes tracked in release history)
- `helm list -n <namespace>` shows all releases and current status

### Phase 5 Migration: Raw → Helm

Raw Kubernetes manifests from Phase 4 are now removed, and the Helm chart is the single source of truth.

```bash
# All future updates: modify charts/homelab-api/values*.yaml and run helm upgrade
# If needed, recover removed legacy files from git history.
```

### Notes

- Helm is a package manager for Kubernetes; it generates final YAML from templates and values at deploy time
- NetworkPolicy enforcement depends on CNI plugin support (Kind may not enforce by default; Calico, Cilium, and Weave do)
- Use `helm lint` to validate chart syntax before deployment
- Use `helm template` to inspect rendered YAML without applying
- Values files are version-controlled; secrets should use external tools (Sealed Secrets, External Secrets, Vault)

## 🔐 Configuration

### Variables
Edit `secret.auto.tfvars` to customize:
```hcl
db_password = "your-secure-password-here"
```

> ⚠️ **Security Note**: `secret.auto.tfvars` is auto-loaded and should be git-ignored. Keep sensitive values out of version control.

For local Python development, `.venv/` is also git-ignored and should not be committed.

For AWS dev stack values, edit `environments/dev/dev.auto.tfvars`.
This controls networking, IAM wiring context, ECR repository names, and EKS cluster/node-group sizing.

## 🛡️ Security & CI/CD

### Custom Policies
- **Checkov Policy**: `policies/tagging_policy.yaml` enforces Owner tags on S3 buckets.

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
