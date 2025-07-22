# Traefik Module Outputs

output "namespace" {
  description = "Traefik namespace"
  value       = kubernetes_namespace.traefik.metadata[0].name
}

output "service_name" {
  description = "Traefik service name"
  value       = helm_release.traefik.name
}

output "chart_version" {
  description = "Deployed Traefik chart version"
  value       = helm_release.traefik.version
}

output "service_type" {
  description = "Traefik service type"
  value       = var.service_type
}

output "nodeports" {
  description = "Traefik NodePort configuration"
  value       = var.nodeports
}