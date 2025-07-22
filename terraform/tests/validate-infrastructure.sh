#!/bin/bash
# Infrastructure Validation Script for Terraform Deployment
# Tests all deployed components for health and accessibility

set -euo pipefail

# Colors for output
YELLOW='\033[1;33m'
GREEN='\033[1;32m'
BLUE='\033[1;34m'
RED='\033[1;31m'
NC='\033[0m'

# Configuration
KUBECONFIG=${KUBECONFIG:-~/.kube/config}
export KUBECONFIG

SERVER_IP=${1:-10.0.0.88}
TIMEOUT=${TIMEOUT:-300}

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
    
    if ! command -v kubectl &> /dev/null; then
        error "kubectl is not installed or not in PATH"
    fi
    
    if ! kubectl cluster-info &> /dev/null; then
        error "Cannot access Kubernetes cluster. Check kubeconfig."
    fi
    
    if ! command -v curl &> /dev/null; then
        error "curl is not installed or not in PATH"
    fi
    
    success "Prerequisites check passed"
}

wait_for_pods() {
    local namespace=$1
    local label_selector=$2
    local timeout=${3:-300}
    
    log "Waiting for pods in namespace '$namespace' with selector '$label_selector'..."
    
    if kubectl wait --for=condition=ready pod -l "$label_selector" -n "$namespace" --timeout="${timeout}s" &> /dev/null; then
        success "Pods are ready in namespace '$namespace'"
    else
        warning "Some pods may not be ready in namespace '$namespace'"
        kubectl get pods -n "$namespace" -l "$label_selector"
    fi
}

test_metallb() {
    log "Testing MetalLB Load Balancer..."
    
    # Check MetalLB namespace and pods
    if kubectl get namespace metallb-system &> /dev/null; then
        success "MetalLB namespace exists"
        
        wait_for_pods "metallb-system" "app=metallb" 120
        
        # Check IP address pools
        if kubectl get ipaddresspools -n metallb-system &> /dev/null; then
            local pools=$(kubectl get ipaddresspools -n metallb-system -o name | wc -l)
            success "MetalLB has $pools IP address pool(s)"
        else
            warning "No MetalLB IP address pools found"
        fi
    else
        warning "MetalLB namespace not found - may be disabled"
    fi
}

test_traefik() {
    log "Testing Traefik Ingress Controller..."
    
    if kubectl get namespace traefik &> /dev/null; then
        success "Traefik namespace exists"
        
        wait_for_pods "traefik" "app.kubernetes.io/name=traefik" 120
        
        # Check Traefik service
        if kubectl get service traefik -n traefik &> /dev/null; then
            local service_type=$(kubectl get service traefik -n traefik -o jsonpath='{.spec.type}')
            success "Traefik service exists (type: $service_type)"
        fi
        
        # Test Traefik dashboard accessibility
        log "Testing Traefik dashboard accessibility..."
        if curl -s -o /dev/null -w "%{http_code}" --connect-timeout 5 "http://${SERVER_IP}:30900/dashboard/" | grep -q "200"; then
            success "Traefik dashboard is accessible at http://${SERVER_IP}:30900/dashboard/"
        else
            warning "Traefik dashboard may not be accessible"
        fi
    else
        warning "Traefik namespace not found - may be disabled"
    fi
}

test_harbor() {
    log "Testing Harbor Container Registry..."
    
    if kubectl get namespace harbor &> /dev/null; then
        success "Harbor namespace exists"
        
        wait_for_pods "harbor" "app=harbor" 300
        
        # Check Harbor service
        if kubectl get service harbor -n harbor &> /dev/null; then
            success "Harbor service exists"
        fi
        
        # Test Harbor accessibility
        log "Testing Harbor web UI accessibility..."
        if curl -s -o /dev/null -w "%{http_code}" --connect-timeout 10 "http://${SERVER_IP}:30880" | grep -q "200"; then
            success "Harbor web UI is accessible at http://${SERVER_IP}:30880"
        else
            warning "Harbor web UI may not be accessible"
        fi
        
        # Check Harbor database
        if kubectl get pod -n harbor -l app=harbor,component=database | grep -q "Running"; then
            success "Harbor database is running"
        else
            warning "Harbor database may not be ready"
        fi
    else
        warning "Harbor namespace not found - may be disabled"
    fi
}

test_cert_manager() {
    log "Testing cert-manager..."
    
    if kubectl get namespace cert-manager &> /dev/null; then
        success "cert-manager namespace exists"
        
        wait_for_pods "cert-manager" "app.kubernetes.io/name=cert-manager" 120
        
        # Check cert-manager CRDs
        local crds=$(kubectl get crd | grep cert-manager.io | wc -l)
        if [ "$crds" -gt 0 ]; then
            success "cert-manager has $crds CRDs installed"
        else
            warning "cert-manager CRDs may not be installed"
        fi
        
        # Check ClusterIssuers
        local issuers=$(kubectl get clusterissuers 2>/dev/null | wc -l || echo "0")
        if [ "$issuers" -gt 1 ]; then
            success "cert-manager has ClusterIssuers configured"
        else
            log "No ClusterIssuers found (this may be expected for homelab setup)"
        fi
    else
        warning "cert-manager namespace not found - may be disabled"
    fi
}

test_argocd() {
    log "Testing ArgoCD GitOps Engine..."
    
    if kubectl get namespace argocd &> /dev/null; then
        success "ArgoCD namespace exists"
        
        wait_for_pods "argocd" "app.kubernetes.io/name=argocd-server" 180
        
        # Check ArgoCD services
        if kubectl get service argocd-server -n argocd &> /dev/null; then
            success "ArgoCD server service exists"
        fi
        
        # Test ArgoCD web UI accessibility
        log "Testing ArgoCD web UI accessibility..."
        if curl -s -o /dev/null -w "%{http_code}" --connect-timeout 10 "http://${SERVER_IP}:30808" | grep -q "200"; then
            success "ArgoCD web UI is accessible at http://${SERVER_IP}:30808"
        else
            warning "ArgoCD web UI may not be accessible"
        fi
        
        # Check ArgoCD applications
        local apps=$(kubectl get applications -n argocd --no-headers 2>/dev/null | wc -l || echo "0")
        if [ "$apps" -gt 0 ]; then
            success "ArgoCD has $apps application(s) deployed"
            kubectl get applications -n argocd
        else
            log "No ArgoCD applications found (this may be expected for fresh installation)"
        fi
        
        # Show initial admin password
        if kubectl get secret argocd-initial-admin-secret -n argocd &> /dev/null; then
            local password=$(kubectl get secret argocd-initial-admin-secret -n argocd -o jsonpath='{.data.password}' | base64 -d 2>/dev/null || echo "Unable to decode")
            log "ArgoCD admin credentials: admin / $password"
        fi
    else
        warning "ArgoCD namespace not found - may be disabled"
    fi
}

test_overall_health() {
    log "Testing overall infrastructure health..."
    
    # Check node status
    local ready_nodes=$(kubectl get nodes --no-headers | grep " Ready " | wc -l)
    local total_nodes=$(kubectl get nodes --no-headers | wc -l)
    success "$ready_nodes of $total_nodes nodes are Ready"
    
    # Check system pods
    local system_pods=$(kubectl get pods -n kube-system --no-headers | grep -v "Completed" | wc -l)
    local running_system_pods=$(kubectl get pods -n kube-system --no-headers | grep "Running" | wc -l)
    success "$running_system_pods of $system_pods system pods are Running"
    
    # Show NodePort services summary
    log "NodePort services summary:"
    kubectl get services --all-namespaces --no-headers | grep NodePort | while read line; do
        echo "  $line"
    done
}

generate_report() {
    log "Generating infrastructure validation report..."
    
    cat > infrastructure-validation-report.md << EOF
# Infrastructure Validation Report

**Date**: $(date)
**Server**: $SERVER_IP
**Kubernetes Cluster**: $(kubectl config current-context)

## Service Access URLs

| Service | URL | Status |
|---------|-----|--------|
| Traefik Dashboard | http://$SERVER_IP:30900/dashboard/ | $(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 5 "http://$SERVER_IP:30900/dashboard/" || echo "Failed") |
| Harbor Registry | http://$SERVER_IP:30880 | $(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 5 "http://$SERVER_IP:30880" || echo "Failed") |
| ArgoCD Web UI | http://$SERVER_IP:30808 | $(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 5 "http://$SERVER_IP:30808" || echo "Failed") |

## Component Status

### Namespaces
\`\`\`
$(kubectl get namespaces | grep -E "(metallb-system|traefik|harbor|cert-manager|argocd)")
\`\`\`

### Pod Health
\`\`\`
$(kubectl get pods --all-namespaces | grep -E "(metallb-system|traefik|harbor|cert-manager|argocd)")
\`\`\`

### Services
\`\`\`
$(kubectl get services --all-namespaces | grep -E "(metallb-system|traefik|harbor|cert-manager|argocd)" | grep -v "ClusterIP")
\`\`\`

EOF

    success "Validation report generated: infrastructure-validation-report.md"
}

main() {
    echo -e "${BLUE}=== k3s DevOps Pipeline Infrastructure Validation ===${NC}"
    echo -e "${BLUE}Server: $SERVER_IP${NC}"
    echo -e "${BLUE}Timeout: $TIMEOUT seconds${NC}\n"
    
    check_prerequisites
    test_metallb
    test_traefik
    test_harbor
    test_cert_manager
    test_argocd
    test_overall_health
    generate_report
    
    success "Infrastructure validation completed!"
    
    echo -e "\n${YELLOW}=== Quick Access Summary ===${NC}"
    echo -e "${GREEN}Traefik Dashboard:${NC} http://$SERVER_IP:30900/dashboard/"
    echo -e "${GREEN}Harbor Registry:${NC} http://$SERVER_IP:30880"
    echo -e "${GREEN}ArgoCD Web UI:${NC} http://$SERVER_IP:30808"
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi