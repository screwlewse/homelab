# k3s DevOps Pipeline - Complete Infrastructure Automation

## Overview

This repository contains a **production-grade k3s DevOps pipeline** with complete Infrastructure as Code (IaC) automation, GitOps workflows, and CI/CD integration. It implements enterprise-level DevOps practices on a single-node k3s cluster.

## 🏗️ Architecture

### Core Infrastructure Stack

| Component | Technology | Access | Purpose |
|-----------|------------|--------|---------|
| **Container Orchestration** | k3s (Kubernetes) | - | Lightweight single-node cluster |
| **Load Balancing** | MetalLB | IP Pool: 10.0.0.200-210 | LoadBalancer services |
| **Ingress Controller** | Traefik | http://10.0.0.88:30900 | HTTP/HTTPS routing |
| **Container Registry** | Harbor | http://10.0.0.88:30880 | Image storage and scanning |
| **GitOps Engine** | ArgoCD | http://10.0.0.88:30808 | Automated deployment |
| **Certificate Management** | cert-manager | - | SSL certificate automation |

### Infrastructure as Code

- **Terraform Modules**: Complete IaC with reusable components
- **GitOps Integration**: ArgoCD for declarative deployments
- **CI/CD Automation**: GitHub Actions workflows
- **Testing & Validation**: Automated infrastructure testing

## 🚀 Quick Start

### Prerequisites

- Ubuntu 24 server with k3s installed
- kubectl configured with cluster access
- Terraform >= 1.0 (for IaC deployment)

### Option 1: Infrastructure as Code (Recommended)

```bash
# Clone repository
git clone https://github.com/screwlewse/homelab.git
cd homelab

# Deploy with Terraform
make tf-init
make tf-apply

# Validate deployment
make tf-test
```

### Option 2: Traditional Deployment

```bash
# Deploy all components
make deploy-all

# Verify services
make verify
make status
```

### Option 3: Phase-by-Phase Setup

```bash
# Phase 1: Foundation (k3s, networking)
make phase1
make verify-phase1

# Phase 2 & 3: Complete infrastructure
make deploy-all
```

## 📋 Service Access

### Web Interfaces

| Service | URL | Credentials |
|---------|-----|-------------|
| **Traefik Dashboard** | http://10.0.0.88:30900/dashboard/ | No auth required |
| **Harbor Registry** | http://10.0.0.88:30880 | admin / Harbor12345 |
| **ArgoCD GitOps** | http://10.0.0.88:30808 | admin / [get secret] |

### CLI Access

```bash
# Get ArgoCD admin password
kubectl get secret argocd-initial-admin-secret -n argocd -o jsonpath='{.data.password}' | base64 -d

# Check all services
make info
```

## 🔧 Infrastructure as Code

### Terraform Modules

```
terraform/
├── modules/
│   ├── metallb/      # Load balancer
│   ├── traefik/      # Ingress controller
│   ├── harbor/       # Container registry
│   ├── cert-manager/ # Certificate management
│   └── argocd/       # GitOps engine
├── tests/            # Infrastructure validation
└── *.tf              # Main configuration
```

### Terraform Operations

```bash
# Initialize and plan
make tf-init
make tf-plan

# Deploy infrastructure
make tf-apply

# Validate deployment
make tf-test

# Show outputs
make tf-output

# Cleanup
make tf-destroy
```

### Configuration

Copy and customize the configuration:

```bash
cp terraform/terraform.tfvars.example terraform/terraform.tfvars
# Edit with your settings
```

## 🔄 GitOps & CI/CD

### ArgoCD Applications

- **Application-of-Applications** pattern
- **Automated sync** from Git repositories
- **Multi-environment** support (dev/staging/prod)
- **Health monitoring** and rollback capabilities

### GitHub Actions

- **Infrastructure Pipeline**: Terraform validation and deployment
- **Application Pipeline**: Build, test, and deploy applications
- **Security Scanning**: tfsec and vulnerability scanning
- **Automated Testing**: Infrastructure validation

### GitOps Structure

```
gitops/
├── apps/                 # ArgoCD Applications
├── environments/         # Environment-specific configs
│   ├── dev/
│   ├── staging/
│   └── prod/
└── infrastructure/       # Infrastructure as Code
```

## 🧪 Testing & Validation

### Automated Testing

```bash
# Run comprehensive infrastructure tests
make tf-test

# Traditional validation
make verify

# Check component status
make status
```

### Manual Verification

```bash
# Test service accessibility
curl http://10.0.0.88:30900/dashboard/
curl http://10.0.0.88:30880
curl http://10.0.0.88:30808

# Check Kubernetes health
kubectl get nodes
kubectl get pods --all-namespaces
```

## 📚 Documentation

- **[Phase 3 GitOps Guide](docs/PHASE3-GITOPS.md)**: Complete GitOps implementation
- **[Terraform README](terraform/README.md)**: Infrastructure as Code details
- **[Scripts Directory](scripts/)**: Automation and setup scripts

## 🛠️ Available Commands

```bash
# Infrastructure Operations
make help                 # Show all available commands
make deploy-all           # Deploy entire infrastructure
make status               # Check infrastructure status
make verify               # Verify service accessibility
make clean                # Remove all components

# Terraform Operations  
make tf-init              # Initialize Terraform
make tf-plan              # Plan infrastructure changes
make tf-apply             # Apply Terraform configuration
make tf-test              # Run infrastructure tests
make tf-destroy           # Destroy infrastructure

# Phase-based Operations
make phase1               # Foundation setup
make verify-phase1        # Verify Phase 1
make network-info         # Display network information
make logs                 # Show component logs
```

## 🔐 Security

### Current Configuration (Development)

- **HTTP Access**: All services use HTTP for development
- **Insecure Dashboards**: Traefik and ArgoCD dashboards open
- **Default Credentials**: Standard passwords for demo purposes

### Production Hardening

- [ ] Enable TLS for all services
- [ ] Configure proper RBAC
- [ ] Implement network policies
- [ ] Use external secret management
- [ ] Enable audit logging

## 📊 Features

### ✅ Implemented

- **Complete Infrastructure as Code** with Terraform
- **GitOps Workflows** with ArgoCD
- **CI/CD Automation** with GitHub Actions
- **Automated Testing** and validation
- **NodePort Services** for single-node access
- **Comprehensive Documentation**
- **Production-ready Automation**

### 🔮 Future Enhancements

- Multi-cluster GitOps with ApplicationSets
- Service mesh integration (Istio)
- Advanced monitoring (Prometheus + Grafana)
- External DNS automation
- Vault integration for secrets
- Disaster recovery automation

## 🚦 Project Status

- **Phase 1**: ✅ Foundation (k3s, networking)
- **Phase 2**: ✅ Core Infrastructure (Traefik, Harbor, cert-manager)
- **Phase 3**: ✅ GitOps & CI/CD (ArgoCD, GitHub Actions)
- **Infrastructure as Code**: ✅ Complete Terraform automation
- **Testing & Validation**: ✅ Comprehensive test suite

## 🤝 Contributing

This is a homelab project demonstrating enterprise DevOps practices. Feel free to:

- Fork the repository
- Submit improvements
- Report issues
- Share feedback

## 📄 License

This project is for educational and demonstration purposes.

---

**🏆 Enterprise-Grade k3s DevOps Pipeline - Fully Automated with Infrastructure as Code**

**Repository**: https://github.com/screwlewse/homelab  
**Infrastructure**: Terraform + k3s + GitOps  
**Automation**: 100% Infrastructure as Code