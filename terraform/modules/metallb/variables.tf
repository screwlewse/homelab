# MetalLB Module Variables

variable "ip_range" {
  description = "IP range for MetalLB address pool"
  type        = string
  default     = "10.0.0.200-10.0.0.210"
}

variable "pool_name" {
  description = "Name of the MetalLB IP address pool"
  type        = string
  default     = "default-pool"
}

variable "namespace" {
  description = "Kubernetes namespace for MetalLB"
  type        = string
  default     = "metallb-system"
}