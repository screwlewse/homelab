# Outputs for k3s DevOps Pipeline Infrastructure

output "cluster_info" {
  description = "k3s cluster information"
  value = {
    name      = var.cluster_name
    server_ip = var.server_ip
  }
}

output "service_urls" {
  description = "Service access URLs"
  value = merge(
    {
      traefik_dashboard = "http://${var.server_ip}:${var.nodeport_range.traefik_dashboard}/dashboard/"
      traefik_http      = "http://${var.server_ip}:${var.nodeport_range.traefik_http}"
      harbor_registry   = "http://${var.server_ip}:${var.nodeport_range.harbor}"
      argocd_ui         = "http://${var.server_ip}:${var.nodeport_range.argocd}"
    },
    var.enable_components.monitoring ? {
      prometheus_ui   = "http://${var.server_ip}:${var.nodeport_range.prometheus}"
      grafana_ui      = "http://${var.server_ip}:${var.nodeport_range.grafana}"
      alertmanager_ui = "http://${var.server_ip}:${var.nodeport_range.alertmanager}"
    } : {}
  )
}

output "default_credentials" {
  description = "Default service credentials"
  value = merge(
    {
      harbor = {
        username = "admin"
        password = var.harbor_config.admin_password
      }
      argocd = {
        username = "admin"
        password = "Check: kubectl get secret argocd-initial-admin-secret -n argocd -o jsonpath='{.data.password}' | base64 -d"
      }
    },
    var.enable_components.monitoring ? {
      grafana = {
        username = "admin"
        password = var.monitoring_config.grafana_admin_password
      }
    } : {}
  )
  sensitive = true
}

output "metallb_ip_pool" {
  description = "MetalLB IP address pool"
  value = var.metallb_ip_range
}

output "terraform_state_info" {
  description = "Terraform state information"
  value = {
    backend = "local"
    path    = "./terraform.tfstate"
  }
}