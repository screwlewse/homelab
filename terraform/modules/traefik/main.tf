# Traefik Ingress Controller Terraform Module

resource "kubernetes_namespace" "traefik" {
  metadata {
    name = "traefik"
    labels = {
      name = "traefik"
    }
  }
}

# Traefik Helm repository
resource "helm_release" "traefik" {
  name       = "traefik"
  repository = "https://traefik.github.io/charts"
  chart      = "traefik"
  namespace  = kubernetes_namespace.traefik.metadata[0].name
  version    = var.chart_version

  values = [
    yamlencode({
      deployment = {
        replicas = var.replicas
      }
      
      service = {
        type = var.service_type
      }

      ports = {
        web = {
          port     = 80
          nodePort = var.service_type == "NodePort" ? var.nodeports.http : null
          expose = {
            default = true
          }
        }
        websecure = {
          port     = 443  
          nodePort = var.service_type == "NodePort" ? var.nodeports.https : null
          expose = {
            default = true
          }
        }
        traefik = {
          port     = 9000
          nodePort = var.service_type == "NodePort" ? var.nodeports.dashboard : null
          expose = {
            default = true
          }
        }
      }

      ingressRoute = {
        dashboard = {
          enabled = var.dashboard_enabled
        }
      }

      api = {
        dashboard = var.dashboard_enabled
        insecure  = var.dashboard_insecure
      }

      entryPoints = {
        web = {
          address = ":80"
        }
        websecure = {
          address = ":443"
        }
        traefik = {
          address = ":9000"
        }
      }

      persistence = {
        enabled    = var.persistence_enabled
        accessMode = "ReadWriteOnce"
        size       = var.persistence_size
      }

      globalArguments = [
        "--global.checknewversion=false",
        "--global.sendanonymoususage=false"
      ]
    })
  ]

  timeout = 600
}