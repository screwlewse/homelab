#!/bin/bash

# Verify Phase 4: Monitoring & Observability
# k3s DevOps Pipeline - Monitoring Stack Validation

set -e

echo "🔍 Phase 4 Monitoring Stack Verification"
echo "========================================"

export KUBECONFIG=~/.kube/config

# Function to check HTTP response
check_url() {
    local url=$1
    local name=$2
    local expected_code=${3:-200}
    
    echo -n "  Checking $name ($url)... "
    response=$(curl -s -o /dev/null -w "%{http_code}" "$url" || echo "000")
    
    if [[ "$response" == "$expected_code" ]]; then
        echo "✅ OK ($response)"
        return 0
    else
        echo "❌ FAILED ($response, expected $expected_code)"
        return 1
    fi
}

echo ""
echo "📊 Checking Monitoring Services..."
echo "--------------------------------"

# Check service accessibility
check_url "http://10.0.0.88:30300" "Grafana Dashboard" "200"
check_url "http://10.0.0.88:30909" "Prometheus UI" "302"  # Prometheus redirects
check_url "http://10.0.0.88:30903" "AlertManager UI" "200"

echo ""
echo "🏗️ Checking Pod Status..."
echo "-------------------------"
kubectl get pods -n monitoring --no-headers | while read line; do
    pod_name=$(echo $line | awk '{print $1}')
    status=$(echo $line | awk '{print $3}')
    ready=$(echo $line | awk '{print $2}')
    
    if [[ "$status" == "Running" ]]; then
        echo "  ✅ $pod_name ($status, $ready ready)"
    else
        echo "  ❌ $pod_name ($status, $ready ready)"
    fi
done

echo ""
echo "📈 Checking Prometheus Targets..."
echo "--------------------------------"
target_check=$(curl -s "http://10.0.0.88:30909/api/v1/targets" | grep -o '"health":"up"' | wc -l)
total_targets=$(curl -s "http://10.0.0.88:30909/api/v1/targets" | grep -o '"health":"' | wc -l)
echo "  Healthy targets: $target_check/$total_targets"

if [[ $target_check -gt 0 ]]; then
    echo "  ✅ Prometheus targets are being scraped"
else
    echo "  ❌ No healthy Prometheus targets found"
fi

echo ""
echo "🚨 Checking Alert Rules..."
echo "-------------------------"
alert_rules=$(kubectl get prometheusrules -n monitoring --no-headers | wc -l)
echo "  Alert rule groups configured: $alert_rules"

if [[ $alert_rules -gt 0 ]]; then
    echo "  ✅ Alert rules are configured"
    kubectl get prometheusrules -n monitoring
else
    echo "  ❌ No alert rules found"
fi

echo ""
echo "💾 Checking Persistent Storage..."
echo "-------------------------------"
kubectl get pvc -n monitoring --no-headers | while read line; do
    pvc_name=$(echo $line | awk '{print $1}')
    status=$(echo $line | awk '{print $2}')
    
    if [[ "$status" == "Bound" ]]; then
        echo "  ✅ $pvc_name ($status)"
    else
        echo "  ❌ $pvc_name ($status)"
    fi
done

echo ""
echo "🔧 Service Configuration Summary..."
echo "----------------------------------"
echo "  📊 Prometheus:   http://10.0.0.88:30909"
echo "  📈 Grafana:      http://10.0.0.88:30300 (admin/admin123)"
echo "  🚨 AlertManager: http://10.0.0.88:30903"

echo ""
echo "📋 Resource Usage..."
echo "-------------------"
kubectl top pods -n monitoring 2>/dev/null || echo "  ⚠️  Metrics server not available for resource usage"

echo ""
echo "🎯 Quick Health Check Commands..."
echo "--------------------------------"
echo "  # View all monitoring resources"
echo "  kubectl get all -n monitoring"
echo ""
echo "  # Check Prometheus configuration"  
echo "  curl http://10.0.0.88:30909/api/v1/status/config"
echo ""
echo "  # View active alerts"
echo "  curl http://10.0.0.88:30903/api/v1/alerts"
echo ""
echo "  # Test metric query"
echo "  curl 'http://10.0.0.88:30909/api/v1/query?query=up'"

echo ""
if [[ $target_check -gt 0 && $alert_rules -gt 0 ]]; then
    echo "🎉 Phase 4 Monitoring Stack: ✅ HEALTHY"
    echo "   All monitoring services are operational and collecting metrics!"
else
    echo "⚠️  Phase 4 Monitoring Stack: NEEDS ATTENTION"
    echo "   Some monitoring components may need configuration review."
fi

echo ""
echo "📚 Next Steps:"
echo "  1. Access Grafana dashboard: http://10.0.0.88:30300"
echo "  2. Explore pre-built Kubernetes dashboards"  
echo "  3. Review alert rules and configure notifications"
echo "  4. Consider Phase 5: Log aggregation with Loki"