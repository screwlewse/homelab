#!/bin/bash
# k3s DevOps Pipeline - Phase 2 Setup Script
# Automated deployment of core infrastructure components

set -euo pipefail

# Colors for output
YELLOW='\033[1;33m'
GREEN='\033[1;32m'
BLUE='\033[1;34m'
RED='\033[1;31m'
NC='\033[0m' # No Color

# Configuration
KUBECONFIG=${KUBECONFIG:-~/.kube/config}
export KUBECONFIG

log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

success() {
    echo -e "${GREEN}[SUCCESS] $1${NC}"
}

warning() {
    echo -e "${YELLOW}[WARNING] $1${NC}"
}

error() {
    echo -e "${RED}[ERROR] $1${NC}"
    exit 1
}

check_prerequisites() {
    log "Checking prerequisites..."
    
    # Check if kubectl is available
    if ! command -v kubectl &> /dev/null; then
        error "kubectl is not installed or not in PATH"
    fi
    
    # Check if helm is available
    if ! command -v helm &> /dev/null; then
        error "helm is not installed or not in PATH"
    fi
    
    # Check if k3s cluster is accessible
    if ! kubectl get nodes &> /dev/null; then
        error "Cannot access k3s cluster. Check your kubeconfig."
    fi
    
    success "Prerequisites check passed"
}

deploy_metallb() {
    log "Deploying MetalLB load balancer..."
    
    kubectl apply -f manifests/metallb/metallb-namespace.yaml
    kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.14.8/config/manifests/metallb-native.yaml
    
    log "Waiting for MetalLB pods to be ready..."
    kubectl wait --for=condition=ready pod -l app=metallb -n metallb-system --timeout=120s || true
    
    # Apply IP pool configuration if it doesn't exist
    if ! kubectl get ipaddresspools -n metallb-system production &> /dev/null; then
        kubectl apply -f manifests/metallb/metallb-config.yaml
    else
        warning "MetalLB IP pool already exists"
    fi
    
    success "MetalLB deployed successfully"
}

deploy_traefik() {
    log "Deploying Traefik ingress controller..."
    
    kubectl apply -f manifests/traefik/traefik-namespace.yaml
    helm repo add traefik https://traefik.github.io/charts
    helm repo update
    
    helm upgrade --install traefik traefik/traefik \
        --namespace traefik \
        --values manifests/traefik/traefik-values.yaml \
        --wait --timeout=300s
    
    success "Traefik deployed successfully"
}

deploy_cert_manager() {
    log "Deploying cert-manager..."
    
    kubectl apply -f manifests/cert-manager/cert-manager-namespace.yaml
    helm repo add jetstack https://charts.jetstack.io
    helm repo update
    
    helm upgrade --install cert-manager jetstack/cert-manager \
        --namespace cert-manager \
        --set crds.enabled=true \
        --wait --timeout=300s
    
    success "cert-manager deployed successfully"
}

deploy_harbor() {
    log "Deploying Harbor container registry..."
    
    kubectl apply -f manifests/harbor/harbor-namespace.yaml
    helm repo add harbor https://helm.goharbor.io
    helm repo update
    
    helm upgrade --install harbor harbor/harbor \
        --namespace harbor \
        --values manifests/harbor/harbor-values.yaml \
        --wait --timeout=600s
    
    success "Harbor deployed successfully"
}

verify_deployment() {
    log "Verifying deployment..."
    
    # Check MetalLB
    log "Checking MetalLB..."
    kubectl get pods -n metallb-system
    kubectl get ipaddresspools -n metallb-system
    
    # Check Traefik
    log "Checking Traefik..."
    kubectl get pods -n traefik
    kubectl get services -n traefik
    
    # Check cert-manager
    log "Checking cert-manager..."
    kubectl get pods -n cert-manager
    
    # Check Harbor
    log "Checking Harbor..."
    kubectl get pods -n harbor
    kubectl get services -n harbor
    
    # Show LoadBalancer IPs
    echo -e "\n${YELLOW}=== LoadBalancer Services ===${NC}"
    kubectl get services --all-namespaces -o wide | grep LoadBalancer
    
    success "Phase 2 deployment verification complete"
}

display_info() {
    echo -e "\n${BLUE}=== k3s DevOps Pipeline - Phase 2 Complete ===${NC}"
    echo -e "\n${YELLOW}Service Access URLs:${NC}"
    echo -e "  • ${GREEN}Traefik Dashboard:${NC} http://10.0.0.200:9000/dashboard/"
    echo -e "  • ${GREEN}Harbor Registry:${NC} http://10.0.0.201"
    echo -e "\n${YELLOW}Default Credentials:${NC}"
    echo -e "  • ${GREEN}Harbor:${NC} admin / Harbor12345"
    echo -e "\n${YELLOW}Next Steps:${NC}"
    echo -e "  • Use 'make status' to check component status"
    echo -e "  • Use 'make verify' to test service accessibility"
    echo -e "  • Proceed to Phase 3: GitOps & CI/CD setup"
}

main() {
    echo -e "${BLUE}=== k3s DevOps Pipeline - Phase 2 Setup ===${NC}"
    echo -e "${BLUE}Deploying core infrastructure components...${NC}\n"
    
    check_prerequisites
    deploy_metallb
    deploy_traefik
    deploy_cert_manager
    deploy_harbor
    verify_deployment
    display_info
    
    success "Phase 2 setup completed successfully!"
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi