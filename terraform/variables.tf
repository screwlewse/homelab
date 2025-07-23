# Variables for k3s DevOps Pipeline Infrastructure

variable "kubeconfig_path" {
  description = "Path to kubeconfig file"
  type        = string
  default     = "~/.kube/config"

  validation {
    condition     = can(regex("^.*\\.kube/.*$", var.kubeconfig_path))
    error_message = "The kubeconfig_path must contain '.kube' in the path."
  }
}

variable "cluster_name" {
  description = "Name of the k3s cluster"
  type        = string
  default     = "k3s-devops"
}

variable "server_ip" {
  description = "IP address of the k3s server"
  type        = string
  default     = "10.0.0.88"

  validation {
    condition     = can(regex("^(?:[0-9]{1,3}\\.){3}[0-9]{1,3}$", var.server_ip))
    error_message = "The server_ip must be a valid IPv4 address."
  }
}

variable "metallb_ip_range" {
  description = "IP range for MetalLB load balancer"
  type        = string
  default     = "10.0.0.200-10.0.0.210"

  validation {
    condition     = can(regex("^[0-9]+\\.[0-9]+\\.[0-9]+\\.[0-9]+-[0-9]+\\.[0-9]+\\.[0-9]+\\.[0-9]+$", var.metallb_ip_range))
    error_message = "The metallb_ip_range must be in format: X.X.X.X-Y.Y.Y.Y"
  }
}

variable "nodeport_range" {
  description = "NodePort range configuration"
  type = object({
    traefik_http      = number
    traefik_https     = number
    traefik_dashboard = number
    harbor            = number
    argocd            = number
    prometheus        = number
    grafana           = number
    alertmanager      = number
  })
  default = {
    traefik_http      = 30080
    traefik_https     = 30443
    traefik_dashboard = 30900
    harbor            = 30880
    argocd            = 30808
    prometheus        = 30909
    grafana           = 30300
    alertmanager      = 30903
  }

  validation {
    condition = alltrue([
      for port in values(var.nodeport_range) : port >= 30000 && port <= 32767
    ])
    error_message = "All NodePort values must be between 30000 and 32767."
  }
}

variable "harbor_config" {
  description = "Harbor container registry configuration"
  type = object({
    admin_password = string
    storage_size   = string
  })
  default = {
    admin_password = "Harbor12345"
    storage_size   = "5Gi"
  }
  sensitive = true

  validation {
    condition     = length(var.harbor_config.admin_password) >= 8
    error_message = "Harbor admin password must be at least 8 characters long."
  }

  validation {
    condition     = can(regex("^[0-9]+Gi$", var.harbor_config.storage_size))
    error_message = "Harbor storage size must be in format: XGi (e.g., 5Gi)."
  }
}

variable "argocd_config" {
  description = "ArgoCD configuration"
  type = object({
    server_insecure = bool
  })
  default = {
    server_insecure = true
  }
}

variable "monitoring_config" {
  description = "Monitoring stack configuration"
  type = object({
    grafana_admin_password  = string
    prometheus_retention    = string
    prometheus_storage_size = string
    grafana_storage_size    = string
  })
  default = {
    grafana_admin_password  = "admin123"
    prometheus_retention    = "30d"
    prometheus_storage_size = "20Gi"
    grafana_storage_size    = "2Gi"
  }
  sensitive = true

  validation {
    condition     = length(var.monitoring_config.grafana_admin_password) >= 6
    error_message = "Grafana admin password must be at least 6 characters long."
  }

  validation {
    condition     = can(regex("^[0-9]+[hdm]$", var.monitoring_config.prometheus_retention))
    error_message = "Prometheus retention must be in format: Xd, Xh, or Xm (e.g., 30d)."
  }

  validation {
    condition = alltrue([
      can(regex("^[0-9]+Gi$", var.monitoring_config.prometheus_storage_size)),
      can(regex("^[0-9]+Gi$", var.monitoring_config.grafana_storage_size))
    ])
    error_message = "Storage sizes must be in format: XGi (e.g., 20Gi)."
  }
}

variable "enable_components" {
  description = "Enable/disable infrastructure components"
  type = object({
    metallb      = bool
    traefik      = bool
    harbor       = bool
    cert_manager = bool
    argocd       = bool
    monitoring   = bool
  })
  default = {
    metallb      = true
    traefik      = true
    harbor       = true
    cert_manager = true
    argocd       = true
    monitoring   = true
  }
}