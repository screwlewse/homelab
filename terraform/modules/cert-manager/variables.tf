# cert-manager Module Variables

variable "chart_version" {
  description = "cert-manager Helm chart version"
  type        = string
  default     = "v1.13.2"
}

variable "create_letsencrypt_issuer" {
  description = "Create Let's Encrypt ClusterIssuer"
  type        = bool
  default     = false
}

variable "letsencrypt_email" {
  description = "Email for Let's Encrypt certificate requests"
  type        = string
  default     = "admin@k3s.local"
}