# cert-manager Module Outputs

output "namespace" {
  description = "cert-manager namespace"
  value       = kubernetes_namespace.cert_manager.metadata[0].name
}

output "release_name" {
  description = "cert-manager Helm release name"
  value       = helm_release.cert_manager.name
}

output "chart_version" {
  description = "Deployed cert-manager chart version"
  value       = helm_release.cert_manager.version
}