# ArgoCD Module Outputs

output "namespace" {
  description = "ArgoCD namespace"
  value       = kubernetes_namespace.argocd.metadata[0].name
}

output "server_service_name" {
  description = "ArgoCD server service name"
  value       = var.service_type == "NodePort" ? kubernetes_service.argocd_server_nodeport[0].metadata[0].name : "argocd-server"
}

output "server_nodeport" {
  description = "ArgoCD server NodePort"
  value       = var.service_type == "NodePort" ? var.nodeport : null
}

output "server_insecure" {
  description = "ArgoCD server insecure mode enabled"
  value       = var.server_insecure
}

output "initial_admin_secret" {
  description = "Command to get ArgoCD initial admin password"
  value       = "kubectl get secret argocd-initial-admin-secret -n ${kubernetes_namespace.argocd.metadata[0].name} -o jsonpath='{.data.password}' | base64 -d"
}