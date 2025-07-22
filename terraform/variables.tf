# Variables for k3s DevOps Pipeline Infrastructure

variable "kubeconfig_path" {
  description = "Path to kubeconfig file"
  type        = string
  default     = "~/.kube/config"
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
}

variable "metallb_ip_range" {
  description = "IP range for MetalLB load balancer"
  type        = string
  default     = "10.0.0.200-10.0.0.210"
}

variable "nodeport_range" {
  description = "NodePort range configuration"
  type = object({
    traefik_http      = number
    traefik_https     = number
    traefik_dashboard = number
    harbor            = number
    argocd            = number
  })
  default = {
    traefik_http      = 30080
    traefik_https     = 30443
    traefik_dashboard = 30900
    harbor            = 30880
    argocd            = 30808
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

variable "enable_components" {
  description = "Enable/disable infrastructure components"
  type = object({
    metallb      = bool
    traefik      = bool
    harbor       = bool
    cert_manager = bool
    argocd       = bool
  })
  default = {
    metallb      = true
    traefik      = true
    harbor       = true
    cert_manager = true
    argocd       = true
  }
}