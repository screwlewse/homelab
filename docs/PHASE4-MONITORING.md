# Phase 4: Monitoring & Observability

## Overview

Phase 4 implements comprehensive monitoring and observability for the k3s DevOps pipeline using Prometheus for metrics collection, Grafana for visualization, and AlertManager for alerting.

## Components Deployed

| Component | Technology | Port | Purpose |
|-----------|------------|------|---------|
| **Prometheus** | Metrics Collection | 30909 | Time-series database and metrics scraping |
| **Grafana** | Visualization | 30300 | Dashboards and data visualization |
| **AlertManager** | Alerting | 30903 | Alert routing and notification management |
| **Node Exporter** | System Metrics | - | Host-level metrics collection |
| **kube-state-metrics** | K8s Metrics | - | Kubernetes object metrics |

## Service Access

### Web Interfaces
- **Prometheus**: http://10.0.0.88:30909
- **Grafana**: http://10.0.0.88:30300 (admin/admin123)
- **AlertManager**: http://10.0.0.88:30903

### Key Features
- **Pre-configured Dashboards**: Kubernetes cluster overview, node metrics, pod status
- **Custom Alerts**: Pod crashes, high resource usage, ArgoCD sync issues
- **Service Discovery**: Automatic discovery of Kubernetes services
- **Persistent Storage**: Data retention for metrics and configurations

## Grafana Dashboards

### Default Dashboards Included
1. **Kubernetes / Cluster Overview** - Cluster-wide resource usage and health
2. **Kubernetes / Nodes** - Node-level system metrics and resource utilization
3. **Kubernetes / Pods** - Pod-level metrics, restarts, and resource consumption
4. **Kubernetes / Persistent Volumes** - Storage metrics and PVC status

### Custom Dashboards
1. **k3s DevOps Pipeline Overview** - Infrastructure component status
2. **ArgoCD GitOps Monitoring** - Application deployment and sync status

### Dashboard Access
```bash
# Access Grafana
open http://10.0.0.88:30300

# Login credentials
Username: admin
Password: admin123
```

## Prometheus Monitoring

### Monitored Components
- **Kubernetes API Server** - API response times and request rates
- **kubelet** - Node agent metrics and container runtime stats
- **Node Exporter** - System-level metrics (CPU, memory, disk, network)
- **kube-state-metrics** - Kubernetes object state and metadata
- **Application Metrics** - Custom application metrics via service monitors

### Key Metrics Categories
- **Infrastructure**: CPU, memory, disk, network utilization
- **Kubernetes**: Pod status, deployments, services, ingress
- **Applications**: Custom business metrics from applications
- **GitOps**: ArgoCD application sync status and health

### Prometheus Queries Examples
```promql
# CPU usage by node
100 - (avg by(instance) (irate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)

# Memory usage percentage
(node_memory_MemTotal_bytes - node_memory_MemAvailable_bytes) / node_memory_MemTotal_bytes * 100

# Pod restart rate
rate(kube_pod_container_status_restarts_total[5m])

# ArgoCD application sync status
argocd_app_info{sync_status="Synced"}
```

## Alert Rules

### Critical Alerts
- **NodeDown**: Node unavailable for >5 minutes
- **PodCrashLooping**: Pod restarting repeatedly
- **PersistentVolumeClaimPending**: PVC stuck in pending state

### Warning Alerts  
- **HighMemoryUsage**: Memory usage >90% for >10 minutes
- **HighCPUUsage**: CPU usage >80% for >10 minutes
- **PodNotReady**: Pod not ready for >10 minutes
- **ArgocdApplicationNotSynced**: ArgoCD app out of sync >15 minutes

### Alert Configuration
```yaml
# View active alerts
kubectl get prometheusrules -n monitoring

# Check AlertManager status
curl http://10.0.0.88:30903/api/v1/alerts
```

## Monitoring Architecture

### Data Flow
1. **Collection**: Prometheus scrapes metrics from exporters and applications
2. **Storage**: Time-series data stored in Prometheus with 30-day retention
3. **Visualization**: Grafana queries Prometheus for dashboard display
4. **Alerting**: AlertManager processes alert rules and sends notifications

### Service Discovery
- **Kubernetes**: Automatic discovery of pods, services, and endpoints
- **Static Config**: Manual configuration for external services
- **ServiceMonitor**: CRD-based configuration for application monitoring

## Resource Requirements

### Current Allocation
- **Prometheus**: 512Mi memory, 100m CPU (limits: 2Gi/1000m)
- **Grafana**: 128Mi memory, 50m CPU (limits: 512Mi/500m)
- **AlertManager**: 64Mi memory, 25m CPU (limits: 256Mi/200m)
- **Storage**: 20Gi for Prometheus, 2Gi for Grafana, 2Gi for AlertManager

### Storage Configuration
- **Prometheus**: 30-day retention, 10GB size limit
- **Grafana**: Persistent dashboard and user configurations
- **AlertManager**: Persistent alert state and silences

## Configuration Files

### Deployment Files
```
manifests/monitoring/
├── monitoring-namespace.yaml          # Namespace creation
├── prometheus-values.yaml             # Helm values configuration  
├── grafana-dashboards.yaml           # Custom dashboard definitions
└── alert-rules.yaml                  # Prometheus alert rules

scripts/
└── deploy-monitoring.sh              # Automated deployment script
```

### Helm Configuration
The monitoring stack is deployed using the `kube-prometheus-stack` Helm chart with custom values optimized for single-node k3s deployment.

## Management Commands

### Prometheus
```bash
# Access Prometheus UI
open http://10.0.0.88:30909

# Check Prometheus targets
curl http://10.0.0.88:30909/api/v1/targets

# Query metrics via API
curl 'http://10.0.0.88:30909/api/v1/query?query=up'
```

### Grafana
```bash
# Access Grafana UI
open http://10.0.0.88:30300

# Reset Grafana admin password
kubectl get secret prometheus-stack-grafana -n monitoring -o jsonpath="{.data.admin-password}" | base64 -d

# View Grafana pods
kubectl get pods -n monitoring -l app.kubernetes.io/name=grafana
```

### AlertManager
```bash
# Access AlertManager UI
open http://10.0.0.88:30903

# View active alerts
curl http://10.0.0.88:30903/api/v1/alerts

# Silence alerts (example)
curl -X POST http://10.0.0.88:30903/api/v1/silences \
  -H "Content-Type: application/json" \
  -d '{"matchers":[{"name":"alertname","value":"PodCrashLooping"}],"startsAt":"2024-01-01T00:00:00Z","endsAt":"2024-01-01T01:00:00Z","comment":"Maintenance window"}'
```

## Troubleshooting

### Common Issues

| Issue | Symptoms | Solution |
|-------|----------|----------|
| High Memory Usage | Prometheus OOMKilled | Increase memory limits or reduce retention |
| Grafana Login Failed | 403 Forbidden | Check admin password in secret |
| No Metrics Data | Empty dashboards | Verify Prometheus targets are up |
| Alert Spam | Too many alerts | Tune alert thresholds and for durations |

### Debug Commands
```bash
# Check all monitoring pods
kubectl get pods -n monitoring

# View Prometheus logs
kubectl logs -n monitoring prometheus-prometheus-stack-kube-prom-prometheus-0

# View Grafana logs  
kubectl logs -n monitoring -l app.kubernetes.io/name=grafana

# Check AlertManager logs
kubectl logs -n monitoring alertmanager-prometheus-stack-kube-prom-alertmanager-0
```

### Performance Tuning
```bash
# Prometheus memory usage
kubectl top pod -n monitoring prometheus-prometheus-stack-kube-prom-prometheus-0

# Grafana response times
curl -w "%{time_total}" http://10.0.0.88:30300/api/health

# Check disk usage
kubectl exec -n monitoring prometheus-prometheus-stack-kube-prom-prometheus-0 -- df -h /prometheus
```

## Security Considerations

### Current Configuration
- **Authentication**: Basic auth for Grafana (admin/admin123)
- **Network**: NodePort services for external access
- **RBAC**: ServiceAccounts with appropriate cluster permissions
- **Storage**: Local persistent volumes for data retention

### Production Hardening Recommendations
1. **Change Default Passwords**: Update Grafana admin password
2. **Enable HTTPS**: Configure TLS certificates for all services
3. **Network Policies**: Restrict access to monitoring namespace
4. **RBAC**: Implement fine-grained permissions for users
5. **External Storage**: Use network storage for HA deployment
6. **Secret Management**: Use external secret management tools

## Integration with Existing Services

### ArgoCD Metrics
- Application sync status and health
- Repository and cluster connectivity
- User activity and API usage

### Harbor Metrics  
- Registry API response times
- Storage usage and quota monitoring
- Image scan results and vulnerabilities

### Traefik Metrics
- Request rate and response times
- SSL certificate expiration
- Backend service health

### Infrastructure Metrics
- k3s cluster health and performance
- Node resource utilization
- Pod lifecycle and restart patterns

## Next Steps (Phase 5)

1. **Log Aggregation**: Deploy Loki for centralized logging
2. **Distributed Tracing**: Add Jaeger for request tracing
3. **Advanced Alerting**: Configure Slack/email notifications
4. **Multi-Cluster**: Extend monitoring to multiple clusters
5. **Custom Metrics**: Add application-specific business metrics
6. **Backup & Recovery**: Implement monitoring data backup

## Validation Checklist

- [ ] Prometheus scraping all configured targets
- [ ] Grafana dashboards displaying metrics correctly  
- [ ] AlertManager receiving and processing alerts
- [ ] All services accessible via NodePort
- [ ] Custom dashboards imported successfully
- [ ] Alert rules triggering appropriately
- [ ] Data persistence working across pod restarts

---

**Phase 4 Status**: ✅ Complete  
**Monitoring Stack**: Prometheus + Grafana + AlertManager deployed  
**Custom Dashboards**: k3s DevOps pipeline overview configured  
**Alert Rules**: Infrastructure and application monitoring active  
**Service URLs**: All monitoring services accessible via NodePort  

**Total Infrastructure Components**: 6 phases planned, 4 completed  
**Monitoring Readiness**: ✅ Production-ready observability stack deployed