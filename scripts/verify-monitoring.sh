#!/bin/bash

# Verify Phase 4: Monitoring & Observability
# k3s DevOps Pipeline - Monitoring Stack Validation

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

info "🔍 Phase 4 Monitoring Stack Verification"
info "========================================"

# Validate KUBECONFIG
export KUBECONFIG="${KUBECONFIG:-$HOME/.kube/config}"
[[ -f "$KUBECONFIG" ]] || error "KUBECONFIG file not found: $KUBECONFIG"

# Function to check HTTP response
check_url() {
    local url="$1"
    local name="$2"
    local expected_code="${3:-200}"
    
    echo -n "  Checking $name ($url)... "
    response=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 5 --max-time 10 "$url" || echo "000")
    
    if [[ "$response" == "$expected_code" ]]; then
        echo "✅ OK ($response)"
        return 0
    else
        echo "❌ FAILED ($response, expected $expected_code)"
        return 1
    fi
}

info ""
info "📊 Checking Monitoring Services..."
info "--------------------------------"

# Check service accessibility
check_url "http://10.0.0.88:30300" "Grafana Dashboard" "200"
check_url "http://10.0.0.88:30909" "Prometheus UI" "302"  # Prometheus redirects
check_url "http://10.0.0.88:30903" "AlertManager UI" "200"

info ""
info "🏗️ Checking Pod Status..."
info "-------------------------"
kubectl get pods -n monitoring --no-headers | while read -r line; do
    pod_name=$(echo "$line" | awk '{print $1}')
    status=$(echo "$line" | awk '{print $3}')
    ready=$(echo "$line" | awk '{print $2}')
    
    if [[ "$status" == "Running" ]]; then
        echo "  ✅ $pod_name ($status, $ready ready)"
    else
        echo "  ❌ $pod_name ($status, $ready ready)"
    fi
done

info ""
info "📈 Checking Prometheus Targets..."
info "--------------------------------"
# Fetch targets once to avoid multiple API calls
targets_json=$(curl -s --connect-timeout 5 --max-time 10 "http://10.0.0.88:30909/api/v1/targets" || echo '{}')
target_check=$(echo "$targets_json" | grep -o '"health":"up"' | wc -l || echo 0)
total_targets=$(echo "$targets_json" | grep -o '"health":"' | wc -l || echo 0)
info "  Healthy targets: $target_check/$total_targets"

if [[ $target_check -gt 0 ]]; then
    echo "  ✅ Prometheus targets are being scraped"
else
    echo "  ❌ No healthy Prometheus targets found"
fi

info ""
info "🚨 Checking Alert Rules..."
info "-------------------------"
alert_rules=$(kubectl get prometheusrules -n monitoring --no-headers 2>/dev/null | wc -l || echo 0)
info "  Alert rule groups configured: $alert_rules"

if [[ $alert_rules -gt 0 ]]; then
    echo "  ✅ Alert rules are configured"
    kubectl get prometheusrules -n monitoring
else
    echo "  ❌ No alert rules found"
fi

info ""
info "💾 Checking Persistent Storage..."
info "-------------------------------"
kubectl get pvc -n monitoring --no-headers 2>/dev/null | while read -r line; do
    pvc_name=$(echo "$line" | awk '{print $1}')
    status=$(echo "$line" | awk '{print $2}')
    
    if [[ "$status" == "Bound" ]]; then
        echo "  ✅ $pvc_name ($status)"
    else
        echo "  ❌ $pvc_name ($status)"
    fi
done

info ""
info "🔧 Service Configuration Summary..."
info "----------------------------------"
info "  📊 Prometheus:   http://10.0.0.88:30909"
info "  📈 Grafana:      http://10.0.0.88:30300 (admin/admin123)"
info "  🚨 AlertManager: http://10.0.0.88:30903"

info ""
info "📋 Resource Usage..."
info "-------------------"
kubectl top pods -n monitoring 2>/dev/null || warn "Metrics server not available for resource usage"

info ""
info "🎯 Quick Health Check Commands..."
info "--------------------------------"
info "  # View all monitoring resources"
info "  kubectl get all -n monitoring"
info ""
info "  # Check Prometheus configuration"  
info "  curl http://10.0.0.88:30909/api/v1/status/config"
info ""
info "  # View active alerts"
info "  curl http://10.0.0.88:30903/api/v1/alerts"
info ""
info "  # Test metric query"
info "  curl 'http://10.0.0.88:30909/api/v1/query?query=up'"

info ""
if [[ $target_check -gt 0 && $alert_rules -gt 0 ]]; then
    info "🎉 Phase 4 Monitoring Stack: ✅ HEALTHY"
    info "   All monitoring services are operational and collecting metrics!"
else
    warn "Phase 4 Monitoring Stack: NEEDS ATTENTION"
    warn "   Some monitoring components may need configuration review."
fi

info ""
info "📚 Next Steps:"
info "  1. Access Grafana dashboard: http://10.0.0.88:30300"
info "  2. Explore pre-built Kubernetes dashboards"  
info "  3. Review alert rules and configure notifications"
info "  4. Consider Phase 5: Log aggregation with Loki"