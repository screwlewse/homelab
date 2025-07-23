# MetalLB Module Variables

variable "ip_range" {
  description = "IP range for MetalLB address pool"
  type        = string
  default     = "10.0.0.200-10.0.0.210"

  validation {
    condition     = can(regex("^[0-9]+\\.[0-9]+\\.[0-9]+\\.[0-9]+-[0-9]+\\.[0-9]+\\.[0-9]+\\.[0-9]+$", var.ip_range))
    error_message = "The ip_range must be in format: X.X.X.X-Y.Y.Y.Y"
  }
}

variable "pool_name" {
  description = "Name of the MetalLB IP address pool"
  type        = string
  default     = "default-pool"

  validation {
    condition     = can(regex("^[a-z0-9]([-a-z0-9]*[a-z0-9])?$", var.pool_name))
    error_message = "The pool_name must be a valid Kubernetes resource name."
  }
}

variable "namespace" {
  description = "Kubernetes namespace for MetalLB"
  type        = string
  default     = "metallb-system"

  validation {
    condition     = can(regex("^[a-z0-9]([-a-z0-9]*[a-z0-9])?$", var.namespace))
    error_message = "The namespace must be a valid Kubernetes namespace name."
  }
}