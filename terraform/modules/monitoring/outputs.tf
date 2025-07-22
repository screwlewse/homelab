# Monitoring Module Outputs

output "namespace" {
  description = "Monitoring namespace name"
  value       = kubernetes_namespace.monitoring.metadata[0].name
}

output "prometheus_url" {
  description = "Prometheus UI URL"
  value       = "http://${var.server_ip}:${var.prometheus_nodeport}"
}

output "grafana_url" {
  description = "Grafana Dashboard URL"
  value       = "http://${var.server_ip}:${var.grafana_nodeport}"
}

output "grafana_credentials" {
  description = "Grafana login credentials"
  value = {
    username = "admin"
    password = var.grafana_admin_password
  }
  sensitive = true
}

output "alertmanager_url" {
  description = "AlertManager UI URL"
  value       = "http://${var.server_ip}:${var.alertmanager_nodeport}"
}

output "monitoring_endpoints" {
  description = "All monitoring service endpoints"
  value = {
    prometheus   = "http://${var.server_ip}:${var.prometheus_nodeport}"
    grafana      = "http://${var.server_ip}:${var.grafana_nodeport}"
    alertmanager = "http://${var.server_ip}:${var.alertmanager_nodeport}"
  }
}

output "helm_release_name" {
  description = "Helm release name for the monitoring stack"
  value       = helm_release.prometheus_stack.name
}

output "helm_release_namespace" {
  description = "Helm release namespace for the monitoring stack"
  value       = helm_release.prometheus_stack.namespace
}

output "helm_release_status" {
  description = "Helm release status"
  value       = helm_release.prometheus_stack.status
}

output "storage_info" {
  description = "Storage configuration for monitoring components"
  value = {
    prometheus_storage   = var.prometheus_storage_size
    grafana_storage      = var.grafana_storage_size
    alertmanager_storage = var.alertmanager_storage_size
    retention_period     = var.prometheus_retention
  }
}