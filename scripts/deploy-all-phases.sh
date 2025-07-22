#!/bin/bash

# Complete k3s DevOps Pipeline Deployment
# Automated deployment of all infrastructure phases with Terraform

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
TERRAFORM_DIR="$PROJECT_ROOT/terraform"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

log_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

log_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

log_error() {
    echo -e "${RED}❌ $1${NC}"
}

log_phase() {
    echo -e "${PURPLE}🚀 $1${NC}"
    echo "=================================="
}

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to check service accessibility
check_service() {
    local url=$1
    local name=$2
    local expected_code=${3:-200}
    
    echo -n "  Checking $name ($url)... "
    response=$(curl -s -o /dev/null -w "%{http_code}" "$url" --max-time 10 2>/dev/null || echo "000")
    
    if [[ "$response" == "$expected_code" ]] || [[ "$response" == "302" ]]; then
        log_success "OK ($response)"
        return 0
    else
        log_warning "FAILED ($response, expected $expected_code)"
        return 1
    fi
}

# Function to wait for pods to be ready
wait_for_pods() {
    local namespace=$1
    local timeout=${2:-300}
    
    log_info "Waiting for pods in namespace '$namespace' to be ready (timeout: ${timeout}s)..."
    
    if kubectl wait --for=condition=ready pods --all -n "$namespace" --timeout="${timeout}s" 2>/dev/null; then
        log_success "All pods in '$namespace' are ready"
        return 0
    else
        log_warning "Some pods in '$namespace' may not be ready yet"
        return 1
    fi
}

echo "🎯 k3s DevOps Pipeline - Complete Infrastructure Deployment"
echo "=========================================================="
echo ""

# Pre-flight checks
log_phase "Phase 0: Pre-flight Checks"

# Check required tools
REQUIRED_TOOLS=("kubectl" "terraform" "helm" "curl" "git")
for tool in "${REQUIRED_TOOLS[@]}"; do
    if command_exists "$tool"; then
        log_success "$tool is available"
    else
        log_error "$tool is not installed or not in PATH"
        exit 1
    fi
done

# Check kubeconfig
export KUBECONFIG=${KUBECONFIG:-~/.kube/config}
if ! kubectl cluster-info --request-timeout=10s >/dev/null 2>&1; then
    log_error "Cannot connect to Kubernetes cluster. Check your kubeconfig."
    exit 1
fi
log_success "Kubernetes cluster is accessible"

# Check if we're in a git repository
if ! git rev-parse --git-dir >/dev/null 2>&1; then
    log_error "Not in a git repository"
    exit 1
fi
log_success "Git repository detected"

echo ""

# Phase 1-4: Terraform Infrastructure Deployment
log_phase "Phases 1-4: Infrastructure Deployment (Terraform)"

cd "$TERRAFORM_DIR"

# Initialize Terraform
log_info "Initializing Terraform..."
if terraform init; then
    log_success "Terraform initialized successfully"
else
    log_error "Terraform initialization failed"
    exit 1
fi

# Terraform Plan
log_info "Generating Terraform plan..."
if terraform plan -out=tfplan; then
    log_success "Terraform plan generated successfully"
else
    log_error "Terraform plan failed"
    exit 1
fi

# Terraform Apply
log_info "Applying Terraform configuration..."
if terraform apply -auto-approve tfplan; then
    log_success "Infrastructure deployed successfully via Terraform"
else
    log_error "Terraform apply failed"
    exit 1
fi

# Clean up plan file
rm -f tfplan

echo ""

# Phase 5: Service Verification
log_phase "Phase 5: Service Verification"

# Get Terraform outputs
TERRAFORM_OUTPUTS=$(terraform output -json)

# Extract service URLs
SERVICE_URLS=$(echo "$TERRAFORM_OUTPUTS" | jq -r '.service_urls.value')
CREDENTIALS=$(echo "$TERRAFORM_OUTPUTS" | jq -r '.default_credentials.value')

log_info "Waiting for services to be ready..."
sleep 30

# Check core services
if echo "$SERVICE_URLS" | jq -e '.traefik_dashboard' >/dev/null; then
    TRAEFIK_URL=$(echo "$SERVICE_URLS" | jq -r '.traefik_dashboard')
    check_service "$TRAEFIK_URL" "Traefik Dashboard"
fi

if echo "$SERVICE_URLS" | jq -e '.harbor_registry' >/dev/null; then
    HARBOR_URL=$(echo "$SERVICE_URLS" | jq -r '.harbor_registry')
    check_service "$HARBOR_URL" "Harbor Registry"
fi

if echo "$SERVICE_URLS" | jq -e '.argocd_ui' >/dev/null; then
    ARGOCD_URL=$(echo "$SERVICE_URLS" | jq -r '.argocd_ui')
    check_service "$ARGOCD_URL" "ArgoCD UI"
fi

# Check monitoring services if enabled
if echo "$SERVICE_URLS" | jq -e '.prometheus_ui' >/dev/null; then
    PROMETHEUS_URL=$(echo "$SERVICE_URLS" | jq -r '.prometheus_ui')
    GRAFANA_URL=$(echo "$SERVICE_URLS" | jq -r '.grafana_ui')
    ALERTMANAGER_URL=$(echo "$SERVICE_URLS" | jq -r '.alertmanager_ui')
    
    check_service "$PROMETHEUS_URL" "Prometheus UI" "302"  # Prometheus redirects
    check_service "$GRAFANA_URL" "Grafana Dashboard"
    check_service "$ALERTMANAGER_URL" "AlertManager UI"
fi

echo ""

# Phase 6: Pod Health Check
log_phase "Phase 6: Pod Health Check"

# Check pods in all infrastructure namespaces
NAMESPACES=("metallb-system" "traefik" "cert-manager" "harbor" "argocd")
if echo "$SERVICE_URLS" | jq -e '.prometheus_ui' >/dev/null; then
    NAMESPACES+=("monitoring")
fi

for ns in "${NAMESPACES[@]}"; do
    if kubectl get namespace "$ns" >/dev/null 2>&1; then
        wait_for_pods "$ns" 60
    else
        log_warning "Namespace '$ns' not found - component may be disabled"
    fi
done

echo ""

# Phase 7: Summary and Next Steps
log_phase "Phase 7: Deployment Summary"

echo "🎉 k3s DevOps Pipeline Deployment Complete!"
echo "============================================="
echo ""

log_success "Infrastructure Status: All phases deployed successfully"

echo "📊 Service Access URLs:"
echo "-----------------------"

if echo "$SERVICE_URLS" | jq -e '.traefik_dashboard' >/dev/null; then
    echo "  🌐 Traefik Dashboard: $(echo "$SERVICE_URLS" | jq -r '.traefik_dashboard')"
fi

if echo "$SERVICE_URLS" | jq -e '.harbor_registry' >/dev/null; then
    echo "  🐳 Harbor Registry:   $(echo "$SERVICE_URLS" | jq -r '.harbor_registry')"
fi

if echo "$SERVICE_URLS" | jq -e '.argocd_ui' >/dev/null; then
    echo "  🔄 ArgoCD GitOps:     $(echo "$SERVICE_URLS" | jq -r '.argocd_ui')"
fi

if echo "$SERVICE_URLS" | jq -e '.prometheus_ui' >/dev/null; then
    echo "  📈 Prometheus:        $(echo "$SERVICE_URLS" | jq -r '.prometheus_ui')"
    echo "  📊 Grafana:           $(echo "$SERVICE_URLS" | jq -r '.grafana_ui')"
    echo "  🚨 AlertManager:      $(echo "$SERVICE_URLS" | jq -r '.alertmanager_ui')"
fi

echo ""
echo "🔐 Default Credentials:"
echo "-----------------------"

if echo "$CREDENTIALS" | jq -e '.harbor' >/dev/null; then
    HARBOR_USER=$(echo "$CREDENTIALS" | jq -r '.harbor.username')
    HARBOR_PASS=$(echo "$CREDENTIALS" | jq -r '.harbor.password')
    echo "  Harbor:     $HARBOR_USER / $HARBOR_PASS"
fi

if echo "$CREDENTIALS" | jq -e '.argocd' >/dev/null; then
    echo "  ArgoCD:     admin / <run: kubectl get secret argocd-initial-admin-secret -n argocd -o jsonpath='{.data.password}' | base64 -d>"
fi

if echo "$CREDENTIALS" | jq -e '.grafana' >/dev/null; then
    GRAFANA_USER=$(echo "$CREDENTIALS" | jq -r '.grafana.username')
    GRAFANA_PASS=$(echo "$CREDENTIALS" | jq -r '.grafana.password')
    echo "  Grafana:    $GRAFANA_USER / $GRAFANA_PASS"
fi

echo ""
echo "🔧 Management Commands:"
echo "----------------------"
echo "  # View all resources"
echo "  kubectl get all --all-namespaces"
echo ""
echo "  # Infrastructure management"
echo "  cd $TERRAFORM_DIR"
echo "  terraform plan    # Preview changes"
echo "  terraform apply   # Apply changes"
echo "  terraform destroy # Remove infrastructure"
echo ""
echo "  # Service verification"
echo "  $SCRIPT_DIR/verify-monitoring.sh"

echo ""
log_success "🎯 k3s DevOps Pipeline is ready for production workloads!"

cd "$PROJECT_ROOT"

echo ""
echo "📝 Deployment completed at: $(date)"
echo "🗂️  Working directory: $PROJECT_ROOT"