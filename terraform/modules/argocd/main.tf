# ArgoCD GitOps Engine Terraform Module

resource "kubernetes_namespace" "argocd" {
  metadata {
    name = "argocd"
    labels = {
      name = "argocd"
    }
  }
}

# Install ArgoCD using kubectl provider for raw manifests
resource "kubectl_manifest" "argocd_install" {
  for_each = toset(split("---", data.http.argocd_manifests.response_body))
  
  yaml_body = each.key
  
  depends_on = [kubernetes_namespace.argocd]
}

data "http" "argocd_manifests" {
  url = "https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml"
}

# Wait for ArgoCD deployment to be ready
resource "time_sleep" "wait_for_argocd" {
  depends_on = [kubectl_manifest.argocd_install]
  
  create_duration = "120s"
}

# ArgoCD Server NodePort Service
resource "kubernetes_service" "argocd_server_nodeport" {
  count = var.service_type == "NodePort" ? 1 : 0
  
  metadata {
    name      = "argocd-server-nodeport"
    namespace = kubernetes_namespace.argocd.metadata[0].name
    labels = {
      "app.kubernetes.io/name" = "argocd-server-nodeport"
    }
  }

  spec {
    type = "NodePort"
    
    port {
      name        = "http"
      port        = 80
      target_port = 8080
      node_port   = var.nodeport
      protocol    = "TCP"
    }
    
    port {
      name        = "https"
      port        = 443
      target_port = 8080
      node_port   = var.nodeport + 35
      protocol    = "TCP"
    }

    selector = {
      "app.kubernetes.io/name" = "argocd-server"
    }
  }
  
  depends_on = [time_sleep.wait_for_argocd]
}

# Configure ArgoCD server for insecure access (if enabled)
resource "kubernetes_config_map_v1_data" "argocd_cmd_params_cm" {
  count = var.server_insecure ? 1 : 0
  
  metadata {
    name      = "argocd-cmd-params-cm"
    namespace = kubernetes_namespace.argocd.metadata[0].name
  }

  data = {
    "server.insecure" = "true"
  }
  
  depends_on = [time_sleep.wait_for_argocd]
}

# Restart ArgoCD server deployment to apply insecure setting
resource "kubectl_manifest" "restart_argocd_server" {
  count = var.server_insecure ? 1 : 0
  
  yaml_body = yamlencode({
    apiVersion = "apps/v1"
    kind       = "Deployment"
    metadata = {
      name      = "argocd-server"
      namespace = kubernetes_namespace.argocd.metadata[0].name
      annotations = {
        "kubectl.kubernetes.io/restartedAt" = timestamp()
      }
    }
    spec = {} # This will trigger a patch operation
  })
  
  depends_on = [kubernetes_config_map_v1_data.argocd_cmd_params_cm]
}