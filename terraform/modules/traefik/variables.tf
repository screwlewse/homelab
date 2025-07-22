# Traefik Module Variables

variable "chart_version" {
  description = "Traefik Helm chart version"
  type        = string
  default     = "28.3.0"
}

variable "replicas" {
  description = "Number of Traefik replicas"
  type        = number
  default     = 1
}

variable "service_type" {
  description = "Kubernetes service type (LoadBalancer or NodePort)"
  type        = string
  default     = "NodePort"
  
  validation {
    condition     = contains(["LoadBalancer", "NodePort"], var.service_type)
    error_message = "Service type must be either LoadBalancer or NodePort."
  }
}

variable "nodeports" {
  description = "NodePort configuration"
  type = object({
    http      = number
    https     = number
    dashboard = number
  })
  default = {
    http      = 30080
    https     = 30443
    dashboard = 30900
  }
}

variable "dashboard_enabled" {
  description = "Enable Traefik dashboard"
  type        = bool
  default     = true
}

variable "dashboard_insecure" {
  description = "Enable insecure dashboard access (HTTP)"
  type        = bool
  default     = true
}

variable "persistence_enabled" {
  description = "Enable persistent storage for Traefik"
  type        = bool
  default     = true
}

variable "persistence_size" {
  description = "Size of persistent storage"
  type        = string
  default     = "128Mi"
}