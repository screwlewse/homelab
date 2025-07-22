# k3s DevOps Pipeline Makefile
# Phase 2: Core Infrastructure Automation

.PHONY: help status deploy-all verify clean

KUBECONFIG ?= ~/.kube/config
export KUBECONFIG

# Colors for output
YELLOW := \033[1;33m
GREEN := \033[1;32m
BLUE := \033[1;34m
RED := \033[1;31m
NC := \033[0m # No Color

help: ## Display this help message
	@echo "$(BLUE)k3s DevOps Pipeline - Phase 2 Automation$(NC)"
	@echo ""
	@echo "$(YELLOW)Available targets:$(NC)"
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "  $(GREEN)%-15s$(NC) %s\n", $$1, $$2}' $(MAKEFILE_LIST)

status: ## Check status of all infrastructure components
	@echo "$(YELLOW)=== k3s Cluster Status ===$(NC)"
	kubectl get nodes -o wide
	@echo ""
	@echo "$(YELLOW)=== MetalLB Status ===$(NC)"
	kubectl get pods -n metallb-system
	kubectl get ipaddresspools -n metallb-system
	@echo ""
	@echo "$(YELLOW)=== Traefik Status ===$(NC)"
	kubectl get pods -n traefik
	kubectl get services -n traefik
	@echo ""
	@echo "$(YELLOW)=== cert-manager Status ===$(NC)"
	kubectl get pods -n cert-manager
	@echo ""
	@echo "$(YELLOW)=== Harbor Status ===$(NC)"
	kubectl get pods -n harbor
	kubectl get services -n harbor
	@echo ""
	@echo "$(YELLOW)=== ArgoCD Status ===$(NC)"
	kubectl get pods -n argocd
	kubectl get services -n argocd
	kubectl get applications -n argocd
	@echo ""
	@echo "$(YELLOW)=== NodePort Services ===$(NC)"
	kubectl get services --all-namespaces -o wide | grep NodePort

verify: ## Verify all services are accessible
	@echo "$(YELLOW)=== Verifying Service Accessibility ===$(NC)"
	@echo "$(BLUE)Testing Traefik Dashboard (10.0.0.88:30900/dashboard/)...$(NC)"
	@curl -s -o /dev/null -w "%{http_code}" http://10.0.0.88:30900/dashboard/ && echo " - Traefik dashboard accessible" || echo "$(RED)Failed to reach Traefik dashboard$(NC)"
	@echo ""
	@echo "$(BLUE)Testing Harbor Registry (10.0.0.88:30880)...$(NC)"
	@curl -s -o /dev/null -w "%{http_code}" http://10.0.0.88:30880 && echo " - Harbor accessible" || echo "$(RED)Failed to reach Harbor$(NC)"
	@echo ""
	@echo "$(BLUE)Testing ArgoCD Web UI (10.0.0.88:30808)...$(NC)"
	@curl -s -o /dev/null -w "%{http_code}" http://10.0.0.88:30808 && echo " - ArgoCD accessible" || echo "$(RED)Failed to reach ArgoCD$(NC)"
	@echo ""

deploy-traefik: ## Deploy Traefik ingress controller
	@echo "$(YELLOW)=== Deploying Traefik ===$(NC)"
	kubectl apply -f manifests/traefik/traefik-namespace.yaml
	helm repo add traefik https://traefik.github.io/charts
	helm repo update
	helm upgrade --install traefik traefik/traefik --namespace traefik --values manifests/traefik/traefik-values.yaml
	@echo "$(GREEN)Traefik deployed successfully$(NC)"

deploy-harbor: ## Deploy Harbor container registry
	@echo "$(YELLOW)=== Deploying Harbor ===$(NC)"
	kubectl apply -f manifests/harbor/harbor-namespace.yaml
	helm repo add harbor https://helm.goharbor.io
	helm repo update
	helm upgrade --install harbor harbor/harbor --namespace harbor --values manifests/harbor/harbor-values.yaml --timeout 10m
	@echo "$(GREEN)Harbor deployed successfully$(NC)"

deploy-cert-manager: ## Deploy cert-manager
	@echo "$(YELLOW)=== Deploying cert-manager ===$(NC)"
	kubectl apply -f manifests/cert-manager/cert-manager-namespace.yaml
	helm repo add jetstack https://charts.jetstack.io
	helm repo update
	helm upgrade --install cert-manager jetstack/cert-manager --namespace cert-manager --set crds.enabled=true
	@echo "$(GREEN)cert-manager deployed successfully$(NC)"

deploy-metallb: ## Deploy MetalLB load balancer
	@echo "$(YELLOW)=== Deploying MetalLB ===$(NC)"
	kubectl apply -f manifests/metallb/metallb-namespace.yaml
	kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.14.8/config/manifests/metallb-native.yaml
	@echo "$(BLUE)Waiting for MetalLB pods to be ready...$(NC)"
	kubectl wait --for=condition=ready pod -l app=metallb -n metallb-system --timeout=60s
	kubectl apply -f manifests/metallb/metallb-config.yaml
	@echo "$(GREEN)MetalLB deployed successfully$(NC)"

deploy-argocd: ## Deploy ArgoCD GitOps engine
	@echo "$(YELLOW)=== Deploying ArgoCD ===$(NC)"
	kubectl apply -f manifests/argocd/argocd-namespace.yaml
	kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
	kubectl apply -f manifests/argocd/argocd-server-nodeport.yaml
	kubectl patch configmap argocd-cmd-params-cm -n argocd --type merge -p '{"data":{"server.insecure":"true"}}'
	kubectl rollout restart deployment argocd-server -n argocd
	@echo "$(GREEN)ArgoCD deployed successfully$(NC)"

deploy-all: deploy-metallb deploy-traefik deploy-cert-manager deploy-harbor deploy-argocd ## Deploy all infrastructure components
	@echo "$(GREEN)=== All Phase 2 & 3 components deployed successfully ===$(NC)"
	@$(MAKE) status

wait-for-harbor: ## Wait for Harbor to be fully ready
	@echo "$(YELLOW)=== Waiting for Harbor to be ready ===$(NC)"
	kubectl wait --for=condition=ready pod -l app=harbor -n harbor --timeout=300s
	@echo "$(GREEN)Harbor is ready$(NC)"

clean-traefik: ## Remove Traefik
	helm uninstall traefik -n traefik
	kubectl delete namespace traefik

clean-harbor: ## Remove Harbor
	helm uninstall harbor -n harbor
	kubectl delete namespace harbor

clean-cert-manager: ## Remove cert-manager
	helm uninstall cert-manager -n cert-manager
	kubectl delete namespace cert-manager

clean-metallb: ## Remove MetalLB
	kubectl delete -f manifests/metallb/metallb-config.yaml
	kubectl delete -f https://raw.githubusercontent.com/metallb/metallb/v0.14.8/config/manifests/metallb-native.yaml
	kubectl delete namespace metallb-system

# Terraform Infrastructure as Code operations
tf-init: ## Initialize Terraform
	@echo "$(YELLOW)=== Initializing Terraform ===$(NC)"
	cd terraform && terraform init

tf-plan: ## Plan Terraform infrastructure
	@echo "$(YELLOW)=== Planning Terraform infrastructure ===$(NC)"
	cd terraform && terraform plan

tf-apply: ## Apply Terraform infrastructure
	@echo "$(YELLOW)=== Applying Terraform infrastructure ===$(NC)"
	cd terraform && terraform apply

tf-destroy: ## Destroy Terraform infrastructure
	@echo "$(YELLOW)=== Destroying Terraform infrastructure ===$(NC)"
	cd terraform && terraform destroy

tf-validate: ## Validate Terraform configuration
	@echo "$(YELLOW)=== Validating Terraform configuration ===$(NC)"
	cd terraform && terraform validate && terraform fmt -check -recursive

tf-output: ## Show Terraform outputs
	@echo "$(YELLOW)=== Terraform outputs ===$(NC)"
	cd terraform && terraform output

tf-test: ## Run infrastructure validation tests
	@echo "$(YELLOW)=== Running infrastructure tests ===$(NC)"
	cd terraform && ./tests/validate-infrastructure.sh

clean: clean-harbor clean-traefik clean-cert-manager clean-metallb ## Remove all infrastructure components
	@echo "$(GREEN)All components removed$(NC)"

info: ## Display service information and access URLs
	@echo "$(BLUE)=== k3s DevOps Pipeline - Service Information ===$(NC)"
	@echo ""
	@echo "$(YELLOW)NodePort Services (accessible via 10.0.0.88):$(NC)"
	@echo "  • $(GREEN)Traefik Dashboard:$(NC) http://10.0.0.88:30900/dashboard/"
	@echo "  • $(GREEN)Traefik HTTP:$(NC) http://10.0.0.88:30080"
	@echo "  • $(GREEN)Harbor Registry:$(NC) http://10.0.0.88:30880"
	@echo "  • $(GREEN)ArgoCD Web UI:$(NC) http://10.0.0.88:30808"
	@echo ""
	@echo "$(YELLOW)Default Credentials:$(NC)"
	@echo "  • $(GREEN)Harbor:$(NC) admin / Harbor12345"
	@echo "  • $(GREEN)ArgoCD:$(NC) admin / $$(kubectl get secret argocd-initial-admin-secret -n argocd -o jsonpath=\"{.data.password}\" | base64 -d)"
	@echo ""
	@echo "$(YELLOW)Port Mapping:$(NC)"
	@echo "  • $(GREEN)Traefik Dashboard:$(NC) 30900"
	@echo "  • $(GREEN)Traefik HTTP:$(NC) 30080" 
	@echo "  • $(GREEN)Harbor Web UI:$(NC) 30880"
	@echo "  • $(GREEN)ArgoCD Web UI:$(NC) 30808"
	@echo ""