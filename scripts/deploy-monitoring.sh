#!/bin/bash

# Deploy Monitoring Stack (Prometheus + Grafana)
# k3s DevOps Pipeline - Phase 4

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

echo "🚀 Starting Phase 4: Monitoring & Observability Deployment"
echo "================================================="

# Check if kubectl is available
if ! command -v kubectl &> /dev/null; then
    echo "❌ kubectl is not installed or not in PATH"
    exit 1
fi

# Check if helm is available
if ! command -v helm &> /dev/null; then
    echo "❌ Helm is not installed. Installing Helm..."
    curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
fi

echo "📋 Checking cluster connection..."
kubectl cluster-info --request-timeout=10s

echo "📦 Creating monitoring namespace..."
kubectl apply -f "$PROJECT_ROOT/manifests/monitoring/monitoring-namespace.yaml"

echo "📊 Adding Prometheus Community Helm repository..."
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

echo "🔍 Installing kube-prometheus-stack..."
helm upgrade --install prometheus-stack prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --values "$PROJECT_ROOT/manifests/monitoring/prometheus-values.yaml" \
  --wait \
  --timeout 10m

echo "⏳ Waiting for all pods to be ready..."
kubectl wait --for=condition=ready pods --all -n monitoring --timeout=300s

echo "🎯 Checking deployment status..."
kubectl get pods -n monitoring
kubectl get services -n monitoring

echo ""
echo "🎉 Monitoring Stack Deployment Complete!"
echo "=========================================="
echo ""
echo "📊 Service URLs:"
echo "  Prometheus:   http://10.0.0.88:30909"
echo "  Grafana:      http://10.0.0.88:30300 (admin/admin123)"
echo "  AlertManager: http://10.0.0.88:30903"
echo ""
echo "🔧 Useful Commands:"
echo "  kubectl get all -n monitoring"
echo "  kubectl logs -n monitoring -l app.kubernetes.io/name=prometheus"
echo "  kubectl logs -n monitoring -l app.kubernetes.io/name=grafana"
echo ""
echo "📈 Next Steps:"
echo "  1. Access Grafana dashboard at http://10.0.0.88:30300"
echo "  2. Import additional dashboards for ArgoCD, Harbor, Traefik"
echo "  3. Configure alert rules for production monitoring"
echo "  4. Set up log aggregation with Loki (optional)"