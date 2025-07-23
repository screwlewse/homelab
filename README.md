# k3s DevOps Pipeline - Complete Infrastructure Automation

## Overview

This repository contains a **production-grade k3s DevOps pipeline** with complete Infrastructure as Code (IaC) automation, GitOps workflows, and CI/CD integration. It implements enterprise-level DevOps practices on a single-node k3s cluster.

## ✨ Recent Improvements

- **Enhanced Code Quality**: All shell scripts now have proper error handling and logging
- **CI/CD Automation**: Complete GitHub Actions workflows for testing and deployment
- **Comprehensive Testing**: Unit, integration, and security tests with automated reporting
- **Pre-commit Hooks**: Automated code quality checks before commits
- **Security Scanning**: Integrated tfsec, detect-secrets, and vulnerability scanning

See [IMPROVEMENTS.md](IMPROVEMENTS.md) for detailed information about recent enhancements.

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

- Ubuntu 20.04+ server (fresh install supported)
- 2+ CPU cores, 4GB+ RAM recommended
- Static IP address configured

### Fresh Ubuntu Installation

For a brand new Ubuntu server:

```bash
# Download and run the setup script
curl -sfL https://raw.githubusercontent.com/screwlewse/homelab/main/scripts/setup-fresh-ubuntu.sh | bash -s -- server

# For worker nodes (provide server URL and token)
curl -sfL https://raw.githubusercontent.com/screwlewse/homelab/main/scripts/setup-fresh-ubuntu.sh | bash -s -- worker https://SERVER_IP:6443 TOKEN
```

Or clone the repo first:

```bash
git clone https://github.com/screwlewse/homelab.git
cd homelab
./scripts/setup-fresh-ubuntu.sh server  # For control plane
./scripts/setup-fresh-ubuntu.sh worker https://SERVER_IP:6443 TOKEN  # For worker
```

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

## 🧪 Testing

### Running Tests

```bash
# Run all tests
make test

# Run specific test types
make test-bats        # Shell script tests
make test-unit        # Terraform unit tests
make test-integration # Integration tests
make test-security    # Security scanning

# Quick validation
make test-quick
```

### Pre-commit Hooks

```bash
# Setup pre-commit hooks
make pre-commit

# Run linters manually
make lint
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

## 🖥️ Multi-Node Support

### Adding Worker Nodes

The repository now supports multi-node k3s clusters. To add worker nodes, you need the **k3s node token** from your server node.

#### Step 1: Get the Node Token (on server node)

The k3s node token is a secure authentication token that allows worker nodes to join your cluster. Run this command on your **server/control plane node**:

```bash
# SSH into your server node first, then run:
sudo cat /var/lib/rancher/k3s/server/node-token

# Example output:
# K10c843b1f6b8c1d23456789abcdef0123456789abcdef0123456789abcdef01::server:1234567890abcdef1234567890abcdef
```

**Important**: This token is like a password - keep it secure and don't share it publicly.

#### Step 2: Get the Server URL

The server URL is the address where your k3s API server is listening:

```bash
# Format: https://<SERVER_IP>:6443
# Example: https://10.0.0.88:6443

# To find your server IP:
hostname -I | awk '{print $1}'
```

#### Step 3: Join Worker Node to Cluster

On the **worker node**, run one of these commands:

```bash
# Option 1: Using the worker setup script
./scripts/setup-k3s-worker.sh https://SERVER_IP:6443 YOUR_NODE_TOKEN

# Option 2: During fresh Ubuntu install
./scripts/setup-fresh-ubuntu.sh worker https://SERVER_IP:6443 YOUR_NODE_TOKEN

# Real example:
./scripts/setup-k3s-worker.sh https://10.0.0.88:6443 K10c843b1f6b8c1d23456789abcdef0123456789abcdef0123456789abcdef01::server:1234567890abcdef1234567890abcdef
```

#### Step 4: Verify Worker Node Joined

Back on the **server node**, verify the worker joined successfully:

```bash
# Check all nodes in the cluster
kubectl get nodes

# Example output:
# NAME       STATUS   ROLES                  AGE   VERSION
# server-1   Ready    control-plane,master   10d   v1.32.6+k3s1
# worker-1   Ready    <none>                 5m    v1.32.6+k3s1
```

### Node Management

```bash
# View all nodes with more details
kubectl get nodes -o wide

# Label worker nodes for clarity
kubectl label node worker-1 node-role.kubernetes.io/worker=worker

# Taint nodes for specific workloads
kubectl taint nodes worker-1 workload=frontend:NoSchedule

# Remove a node from cluster (run on server)
kubectl drain worker-1 --ignore-daemonsets --delete-emptydir-data
kubectl delete node worker-1
```

### Troubleshooting Worker Node Issues

If the worker node fails to join:

1. **Check connectivity**:
   ```bash
   # From worker, test connection to server
   curl -k https://SERVER_IP:6443
   ```

2. **Verify token is correct**:
   - Token should start with `K10` or `K11`
   - Token is case-sensitive
   - Token doesn't expire but changes if k3s is reinstalled

3. **Check firewall**:
   ```bash
   # Required ports:
   # 6443: Kubernetes API server
   # 10250: Kubelet metrics
   # 8472: Flannel VXLAN (if using Flannel)
   ```

4. **View k3s agent logs** (on worker):
   ```bash
   sudo journalctl -u k3s-agent -f
   ```

### Considerations for Multi-Node

- **Storage**: Consider distributed storage (Longhorn, Rook/Ceph)
- **Networking**: Ensure all nodes can communicate
- **Load Balancing**: MetalLB works across all nodes
- **Scheduling**: Use node selectors and affinity rules

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