# k3s DevOps Pipeline - Infrastructure Deployment
# This file orchestrates all infrastructure components

# MetalLB Load Balancer
module "metallb" {
  count = var.enable_components.metallb ? 1 : 0
  
  source = "./modules/metallb"
  
  ip_range  = var.metallb_ip_range
  pool_name = "default-pool"
}

# Traefik Ingress Controller
module "traefik" {
  count = var.enable_components.traefik ? 1 : 0
  
  source = "./modules/traefik"
  
  service_type = "NodePort"
  nodeports = {
    http      = var.nodeport_range.traefik_http
    https     = var.nodeport_range.traefik_https
    dashboard = var.nodeport_range.traefik_dashboard
  }
  dashboard_enabled  = true
  dashboard_insecure = true
}

# cert-manager for SSL/TLS certificate management
module "cert_manager" {
  count = var.enable_components.cert_manager ? 1 : 0
  
  source = "./modules/cert-manager"
  
  create_letsencrypt_issuer = false  # Disabled for homelab
  letsencrypt_email        = "admin@k3s.local"
}

# Harbor Container Registry
module "harbor" {
  count = var.enable_components.harbor ? 1 : 0
  
  source = "./modules/harbor"
  
  service_type    = "NodePort"
  nodeport        = var.nodeport_range.harbor
  external_url    = "http://${var.server_ip}:${var.nodeport_range.harbor}"
  admin_password  = var.harbor_config.admin_password
  tls_enabled     = false
  
  storage_sizes = {
    registry    = var.harbor_config.storage_size
    chartmuseum = var.harbor_config.storage_size
    jobservice  = "1Gi"
    database    = "1Gi"
    redis       = "1Gi"
    trivy       = var.harbor_config.storage_size
  }
  
  # Depend on MetalLB for potential LoadBalancer support
  depends_on = [module.metallb]
}

# ArgoCD GitOps Engine
module "argocd" {
  count = var.enable_components.argocd ? 1 : 0
  
  source = "./modules/argocd"
  
  service_type     = "NodePort"
  nodeport         = var.nodeport_range.argocd
  server_insecure  = var.argocd_config.server_insecure
}

# Monitoring Stack (Prometheus + Grafana + AlertManager)
module "monitoring" {
  count = var.enable_components.monitoring ? 1 : 0
  
  source = "./modules/monitoring"
  
  server_ip = var.server_ip
  
  # Service NodePorts
  prometheus_nodeport   = var.nodeport_range.prometheus
  grafana_nodeport      = var.nodeport_range.grafana
  alertmanager_nodeport = var.nodeport_range.alertmanager
  
  # Configuration
  grafana_admin_password = var.monitoring_config.grafana_admin_password
  prometheus_retention   = var.monitoring_config.prometheus_retention
  prometheus_storage_size = var.monitoring_config.prometheus_storage_size
  grafana_storage_size    = var.monitoring_config.grafana_storage_size
  
  # Ensure monitoring deploys after core infrastructure
  depends_on = [
    module.metallb,
    module.traefik,
    module.cert_manager,
    module.harbor,
    module.argocd
  ]
}