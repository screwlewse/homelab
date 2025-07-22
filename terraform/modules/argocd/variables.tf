# ArgoCD Module Variables

variable "service_type" {
  description = "Kubernetes service type (LoadBalancer or NodePort)"
  type        = string
  default     = "NodePort"
  
  validation {
    condition     = contains(["LoadBalancer", "NodePort"], var.service_type)
    error_message = "Service type must be either LoadBalancer or NodePort."
  }
}

variable "nodeport" {
  description = "NodePort for ArgoCD server service"
  type        = number
  default     = 30808
}

variable "server_insecure" {
  description = "Enable insecure server mode (HTTP)"
  type        = bool
  default     = true
}

variable "enable_dex" {
  description = "Enable Dex OIDC authentication"
  type        = bool
  default     = true
}

variable "enable_applicationset" {
  description = "Enable ApplicationSet controller"
  type        = bool
  default     = true
}