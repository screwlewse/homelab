# MetalLB Load Balancer Terraform Module

terraform {
  required_providers {
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = "~> 1.14"
    }
  }
}

resource "kubernetes_namespace" "metallb_system" {
  metadata {
    name = "metallb-system"
    labels = {
      name = "metallb-system"
    }
  }
}

# Install MetalLB using kubectl provider for raw manifests
resource "kubectl_manifest" "metallb_install" {
  for_each = toset([
    "https://raw.githubusercontent.com/metallb/metallb/v0.14.8/config/manifests/metallb-native.yaml"
  ])
  
  yaml_body = data.http.metallb_manifests[each.key].response_body
  
  depends_on = [kubernetes_namespace.metallb_system]
}

data "http" "metallb_manifests" {
  for_each = toset([
    "https://raw.githubusercontent.com/metallb/metallb/v0.14.8/config/manifests/metallb-native.yaml"
  ])
  
  url = each.key
}

# Wait for MetalLB deployment to be ready
resource "time_sleep" "wait_for_metallb" {
  depends_on = [kubectl_manifest.metallb_install]
  
  create_duration = "60s"
}

# MetalLB IP Address Pool
resource "kubectl_manifest" "metallb_ippool" {
  yaml_body = yamlencode({
    apiVersion = "metallb.io/v1beta1"
    kind       = "IPAddressPool"
    metadata = {
      name      = var.pool_name
      namespace = kubernetes_namespace.metallb_system.metadata[0].name
    }
    spec = {
      addresses = [var.ip_range]
    }
  })
  
  depends_on = [time_sleep.wait_for_metallb]
}

# MetalLB L2 Advertisement
resource "kubectl_manifest" "metallb_l2_advertisement" {
  yaml_body = yamlencode({
    apiVersion = "metallb.io/v1beta1"
    kind       = "L2Advertisement"
    metadata = {
      name      = "l2-advertisement"
      namespace = kubernetes_namespace.metallb_system.metadata[0].name
    }
    spec = {
      ipAddressPools = [var.pool_name]
    }
  })
  
  depends_on = [kubectl_manifest.metallb_ippool]
}