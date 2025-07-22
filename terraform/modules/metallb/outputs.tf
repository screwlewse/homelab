# MetalLB Module Outputs

output "namespace" {
  description = "MetalLB namespace"
  value       = kubernetes_namespace.metallb_system.metadata[0].name
}

output "ip_pool_name" {
  description = "MetalLB IP address pool name"
  value       = var.pool_name
}

output "ip_range" {
  description = "MetalLB IP address range"
  value       = var.ip_range
}