# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This is a production-grade k3s DevOps pipeline implementing enterprise-level Infrastructure as Code (IaC) practices. The project demonstrates a complete DevOps ecosystem running on a single-node k3s cluster at IP 10.0.0.88.

## Common Commands

### Infrastructure Deployment (Terraform - Recommended)
```bash
make tf-init       # Initialize Terraform providers and modules
make tf-plan       # Preview infrastructure changes
make tf-apply      # Apply infrastructure changes
make tf-test       # Run infrastructure validation tests
make tf-destroy    # Tear down Terraform-managed infrastructure
```

### Traditional Deployment
```bash
make deploy-all    # Deploy all components using kubectl/helm
make verify        # Verify service accessibility
make status        # Check all infrastructure components
make clean         # Remove all deployed components
```

### Testing and Validation
```bash
make tf-validate                      # Validate Terraform configuration and formatting
terraform fmt -check -recursive       # Check Terraform code formatting
terraform validate                    # Validate Terraform syntax
make verify                          # Test HTTP accessibility of all services
make status                          # Comprehensive infrastructure status check
./terraform/tests/validate-infrastructure.sh  # Full infrastructure validation
```

### Development
```bash
kubectl get pods -A                   # Check all pods across namespaces
helm list -A                         # List all Helm releases
docker images | grep 10.0.0.88:30880 # List images in Harbor registry
```

## Architecture

### Core Stack
- **k3s**: Lightweight Kubernetes (v1.32.6+k3s1) on single node
- **Terraform Modules**: Reusable IaC components in `terraform/modules/`
- **GitOps**: ArgoCD with Application-of-Applications pattern
- **Service Mesh**: All services exposed via NodePort (30xxx range)

### Key Services and Access
- **Traefik**: http://10.0.0.88:30900/dashboard/ (Ingress controller)
- **Harbor**: http://10.0.0.88:30880 (admin/Harbor12345) (Container registry)
- **ArgoCD**: http://10.0.0.88:30808 (GitOps engine)
- **Prometheus**: http://10.0.0.88:30909 (Metrics)
- **Grafana**: http://10.0.0.88:30300 (admin/admin123) (Dashboards)
- **AlertManager**: http://10.0.0.88:30903 (Alerts)

### Infrastructure Patterns
1. **Terraform First**: Always use Terraform modules for infrastructure changes
2. **NodePort Services**: All services use NodePort for single-node accessibility
3. **Local Storage**: Uses local-path-provisioner for persistent volumes
4. **HTTP Only**: Development mode with no TLS (security hardening optional)

## Working with Terraform

### Module Structure
Each service has its own Terraform module in `terraform/modules/`:
- `metallb/` - Load balancer configuration
- `traefik/` - Ingress controller
- `harbor/` - Container registry
- `cert-manager/` - Certificate management
- `argocd/` - GitOps engine
- `monitoring/` - Prometheus stack

### Making Changes
1. Modify the relevant module in `terraform/modules/`
2. Update `terraform/infrastructure.tf` if adding new modules
3. Run `make tf-plan` to preview changes
4. Apply with `make tf-apply`
5. Validate with `make tf-test`

## GitOps Workflow

### Application Management
- Applications defined in `gitops/apps/`
- Environment-specific configs in `gitops/environments/`
- Use ArgoCD UI or CLI for application management

### Adding New Applications
1. Create application manifest in `gitops/apps/`
2. Add to `gitops/apps/app-of-apps.yaml`
3. ArgoCD will automatically sync

## CI/CD Integration

### GitHub Actions Workflows
- `.github/workflows/terraform-infrastructure.yaml` - Infrastructure automation
- `.github/workflows/ci-cd-pipeline.yaml` - Application deployment
- Required secrets configured in GitHub repository

### Pipeline Triggers
- Push to main branch triggers infrastructure validation
- Tag creation triggers full deployment
- Manual dispatch available for all workflows

## Important Context

### Repository Information
- **GitHub**: https://github.com/screwlewse/homelab
- **Current Phase**: Phase 4 complete (all infrastructure operational)
- **Terraform State**: Local file at `terraform/terraform.tfstate`

### Deployment Options
1. **Terraform** (Recommended): Full IaC automation
2. **Traditional**: Manual kubectl/helm commands
3. **Phased**: Step-by-step setup scripts

### Network Configuration
- **Server IP**: 10.0.0.88 (ThinkPad T470s)
- **MetalLB Pool**: 10.0.0.200-210
- **NodePort Range**: 30000-32767

## Security Notes

This is a development/homelab setup with:
- HTTP-only access (no TLS certificates)
- Default credentials for demo purposes
- Insecure dashboard access
- Production hardening recommendations in docs but not implemented

For production use, implement the security recommendations in the documentation.