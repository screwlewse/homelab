#!/bin/bash

# Deploy Monitoring Stack (Prometheus + Grafana)
# k3s DevOps Pipeline - Phase 4

set -euo pipefail
IFS=$'\n\t'

# Enable debug mode if DEBUG is set
[[ "${DEBUG:-}" == "true" ]] && set -x

# Script metadata
readonly SCRIPT_NAME=$(basename "${BASH_SOURCE[0]}")
readonly SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

# Logging functions
log() { echo "[$(date +'%Y-%m-%d %H:%M:%S')] [$SCRIPT_NAME] $*"; }
error() { log "ERROR: $*" >&2; exit 1; }
warn() { log "WARNING: $*" >&2; }
info() { log "INFO: $*"; }

# Trap errors
trap 'error "Script failed on line $LINENO"' ERR

PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Validate required files exist
[[ -f "$PROJECT_ROOT/manifests/monitoring/monitoring-namespace.yaml" ]] || error "monitoring-namespace.yaml not found"
[[ -f "$PROJECT_ROOT/manifests/monitoring/prometheus-values.yaml" ]] || error "prometheus-values.yaml not found"

info "🚀 Starting Phase 4: Monitoring & Observability Deployment"
info "================================================="

# Check prerequisites
info "Checking prerequisites..."
command -v kubectl &> /dev/null || error "kubectl is not installed or not in PATH"

# Check if helm is available
if ! command -v helm &> /dev/null; then
    warn "Helm is not installed. Installing Helm..."
    # Download and verify Helm installer
    HELM_INSTALLER_URL="https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3"
    HELM_INSTALLER_SCRIPT="/tmp/get-helm-3.sh"
    
    curl -fsSL "$HELM_INSTALLER_URL" -o "$HELM_INSTALLER_SCRIPT" || error "Failed to download Helm installer"
    chmod +x "$HELM_INSTALLER_SCRIPT"
    "$HELM_INSTALLER_SCRIPT" || error "Failed to install Helm"
    rm -f "$HELM_INSTALLER_SCRIPT"
fi

info "📋 Checking cluster connection..."
kubectl cluster-info --request-timeout=10s || error "Failed to connect to Kubernetes cluster"

info "📦 Creating monitoring namespace..."
kubectl apply -f "$PROJECT_ROOT/manifests/monitoring/monitoring-namespace.yaml" || error "Failed to create monitoring namespace"

info "📊 Adding Prometheus Community Helm repository..."
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts || error "Failed to add Prometheus Helm repository"
helm repo update || error "Failed to update Helm repositories"

info "🔍 Installing kube-prometheus-stack..."
helm upgrade --install prometheus-stack prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --values "$PROJECT_ROOT/manifests/monitoring/prometheus-values.yaml" \
  --wait \
  --timeout 10m || error "Failed to install kube-prometheus-stack"

info "⏳ Waiting for all pods to be ready..."
kubectl wait --for=condition=ready pods --all -n monitoring --timeout=300s || warn "Some pods may not be ready yet"

info "🎯 Checking deployment status..."
kubectl get pods -n monitoring || warn "Failed to get pod status"
kubectl get services -n monitoring || warn "Failed to get service status"

info ""
info "🎉 Monitoring Stack Deployment Complete!"
info "=========================================="
info ""
info "📊 Service URLs:"
info "  Prometheus:   http://10.0.0.88:30909"
info "  Grafana:      http://10.0.0.88:30300 (admin/admin123)"
info "  AlertManager: http://10.0.0.88:30903"
info ""
info "🔧 Useful Commands:"
info "  kubectl get all -n monitoring"
info "  kubectl logs -n monitoring -l app.kubernetes.io/name=prometheus"
info "  kubectl logs -n monitoring -l app.kubernetes.io/name=grafana"
info ""
info "📈 Next Steps:"
info "  1. Access Grafana dashboard at http://10.0.0.88:30300"
info "  2. Import additional dashboards for ArgoCD, Harbor, Traefik"
info "  3. Configure alert rules for production monitoring"
info "  4. Set up log aggregation with Loki (optional)"