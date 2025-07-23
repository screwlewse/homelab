# Production Environment Configuration
# k3s DevOps Pipeline

cluster_name = "k3s-devops-prod"
server_ip    = "10.0.0.88"

# MetalLB Configuration
metallb_ip_range = "10.0.0.200-10.0.0.210"

# NodePort Services
nodeport_range = {
  traefik_http      = 30080
  traefik_https     = 30443
  traefik_dashboard = 30900
  harbor            = 30880
  argocd            = 30808
  prometheus        = 30909
  grafana           = 30300
  alertmanager      = 30903
}

# Harbor Configuration (Production)
# NOTE: Use proper secrets management in production
harbor_config = {
  admin_password = "HarborPrd98765!"
  storage_size   = "50Gi"
}

# Monitoring Configuration (Production)
# NOTE: Use proper secrets management in production
monitoring_config = {
  grafana_admin_password  = "grafanaprd789!"
  prometheus_retention    = "30d"
  prometheus_storage_size = "100Gi"
  grafana_storage_size    = "5Gi"
}

# Enable all components for production
enable_components = {
  metallb      = true
  traefik      = true
  harbor       = true
  cert_manager = true
  argocd       = true
  monitoring   = true
}