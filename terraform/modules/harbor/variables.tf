# Harbor Module Variables

variable "chart_version" {
  description = "Harbor Helm chart version"
  type        = string
  default     = "1.13.0"
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

variable "nodeport" {
  description = "NodePort for Harbor service"
  type        = number
  default     = 30880
}

variable "external_url" {
  description = "External URL for Harbor"
  type        = string
}

variable "admin_password" {
  description = "Harbor admin password"
  type        = string
  sensitive   = true
}

variable "tls_enabled" {
  description = "Enable TLS for Harbor"
  type        = bool
  default     = false
}

variable "persistence_enabled" {
  description = "Enable persistent storage"
  type        = bool
  default     = true
}

variable "storage_class" {
  description = "Storage class for persistent volumes"
  type        = string
  default     = "local-path"
}

variable "storage_sizes" {
  description = "Storage sizes for different components"
  type = object({
    registry    = string
    chartmuseum = string
    jobservice  = string
    database    = string
    redis       = string
    trivy       = string
  })
  default = {
    registry    = "5Gi"
    chartmuseum = "5Gi"
    jobservice  = "1Gi"
    database    = "1Gi"
    redis       = "1Gi"
    trivy       = "5Gi"
  }
}

variable "resource_limits" {
  description = "Resource limits for Harbor components"
  type = object({
    core = object({
      resources = object({
        requests = object({
          memory = string
          cpu    = string
        })
        limits = object({
          memory = string
          cpu    = string
        })
      })
    })
    jobservice = object({
      resources = object({
        requests = object({
          memory = string
          cpu    = string
        })
        limits = object({
          memory = string
          cpu    = string
        })
      })
    })
    registry = object({
      resources = object({
        requests = object({
          memory = string
          cpu    = string
        })
        limits = object({
          memory = string
          cpu    = string
        })
      })
    })
    trivy = object({
      resources = object({
        requests = object({
          memory = string
          cpu    = string
        })
        limits = object({
          memory = string
          cpu    = string
        })
      })
    })
  })
  default = {
    core = {
      resources = {
        requests = {
          memory = "256Mi"
          cpu    = "100m"
        }
        limits = {
          memory = "512Mi"
          cpu    = "500m"
        }
      }
    }
    jobservice = {
      resources = {
        requests = {
          memory = "256Mi"
          cpu    = "100m"
        }
        limits = {
          memory = "512Mi"
          cpu    = "500m"
        }
      }
    }
    registry = {
      resources = {
        requests = {
          memory = "256Mi"
          cpu    = "100m"
        }
        limits = {
          memory = "512Mi"
          cpu    = "500m"
        }
      }
    }
    trivy = {
      resources = {
        requests = {
          memory = "512Mi"
          cpu    = "200m"
        }
        limits = {
          memory = "1Gi"
          cpu    = "1"
        }
      }
    }
  }
}

variable "enable_notary" {
  description = "Enable Notary for image signing"
  type        = bool
  default     = false
}

variable "enable_metrics" {
  description = "Enable Harbor metrics"
  type        = bool
  default     = false
}