# Harbor Container Registry Terraform Module

resource "kubernetes_namespace" "harbor" {
  metadata {
    name = "harbor"
    labels = {
      name = "harbor"
    }
  }
}

# Harbor Helm repository
resource "helm_release" "harbor" {
  name       = "harbor"
  repository = "https://helm.goharbor.io"
  chart      = "harbor"
  namespace  = kubernetes_namespace.harbor.metadata[0].name
  version    = var.chart_version

  values = [
    yamlencode({
      expose = {
        type = var.service_type
        nodePort = var.service_type == "NodePort" ? {
          name = "harbor"
          ports = {
            http = {
              port     = 80
              nodePort = var.nodeport
            }
          }
        } : null
        tls = {
          enabled = var.tls_enabled
        }
      }

      externalURL = var.external_url

      # Use internal database and redis for single-node setup
      database = {
        type = "internal"
        internal = {
          password = var.admin_password
        }
      }
      
      redis = {
        type = "internal"
        internal = {
          password = "${var.admin_password}-redis"
        }
      }

      # Storage configuration
      persistence = {
        enabled          = var.persistence_enabled
        resourcePolicy   = "keep"
        persistentVolumeClaim = {
          registry = {
            existingClaim = ""
            storageClass  = var.storage_class
            size          = var.storage_sizes.registry
          }
          chartmuseum = {
            existingClaim = ""
            storageClass  = var.storage_class
            size          = var.storage_sizes.chartmuseum
          }
          jobservice = {
            jobLog = {
              existingClaim = ""
              storageClass  = var.storage_class
              size          = var.storage_sizes.jobservice
            }
          }
          database = {
            existingClaim = ""
            storageClass  = var.storage_class
            size          = var.storage_sizes.database
          }
          redis = {
            existingClaim = ""
            storageClass  = var.storage_class
            size          = var.storage_sizes.redis
          }
          trivy = {
            existingClaim = ""
            storageClass  = var.storage_class
            size          = var.storage_sizes.trivy
          }
        }
      }

      # Harbor admin password
      harborAdminPassword = var.admin_password

      # Disable internal TLS for development
      internalTLS = {
        enabled = false
      }

      # Resource limits for single node
      core = var.resource_limits.core
      jobservice = var.resource_limits.jobservice
      registry = var.resource_limits.registry
      trivy = var.resource_limits.trivy

      # Optional components
      notary = {
        enabled = var.enable_notary
      }
      
      metrics = {
        enabled = var.enable_metrics
      }
    })
  ]

  timeout = 600
}