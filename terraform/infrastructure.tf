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