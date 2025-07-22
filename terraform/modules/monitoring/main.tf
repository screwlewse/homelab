# Monitoring Stack Terraform Module

terraform {
  required_providers {
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.11"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.23"
    }
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = "~> 1.14"
    }
  }
}

# Create monitoring namespace
resource "kubernetes_namespace" "monitoring" {
  metadata {
    name = "monitoring"
    labels = {
      name       = "monitoring"
      monitoring = "enabled"
    }
  }
}

# Deploy kube-prometheus-stack via Helm
resource "helm_release" "prometheus_stack" {
  name       = "prometheus-stack"
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "kube-prometheus-stack"
  namespace  = kubernetes_namespace.monitoring.metadata[0].name
  
  timeout = 600
  wait    = true

  values = [
    yamlencode({
      nameOverride     = ""
      fullnameOverride = ""

      # Prometheus configuration
      prometheus = {
        prometheusSpec = {
          replicas    = 1
          retention   = var.prometheus_retention
          retentionSize = var.prometheus_retention_size
          storageSpec = {
            volumeClaimTemplate = {
              spec = {
                accessModes = ["ReadWriteOnce"]
                resources = {
                  requests = {
                    storage = var.prometheus_storage_size
                  }
                }
              }
            }
          }
          resources = {
            requests = {
              memory = var.prometheus_resources.requests.memory
              cpu    = var.prometheus_resources.requests.cpu
            }
            limits = {
              memory = var.prometheus_resources.limits.memory
              cpu    = var.prometheus_resources.limits.cpu
            }
          }
          nodeSelector = {
            "kubernetes.io/os" = "linux"
          }
        }
        service = {
          type     = "NodePort"
          nodePort = var.prometheus_nodeport
        }
      }

      # Grafana configuration
      grafana = {
        enabled       = true
        adminPassword = var.grafana_admin_password
        
        service = {
          type     = "NodePort"
          nodePort = var.grafana_nodeport
        }
        
        persistence = {
          enabled     = true
          size        = var.grafana_storage_size
          accessModes = ["ReadWriteOnce"]
        }
        
        resources = {
          requests = {
            memory = var.grafana_resources.requests.memory
            cpu    = var.grafana_resources.requests.cpu
          }
          limits = {
            memory = var.grafana_resources.limits.memory
            cpu    = var.grafana_resources.limits.cpu
          }
        }
        
        defaultDashboardsEnabled = true
        
        "grafana.ini" = {
          server = {
            domain   = "${var.server_ip}:${var.grafana_nodeport}"
            root_url = "http://${var.server_ip}:${var.grafana_nodeport}"
          }
          security = {
            allow_embedding = true
          }
          "auth.anonymous" = {
            enabled  = var.grafana_anonymous_enabled
            org_role = "Viewer"
          }
        }
      }

      # AlertManager configuration
      alertmanager = {
        alertmanagerSpec = {
          replicas = 1
          storage = {
            volumeClaimTemplate = {
              spec = {
                accessModes = ["ReadWriteOnce"]
                resources = {
                  requests = {
                    storage = var.alertmanager_storage_size
                  }
                }
              }
            }
          }
          resources = {
            requests = {
              memory = var.alertmanager_resources.requests.memory
              cpu    = var.alertmanager_resources.requests.cpu
            }
            limits = {
              memory = var.alertmanager_resources.limits.memory
              cpu    = var.alertmanager_resources.limits.cpu
            }
          }
        }
        service = {
          type     = "NodePort"
          nodePort = var.alertmanager_nodeport
        }
      }

      # Node Exporter
      nodeExporter = {
        enabled = true
      }

      # kube-state-metrics
      kubeStateMetrics = {
        enabled = true
      }

      # Prometheus Operator
      prometheusOperator = {
        enabled = true
        resources = {
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

      # Component toggles optimized for single-node k3s
      kubeApiServer = {
        enabled = true
      }
      kubelet = {
        enabled = true
      }
      kubeControllerManager = {
        enabled = false  # Not accessible in k3s
      }
      kubeScheduler = {
        enabled = false  # Not accessible in k3s
      }
      kubeProxy = {
        enabled = false  # k3s uses different networking
      }
      kubeEtcd = {
        enabled = false  # k3s uses SQLite by default
      }

      # Additional service monitors for infrastructure components
      additionalServiceMonitors = var.additional_service_monitors
    })
  ]

  depends_on = [kubernetes_namespace.monitoring]
}

# Custom alert rules for k3s DevOps pipeline
resource "kubectl_manifest" "custom_alert_rules" {
  yaml_body = yamlencode({
    apiVersion = "monitoring.coreos.com/v1"
    kind       = "PrometheusRule"
    metadata = {
      name      = "k3s-devops-alerts"
      namespace = kubernetes_namespace.monitoring.metadata[0].name
      labels = {
        prometheus = "kube-prometheus"
        role       = "alert-rules"
      }
    }
    spec = {
      groups = [
        {
          name = "k3s-devops.rules"
          rules = [
            {
              alert = "PodCrashLooping"
              expr  = "rate(kube_pod_container_status_restarts_total[15m]) > 0"
              for   = "5m"
              labels = {
                severity = "warning"
              }
              annotations = {
                summary     = "Pod {{ $labels.namespace }}/{{ $labels.pod }} is crash looping"
                description = "Pod {{ $labels.namespace }}/{{ $labels.pod }} has restarted {{ $value }} times in the last 15 minutes"
              }
            },
            {
              alert = "NodeDown"
              expr  = "up{job=\"kubernetes-nodes\"} == 0"
              for   = "5m"
              labels = {
                severity = "critical"
              }
              annotations = {
                summary     = "Node {{ $labels.instance }} is down"
                description = "Node {{ $labels.instance }} has been down for more than 5 minutes"
              }
            },
            {
              alert = "HighMemoryUsage"
              expr  = "(node_memory_MemTotal_bytes - node_memory_MemAvailable_bytes) / node_memory_MemTotal_bytes > 0.9"
              for   = "10m"
              labels = {
                severity = "warning"
              }
              annotations = {
                summary     = "High memory usage on {{ $labels.instance }}"
                description = "Memory usage is above 90% on {{ $labels.instance }}"
              }
            },
            {
              alert = "HighCPUUsage"
              expr  = "100 - (avg by(instance) (irate(node_cpu_seconds_total{mode=\"idle\"}[5m])) * 100) > 80"
              for   = "10m"
              labels = {
                severity = "warning"
              }
              annotations = {
                summary     = "High CPU usage on {{ $labels.instance }}"
                description = "CPU usage is above 80% on {{ $labels.instance }}"
              }
            },
            {
              alert = "PodNotReady"
              expr  = "kube_pod_status_ready{condition=\"false\", namespace=~\"argocd|harbor|traefik|cert-manager|metallb-system|monitoring\"} == 1"
              for   = "10m"
              labels = {
                severity = "warning"
              }
              annotations = {
                summary     = "Pod {{ $labels.namespace }}/{{ $labels.pod }} not ready"
                description = "Pod {{ $labels.namespace }}/{{ $labels.pod }} has been in a non-ready state for more than 10 minutes"
              }
            },
            {
              alert = "PersistentVolumeClaimPending"
              expr  = "kube_persistentvolumeclaim_status_phase{phase=\"Pending\"} == 1"
              for   = "5m"
              labels = {
                severity = "warning"
              }
              annotations = {
                summary     = "PVC {{ $labels.namespace }}/{{ $labels.persistentvolumeclaim }} is pending"
                description = "PVC {{ $labels.namespace }}/{{ $labels.persistentvolumeclaim }} has been pending for more than 5 minutes"
              }
            }
          ]
        }
      ]
    }
  })

  depends_on = [helm_release.prometheus_stack]
}

# Wait for monitoring stack to be ready
resource "time_sleep" "wait_for_monitoring" {
  depends_on = [helm_release.prometheus_stack]
  
  create_duration = "120s"
}