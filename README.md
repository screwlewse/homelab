# k3s DevOps Pipeline - Phase 2: Core Infrastructure

## Overview

This repository contains the implementation of **Phase 2** of the k3s DevOps Pipeline project, focusing on core infrastructure deployment including ingress controller, load balancer, container registry, and certificate management.

## Architecture

### Deployed Components

| Component | Technology | LoadBalancer IP | Purpose |
|-----------|------------|-----------------|---------|
| **Load Balancer** | MetalLB | 10.0.0.200-210 | Service load balancing |
| **Ingress Controller** | Traefik | 10.0.0.200 | HTTP/HTTPS routing |
| **Container Registry** | Harbor | 10.0.0.201 | Image storage and scanning |
| **Certificate Manager** | cert-manager | N/A | SSL certificate automation |

### Network Configuration

- **k3s Server**: 10.0.0.88 (Ubuntu 24 server)
- **MetalLB IP Pool**: 10.0.0.200-10.0.0.210
- **Access Method**: Mac laptop → LoadBalancer IPs → k3s services

## Quick Start

### Prerequisites

- k3s cluster running on 10.0.0.88
- kubectl configured with cluster access
- Helm package manager installed
- Network connectivity from Mac to 10.0.0.x subnet

### Deploy All Components

```bash
# Clone or navigate to the project directory
cd /home/davidg/k8s-devops-pipeline

# Deploy all Phase 2 components
make deploy-all

# Check deployment status
make status

# Verify service accessibility
make verify
```

### Individual Component Deployment

```bash
# Deploy components individually
make deploy-metallb
make deploy-traefik
make deploy-cert-manager
make deploy-harbor

# Clean up components
make clean-harbor
make clean-traefik
make clean
```

## Service Access

### Web Interfaces

Access these services from your Mac laptop:

| Service | URL | Credentials |
|---------|-----|-------------|
| **Traefik Dashboard** | http://10.0.0.200:8080 | No auth required |
| **Harbor Web UI** | http://10.0.0.201 | admin / Harbor12345 |

### Command Line Access

```bash
# Check cluster status
kubectl get nodes

# View all LoadBalancer services
kubectl get services --all-namespaces | grep LoadBalancer

# Monitor Harbor deployment
kubectl get pods -n harbor -w

# View Traefik logs
kubectl logs -n traefik -l app.kubernetes.io/name=traefik
```

## Configuration Files

### Directory Structure

```
k8s-devops-pipeline/
├── manifests/
│   ├── metallb/
│   │   ├── metallb-namespace.yaml
│   │   └── metallb-config.yaml
│   ├── traefik/
│   │   ├── traefik-namespace.yaml
│   │   └── traefik-values.yaml
│   ├── harbor/
│   │   ├── harbor-namespace.yaml
│   │   └── harbor-values.yaml
│   └── cert-manager/
│       └── cert-manager-namespace.yaml
├── scripts/
│   └── setup-phase2.sh
├── docs/
├── helm-charts/
├── apps/
├── Makefile
└── README.md
```

### Key Configuration Details

#### MetalLB Configuration
- **IP Pool**: 10.0.0.200-10.0.0.210
- **Advertisement**: Layer 2 (ARP)
- **Pool Name**: default-pool

#### Traefik Configuration
- **Service Type**: LoadBalancer (10.0.0.200)
- **Ports**: HTTP (80), HTTPS (443), Dashboard (8080)
- **Dashboard**: Enabled with insecure access

#### Harbor Configuration
- **Service Type**: LoadBalancer (10.0.0.201)
- **Database**: Internal PostgreSQL
- **Storage**: Local path provisioner (5Gi registry, 1Gi DB)
- **TLS**: Disabled for internal testing

## Automation Scripts

### Makefile Targets

```bash
make help          # Display help message
make status        # Check status of all components
make deploy-all    # Deploy all infrastructure components
make verify        # Verify service accessibility
make clean         # Remove all components
make info          # Display service information
```

### Setup Script

```bash
# Run automated Phase 2 setup
./scripts/setup-phase2.sh
```

The setup script includes:
- Prerequisites checking
- Sequential component deployment
- Health checks and verification
- Service information display

## Troubleshooting

### Common Issues

#### MetalLB IP Pool Conflicts
```bash
# Check existing IP pools
kubectl get ipaddresspools -n metallb-system

# Delete conflicting pool if needed
kubectl delete ipaddresspool production -n metallb-system
```

#### Harbor Deployment Timeout
```bash
# Increase timeout for Harbor deployment
helm upgrade harbor harbor/harbor -n harbor --timeout 15m

# Check Harbor pod status
kubectl get pods -n harbor
kubectl describe pod <harbor-pod-name> -n harbor
```

#### Traefik Dashboard Access
```bash
# Check Traefik service
kubectl get service traefik -n traefik

# Port-forward if LoadBalancer isn't working
kubectl port-forward service/traefik 8080:8080 -n traefik
```

### Logs and Debugging

```bash
# View component logs
kubectl logs -n traefik -l app.kubernetes.io/name=traefik
kubectl logs -n harbor -l app=harbor
kubectl logs -n metallb-system -l app=metallb

# Check events for issues
kubectl get events --all-namespaces --sort-by='.lastTimestamp'
```

## Security Considerations

### Current Configuration

- **Harbor**: HTTP only (development setup)
- **Traefik**: Insecure dashboard enabled
- **No RBAC**: Default service account permissions

### Production Hardening (Future)

- Enable TLS for all services
- Configure proper RBAC
- Secure dashboard access
- Network policies implementation

## Resource Usage

### Current Allocation

| Component | CPU Request | Memory Request | Storage |
|-----------|-------------|----------------|---------|
| MetalLB | 100m | 100Mi | - |
| Traefik | 100m | 128Mi | 128Mi |
| Harbor | ~1000m | ~2Gi | 12Gi |
| cert-manager | 100m | 150Mi | - |

### Monitoring Resource Usage

```bash
# Check node resources
kubectl top nodes

# Check pod resources
kubectl top pods --all-namespaces

# View resource requests/limits
kubectl describe nodes
```

## Next Steps (Phase 3)

1. **ArgoCD Installation**: GitOps engine deployment
2. **Git Repository Setup**: Infrastructure and application repositories
3. **CI/CD Pipeline**: GitHub Actions integration
4. **Application Deployment**: Sample applications via GitOps

## Support and Contributing

### Getting Help

- Check logs using kubectl commands above
- Review Makefile targets for common operations
- Use `make status` for health checks

### File Structure

- **manifests/**: Kubernetes YAML manifests
- **scripts/**: Automation and setup scripts
- **docs/**: Additional documentation
- **Makefile**: Primary automation interface

---

**Phase 2 Status**: ✅ Complete  
**Next Phase**: Phase 3 - GitOps & CI/CD Pipeline  
**Project Repository**: k3s DevOps Pipeline Implementation