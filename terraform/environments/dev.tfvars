# Development Environment Configuration
# k3s DevOps Pipeline

cluster_name = "k3s-devops-dev"
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

# Harbor Configuration (Development)
harbor_config = {
  admin_password = "HarborDev12345"
  storage_size   = "5Gi"
}

# Monitoring Configuration (Development)
monitoring_config = {
  grafana_admin_password  = "grafanadev123"
  prometheus_retention    = "7d"
  prometheus_storage_size = "10Gi"
  grafana_storage_size    = "1Gi"
}

# Enable all components for development
enable_components = {
  metallb      = true
  traefik      = true
  harbor       = true
  cert_manager = true
  argocd       = true
  monitoring   = true
}