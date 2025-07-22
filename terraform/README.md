# k3s DevOps Pipeline - Infrastructure as Code

## Overview

This Terraform project automates the complete deployment of a k3s DevOps pipeline infrastructure, replacing manual kubectl and Helm commands with declarative Infrastructure as Code (IaC).

## Architecture

### Components Managed

| Component | Module | Purpose | Service Type |
|-----------|--------|---------|-------------|
| **MetalLB** | `modules/metallb` | Load balancer for k3s | ClusterIP |
| **Traefik** | `modules/traefik` | Ingress controller | NodePort |
| **Harbor** | `modules/harbor` | Container registry | NodePort |
| **cert-manager** | `modules/cert-manager` | SSL certificate management | ClusterIP |
| **ArgoCD** | `modules/argocd` | GitOps engine | NodePort |

### Service Access Ports

| Service | Port | URL |
|---------|------|-----|
| Traefik Dashboard | 30900 | http://10.0.0.88:30900/dashboard/ |
| Traefik HTTP | 30080 | http://10.0.0.88:30080 |
| Harbor Registry | 30880 | http://10.0.0.88:30880 |
| ArgoCD Web UI | 30808 | http://10.0.0.88:30808 |

## Quick Start

### Prerequisites

- Terraform >= 1.0
- kubectl configured with k3s cluster access
- k3s cluster running on target server

### Initial Setup

```bash
# Clone repository
cd /home/davidg/k8s-devops-pipeline/terraform

# Copy and customize variables
cp terraform.tfvars.example terraform.tfvars
nano terraform.tfvars

# Initialize Terraform
terraform init

# Plan deployment
terraform plan

# Apply infrastructure
terraform apply
```

### Terraform Configuration

```hcl
# terraform.tfvars
cluster_name    = "k3s-devops-homelab"
server_ip       = "10.0.0.88"
kubeconfig_path = "~/.kube/config"

metallb_ip_range = "10.0.0.200-10.0.0.210"

nodeport_range = {
  traefik_http      = 30080
  traefik_https     = 30443
  traefik_dashboard = 30900
  harbor            = 30880
  argocd            = 30808
}

harbor_config = {
  admin_password = "Harbor12345"
  storage_size   = "5Gi"
}

argocd_config = {
  server_insecure = true
}

enable_components = {
  metallb      = true
  traefik      = true
  harbor       = true
  cert_manager = true
  argocd       = true
}
```

## Terraform Modules

### MetalLB Module (`modules/metallb`)

Deploys MetalLB load balancer with configurable IP pools.

**Features:**
- Layer 2 advertisement mode
- Configurable IP address ranges
- Automatic L2Advertisement setup

**Usage:**
```hcl
module "metallb" {
  source = "./modules/metallb"
  
  ip_range  = "10.0.0.200-10.0.0.210"
  pool_name = "default-pool"
}
```

### Traefik Module (`modules/traefik`)

Deploys Traefik ingress controller using Helm.

**Features:**
- NodePort or LoadBalancer service types
- Dashboard with configurable security
- Persistent storage support
- SSL/TLS termination ready

**Usage:**
```hcl
module "traefik" {
  source = "./modules/traefik"
  
  service_type = "NodePort"
  nodeports = {
    http      = 30080
    https     = 30443
    dashboard = 30900
  }
  dashboard_enabled  = true
  dashboard_insecure = true
}
```

### Harbor Module (`modules/harbor`)

Deploys Harbor container registry using Helm.

**Features:**
- Internal database and Redis
- Configurable persistent storage
- Resource limits for single-node deployment
- Security scanning with Trivy
- NodePort access configuration

**Usage:**
```hcl
module "harbor" {
  source = "./modules/harbor"
  
  service_type   = "NodePort"
  nodeport       = 30880
  external_url   = "http://10.0.0.88:30880"
  admin_password = var.harbor_admin_password
  
  storage_sizes = {
    registry    = "5Gi"
    chartmuseum = "5Gi"
    jobservice  = "1Gi"
    database    = "1Gi"
    redis       = "1Gi"
    trivy       = "5Gi"
  }
}
```

### cert-manager Module (`modules/cert-manager`)

Deploys cert-manager for SSL certificate management.

**Features:**
- Automatic CRD installation
- Optional Let's Encrypt ClusterIssuer
- Integration with Traefik

**Usage:**
```hcl
module "cert_manager" {
  source = "./modules/cert-manager"
  
  create_letsencrypt_issuer = false
  letsencrypt_email        = "admin@k3s.local"
}
```

### ArgoCD Module (`modules/argocd`)

Deploys ArgoCD GitOps engine.

**Features:**
- Raw manifest installation from upstream
- NodePort service configuration
- Insecure mode for development
- ApplicationSet support

**Usage:**
```hcl
module "argocd" {
  source = "./modules/argocd"
  
  service_type    = "NodePort"
  nodeport        = 30808
  server_insecure = true
}
```

## Operations

### Terraform Commands

```bash
# Initialize and validate
terraform init
terraform validate
terraform fmt -check -recursive

# Plan and apply
terraform plan
terraform apply
terraform apply -target=module.harbor

# Outputs and state
terraform output
terraform show
terraform state list

# Destroy
terraform destroy
terraform destroy -target=module.harbor
```

### Component Management

```bash
# Enable/disable components
terraform apply -var="enable_components={metallb=true,traefik=true,harbor=false,cert_manager=true,argocd=true}"

# Update single component
terraform apply -target=module.traefik

# Check component status
kubectl get pods -n traefik
kubectl get services -n harbor
```

## Testing and Validation

### Automated Testing

```bash
# Run infrastructure validation
./tests/validate-infrastructure.sh

# Run with custom server IP
./tests/validate-infrastructure.sh 10.0.0.88

# Generate validation report
./tests/validate-infrastructure.sh > validation-results.log
```

### Manual Verification

```bash
# Check Terraform outputs
terraform output service_urls

# Test service accessibility
curl -s http://10.0.0.88:30900/dashboard/
curl -s http://10.0.0.88:30880
curl -s http://10.0.0.88:30808

# Kubernetes health checks
kubectl get nodes
kubectl get pods --all-namespaces
kubectl get services --all-namespaces | grep NodePort
```

## CI/CD Integration

### GitHub Actions

The repository includes a complete CI/CD pipeline:

**Workflow: `.github/workflows/terraform-infrastructure.yaml`**

**Triggers:**
- Push to `main` branch (auto-apply)
- Push to `develop` branch (plan only)
- Pull requests (plan and validate)
- Manual dispatch (plan/apply/destroy)

**Stages:**
1. **Validate**: Format check, validation, security scan
2. **Plan**: Generate execution plan
3. **Apply**: Deploy to production (main branch)
4. **Destroy**: Infrastructure cleanup (manual)

**Required Secrets:**
```bash
# GitHub repository secrets
KUBECONFIG         # Base64 encoded kubeconfig
HARBOR_PASSWORD    # Harbor admin password
```

### Local Development

```bash
# Format code
terraform fmt -recursive

# Security scanning
tfsec terraform/

# Validation
terraform validate

# Plan with different var files
terraform plan -var-file="environments/dev/terraform.tfvars"
```

## State Management

### Local State (Default)

```hcl
terraform {
  backend "local" {
    path = "./terraform.tfstate"
  }
}
```

### Remote State Options

**S3 Backend:**
```hcl
terraform {
  backend "s3" {
    bucket = "k3s-terraform-state"
    key    = "infrastructure/terraform.tfstate"
    region = "us-east-1"
  }
}
```

**HTTP Backend (GitLab):**
```hcl
terraform {
  backend "http" {
    address        = "https://gitlab.com/api/v4/projects/PROJECT_ID/terraform/state/infrastructure"
    lock_address   = "https://gitlab.com/api/v4/projects/PROJECT_ID/terraform/state/infrastructure/lock"
    unlock_address = "https://gitlab.com/api/v4/projects/PROJECT_ID/terraform/state/infrastructure/lock"
  }
}
```

## Troubleshooting

### Common Issues

#### Terraform Init Failures

```bash
# Clear cache and reinitialize
rm -rf .terraform .terraform.lock.hcl
terraform init

# Check provider versions
terraform version
terraform providers
```

#### Module Deployment Failures

```bash
# Check individual module
terraform plan -target=module.metallb
terraform apply -target=module.metallb

# Debug with verbose output
TF_LOG=DEBUG terraform apply

# Check Kubernetes connectivity
kubectl cluster-info
kubectl get nodes
```

#### Service Accessibility Issues

```bash
# Check NodePort services
kubectl get services --all-namespaces | grep NodePort

# Verify pod status
kubectl get pods --all-namespaces | grep -v Running

# Check service endpoints
kubectl get endpoints -n traefik
kubectl describe service traefik -n traefik
```

#### State Management Issues

```bash
# Import existing resources
terraform import kubernetes_namespace.traefik traefik

# Refresh state
terraform refresh

# Force unlock (if stuck)
terraform force-unlock LOCK_ID
```

### Debugging Workflows

**Infrastructure Debugging:**
1. Check Terraform plan output
2. Verify kubeconfig access
3. Validate resource dependencies
4. Review Kubernetes events

**Service Debugging:**
1. Check pod logs: `kubectl logs -n NAMESPACE POD_NAME`
2. Describe resources: `kubectl describe pod POD_NAME -n NAMESPACE`
3. Test connectivity: `kubectl port-forward service/SERVICE 8080:80`
4. Check service discovery: `kubectl get endpoints`

## Security Considerations

### Current Configuration

- **Development Mode**: Insecure access enabled for dashboards
- **Local Storage**: PVCs use local-path-provisioner
- **No TLS**: HTTP access for all services
- **Default Credentials**: Standard passwords for demo

### Production Hardening

**Security Checklist:**
- [ ] Enable TLS for all services
- [ ] Configure proper RBAC
- [ ] Use secrets management (SOPS, Vault)
- [ ] Implement network policies
- [ ] Enable Pod Security Standards
- [ ] Configure image scanning policies
- [ ] Set up audit logging

**Implementation:**
```hcl
# Enable TLS
harbor_config = {
  tls_enabled = true
}

# Use external secrets
data "kubernetes_secret" "harbor_password" {
  metadata {
    name      = "harbor-credentials"
    namespace = "harbor"
  }
}
```

## Monitoring and Observability

### Terraform State Monitoring

```bash
# State size and complexity
terraform show -json | jq '.values.root_module.resources | length'

# Resource drift detection
terraform plan -detailed-exitcode

# State backup
cp terraform.tfstate terraform.tfstate.backup.$(date +%Y%m%d)
```

### Infrastructure Metrics

```bash
# Resource utilization
kubectl top nodes
kubectl top pods --all-namespaces

# Service health
kubectl get componentstatuses
kubectl get events --sort-by=.metadata.creationTimestamp
```

## Migration from Manual Deployment

### Import Existing Resources

```bash
# Import namespaces
terraform import kubernetes_namespace.traefik traefik
terraform import kubernetes_namespace.harbor harbor
terraform import kubernetes_namespace.argocd argocd

# Import Helm releases
terraform import helm_release.traefik traefik/traefik
terraform import helm_release.harbor harbor/harbor
```

### Gradual Migration Strategy

1. **Start with state import** for existing resources
2. **Deploy new components** via Terraform
3. **Migrate manual deployments** one by one
4. **Update CI/CD pipelines** to use Terraform
5. **Remove manual scripts** after validation

## Future Enhancements

### Planned Features

- [ ] Multi-cluster support with Crossplane
- [ ] External DNS integration
- [ ] Vault integration for secrets
- [ ] Network policies automation
- [ ] Monitoring stack (Prometheus/Grafana)
- [ ] Service mesh (Istio) integration

### Architecture Evolution

```hcl
# Future: Multi-environment support
module "infrastructure" {
  source = "./modules/k3s-infrastructure"
  
  environment = var.environment
  cluster_config = var.clusters[var.environment]
}
```

---

**Project Status**: ✅ Infrastructure as Code Complete  
**Deployment**: Fully automated via Terraform  
**CI/CD**: GitHub Actions integrated  
**Testing**: Automated validation included