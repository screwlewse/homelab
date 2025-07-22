# Monitoring Module Variables

variable "server_ip" {
  description = "Server IP address for service URLs"
  type        = string
  default     = "10.0.0.88"
}

# Prometheus Configuration
variable "prometheus_nodeport" {
  description = "NodePort for Prometheus UI"
  type        = number
  default     = 30909
}

variable "prometheus_retention" {
  description = "Prometheus data retention period"
  type        = string
  default     = "30d"
}

variable "prometheus_retention_size" {
  description = "Maximum size of Prometheus data"
  type        = string
  default     = "10GB"
}

variable "prometheus_storage_size" {
  description = "Storage size for Prometheus"
  type        = string
  default     = "20Gi"
}

variable "prometheus_resources" {
  description = "Resource limits for Prometheus"
  type = object({
    requests = object({
      memory = string
      cpu    = string
    })
    limits = object({
      memory = string
      cpu    = string
    })
  })
  default = {
    requests = {
      memory = "512Mi"
      cpu    = "100m"
    }
    limits = {
      memory = "2Gi"
      cpu    = "1000m"
    }
  }
}

# Grafana Configuration
variable "grafana_nodeport" {
  description = "NodePort for Grafana UI"
  type        = number
  default     = 30300
}

variable "grafana_admin_password" {
  description = "Grafana admin password"
  type        = string
  default     = "admin123"
  sensitive   = true
}

variable "grafana_storage_size" {
  description = "Storage size for Grafana"
  type        = string
  default     = "2Gi"
}

variable "grafana_anonymous_enabled" {
  description = "Enable anonymous access to Grafana"
  type        = bool
  default     = true
}

variable "grafana_resources" {
  description = "Resource limits for Grafana"
  type = object({
    requests = object({
      memory = string
      cpu    = string
    })
    limits = object({
      memory = string
      cpu    = string
    })
  })
  default = {
    requests = {
      memory = "128Mi"
      cpu    = "50m"
    }
    limits = {
      memory = "512Mi"
      cpu    = "500m"
    }
  }
}

# AlertManager Configuration
variable "alertmanager_nodeport" {
  description = "NodePort for AlertManager UI"
  type        = number
  default     = 30903
}

variable "alertmanager_storage_size" {
  description = "Storage size for AlertManager"
  type        = string
  default     = "2Gi"
}

variable "alertmanager_resources" {
  description = "Resource limits for AlertManager"
  type = object({
    requests = object({
      memory = string
      cpu    = string
    })
    limits = object({
      memory = string
      cpu    = string
    })
  })
  default = {
    requests = {
      memory = "64Mi"
      cpu    = "25m"
    }
    limits = {
      memory = "256Mi"
      cpu    = "200m"
    }
  }
}

# Additional Service Monitors
variable "additional_service_monitors" {
  description = "Additional service monitors for infrastructure components"
  type = list(object({
    name = string
    selector = object({
      matchLabels = map(string)
    })
    endpoints = list(object({
      port = string
      path = optional(string, "/metrics")
    }))
  }))
  default = [
    {
      name = "traefik-metrics"
      selector = {
        matchLabels = {
          "app.kubernetes.io/name" = "traefik"
        }
      }
      endpoints = [
        {
          port = "traefik"
          path = "/metrics"
        }
      ]
    }
  ]
}