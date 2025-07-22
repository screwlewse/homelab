# Harbor Module Outputs

output "namespace" {
  description = "Harbor namespace"
  value       = kubernetes_namespace.harbor.metadata[0].name
}

output "service_name" {
  description = "Harbor service name"
  value       = helm_release.harbor.name
}

output "chart_version" {
  description = "Deployed Harbor chart version"
  value       = helm_release.harbor.version
}

output "external_url" {
  description = "Harbor external URL"
  value       = var.external_url
}

output "admin_credentials" {
  description = "Harbor admin credentials"
  value = {
    username = "admin"
    password = var.admin_password
  }
  sensitive = true
}