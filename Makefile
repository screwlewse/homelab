# k3s DevOps Pipeline - Comprehensive Makefile
# Combines foundation setup, core infrastructure, and Terraform automation

.PHONY: help status deploy-all verify clean

# Configuration
KUBECONFIG ?= ~/.kube/config
export KUBECONFIG

SERVER_IP := 10.0.0.88
METALLB_RANGE := 10.0.0.200-10.0.0.210

# Colors for output
YELLOW := \033[1;33m
GREEN := \033[1;32m
BLUE := \033[1;34m
RED := \033[1;31m
NC := \033[0m # No Color

help: ## Display this help message
	@echo "$(BLUE)k3s DevOps Pipeline - Complete Automation$(NC)"
	@echo ""
	@echo "$(YELLOW)Infrastructure as Code (Recommended):$(NC)"
	@echo "  $(GREEN)tf-init$(NC)      Initialize Terraform"
	@echo "  $(GREEN)tf-plan$(NC)      Plan infrastructure changes"
	@echo "  $(GREEN)tf-apply$(NC)     Deploy infrastructure via Terraform"
	@echo "  $(GREEN)tf-test$(NC)      Run infrastructure validation tests"
	@echo ""
	@echo "$(YELLOW)Traditional Deployment:$(NC)"
	@echo "  $(GREEN)deploy-all$(NC)   Deploy all infrastructure components"
	@echo "  $(GREEN)verify$(NC)       Verify service accessibility"
	@echo "  $(GREEN)status$(NC)       Check infrastructure status"
	@echo ""
	@echo "$(YELLOW)Foundation Setup:$(NC)"
	@echo "  $(GREEN)phase1$(NC)       Run Phase 1: Foundation setup"
	@echo "  $(GREEN)verify-phase1$(NC) Verify Phase 1 installation"
	@echo ""
	@echo "$(YELLOW)Testing:$(NC)"
	@echo "  $(GREEN)test$(NC)         Run all tests"
	@echo "  $(GREEN)test-quick$(NC)   Run quick validation tests"
	@echo "  $(GREEN)lint$(NC)         Run all linters"
	@echo "  $(GREEN)pre-commit$(NC)   Setup and run pre-commit hooks"
	@echo ""
	@echo "$(YELLOW)Utilities:$(NC)"
	@echo "  $(GREEN)info$(NC)         Display service information"
	@echo "  $(GREEN)clean$(NC)        Remove all components"
	@echo ""
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "  $(GREEN)%-15s$(NC) %s\n", $$1, $$2}' $(MAKEFILE_LIST)

# ============================================================================
# Infrastructure as Code (Terraform) - Recommended Approach
# ============================================================================

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

# ============================================================================
# Testing Framework
# ============================================================================

test: ## Run all tests
	@echo "$(YELLOW)=== Running all tests ===$(NC)"
	@./tests/run-tests.sh all

test-bats: ## Run BATS tests for shell scripts
	@echo "$(YELLOW)=== Running BATS tests ===$(NC)"
	@./tests/run-tests.sh bats

test-unit: ## Run Terraform unit tests
	@echo "$(YELLOW)=== Running Terraform unit tests ===$(NC)"
	@./tests/run-tests.sh terraform

test-integration: ## Run integration tests
	@echo "$(YELLOW)=== Running integration tests ===$(NC)"
	@./tests/run-tests.sh integration

test-security: ## Run security tests
	@echo "$(YELLOW)=== Running security tests ===$(NC)"
	@./tests/run-tests.sh security

test-quick: ## Run quick validation tests
	@echo "$(YELLOW)=== Running quick tests ===$(NC)"
	@$(MAKE) tf-validate
	@$(MAKE) test-bats

pre-commit: ## Install and run pre-commit hooks
	@echo "$(YELLOW)=== Setting up pre-commit hooks ===$(NC)"
	@./scripts/setup-pre-commit.sh
	@pre-commit run --all-files

lint: ## Run all linters
	@echo "$(YELLOW)=== Running linters ===$(NC)"
	@shellcheck scripts/*.sh || echo "shellcheck not installed"
	@yamllint . || echo "yamllint not installed"
	@cd terraform && terraform fmt -check -recursive || echo "terraform not installed"

# ============================================================================
# Traditional Infrastructure Deployment
# ============================================================================

status: ## Check status of all infrastructure components
	@echo "$(YELLOW)=== k3s Cluster Status ===$(NC)"
	kubectl get nodes -o wide || echo "kubectl not available"
	@echo ""
	@echo "$(YELLOW)=== MetalLB Status ===$(NC)"
	kubectl get pods -n metallb-system || echo "MetalLB not deployed"
	kubectl get ipaddresspools -n metallb-system || echo "MetalLB not configured"
	@echo ""
	@echo "$(YELLOW)=== Traefik Status ===$(NC)"
	kubectl get pods -n traefik || echo "Traefik not deployed"
	kubectl get services -n traefik || echo "Traefik not deployed"
	@echo ""
	@echo "$(YELLOW)=== cert-manager Status ===$(NC)"
	kubectl get pods -n cert-manager || echo "cert-manager not deployed"
	@echo ""
	@echo "$(YELLOW)=== Harbor Status ===$(NC)"
	kubectl get pods -n harbor || echo "Harbor not deployed"
	kubectl get services -n harbor || echo "Harbor not deployed"
	@echo ""
	@echo "$(YELLOW)=== ArgoCD Status ===$(NC)"
	kubectl get pods -n argocd || echo "ArgoCD not deployed"
	kubectl get services -n argocd || echo "ArgoCD not deployed"
	kubectl get applications -n argocd || echo "No ArgoCD applications"
	@echo ""
	@echo "$(YELLOW)=== NodePort Services ===$(NC)"
	kubectl get services --all-namespaces -o wide | grep NodePort || echo "No NodePort services found"

verify: ## Verify all services are accessible
	@echo "$(YELLOW)=== Verifying Service Accessibility ===$(NC)"
	@echo "$(BLUE)Testing Traefik Dashboard ($(SERVER_IP):30900/dashboard/)...$(NC)"
	@curl -s -o /dev/null -w "%{http_code}" http://$(SERVER_IP):30900/dashboard/ && echo " - Traefik dashboard accessible" || echo "$(RED)Failed to reach Traefik dashboard$(NC)"
	@echo ""
	@echo "$(BLUE)Testing Harbor Registry ($(SERVER_IP):30880)...$(NC)"
	@curl -s -o /dev/null -w "%{http_code}" http://$(SERVER_IP):30880 && echo " - Harbor accessible" || echo "$(RED)Failed to reach Harbor$(NC)"
	@echo ""
	@echo "$(BLUE)Testing ArgoCD Web UI ($(SERVER_IP):30808)...$(NC)"
	@curl -s -o /dev/null -w "%{http_code}" http://$(SERVER_IP):30808 && echo " - ArgoCD accessible" || echo "$(RED)Failed to reach ArgoCD$(NC)"
	@echo ""

deploy-traefik: ## Deploy Traefik ingress controller
	@echo "$(YELLOW)=== Deploying Traefik ===$(NC)"
	kubectl apply -f manifests/traefik/traefik-namespace.yaml
	helm repo add traefik https://traefik.github.io/charts
	helm repo update
	helm upgrade --install traefik traefik/traefik --namespace traefik --values manifests/traefik/traefik-values-nodeport.yaml
	@echo "$(GREEN)Traefik deployed successfully$(NC)"

deploy-harbor: ## Deploy Harbor container registry
	@echo "$(YELLOW)=== Deploying Harbor ===$(NC)"
	kubectl apply -f manifests/harbor/harbor-namespace.yaml
	helm repo add harbor https://helm.goharbor.io
	helm repo update
	helm upgrade --install harbor harbor/harbor --namespace harbor --values manifests/harbor/harbor-values-nodeport.yaml --timeout 10m
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
	kubectl wait --for=condition=ready pod -l app=metallb -n metallb-system --timeout=60s || true
	kubectl apply -f manifests/metallb/metallb-config.yaml || true
	@echo "$(GREEN)MetalLB deployed successfully$(NC)"

deploy-argocd: ## Deploy ArgoCD GitOps engine
	@echo "$(YELLOW)=== Deploying ArgoCD ===$(NC)"
	kubectl apply -f manifests/argocd/argocd-namespace.yaml
	kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
	kubectl apply -f manifests/argocd/argocd-server-nodeport.yaml
	kubectl patch configmap argocd-cmd-params-cm -n argocd --type merge -p '{"data":{"server.insecure":"true"}}' || true
	kubectl rollout restart deployment argocd-server -n argocd || true
	@echo "$(GREEN)ArgoCD deployed successfully$(NC)"

deploy-all: deploy-metallb deploy-traefik deploy-cert-manager deploy-harbor deploy-argocd ## Deploy all infrastructure components
	@echo "$(GREEN)=== All infrastructure components deployed successfully ===$(NC)"
	@$(MAKE) status

# ============================================================================
# Foundation Setup (Phase 1)
# ============================================================================

phase1: ## Run Phase 1: Foundation setup (k3s, Helm, networking)
	@echo "$(YELLOW)=== Starting Phase 1: Foundation Setup ===$(NC)"
	@if [ -f scripts/phase1-foundation-setup.sh ]; then \
		chmod +x scripts/phase1-foundation-setup.sh && \
		./scripts/phase1-foundation-setup.sh; \
	else \
		echo "$(RED)Phase 1 script not found. Run: make setup-foundation$(NC)"; \
	fi

verify-phase1: ## Verify Phase 1 installation
	@echo "$(YELLOW)=== Verifying Phase 1 installation ===$(NC)"
	@if [ -f scripts/verify-phase1.sh ]; then \
		chmod +x scripts/verify-phase1.sh && \
		./scripts/verify-phase1.sh; \
	else \
		echo "$(BLUE)Running basic verification...$(NC)"; \
		kubectl cluster-info || echo "$(RED)k3s cluster not available$(NC)"; \
		helm version --short || echo "$(RED)Helm not available$(NC)"; \
		docker --version || echo "$(RED)Docker not available$(NC)"; \
	fi

setup-foundation: ## Create foundation setup script
	@echo "$(YELLOW)=== Creating foundation setup script ===$(NC)"
	@mkdir -p scripts
	@cat > scripts/phase1-foundation-setup.sh << 'EOF'
#!/bin/bash
# Phase 1: k3s DevOps Pipeline Foundation Setup
set -euo pipefail

echo "=== Phase 1: Foundation Setup ==="
echo "Setting up k3s, Helm, and basic networking..."

# Check if k3s is already installed
if command -v k3s &> /dev/null; then
    echo "✓ k3s already installed"
else
    echo "Installing k3s..."
    curl -sfL https://get.k3s.io | sh -
fi

# Configure kubectl
mkdir -p ~/.kube
sudo cp /etc/rancher/k3s/k3s.yaml ~/.kube/config
sudo chown $$(id -u):$$(id -g) ~/.kube/config

# Install Helm if not present
if command -v helm &> /dev/null; then
    echo "✓ Helm already installed"
else
    echo "Installing Helm..."
    curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
fi

echo "✅ Phase 1: Foundation setup completed successfully!"
EOF
	@chmod +x scripts/phase1-foundation-setup.sh
	@echo "$(GREEN)Foundation setup script created$(NC)"

# ============================================================================
# Cleanup Operations
# ============================================================================

clean-traefik: ## Remove Traefik
	helm uninstall traefik -n traefik || true
	kubectl delete namespace traefik || true

clean-harbor: ## Remove Harbor
	helm uninstall harbor -n harbor || true
	kubectl delete namespace harbor || true

clean-cert-manager: ## Remove cert-manager
	helm uninstall cert-manager -n cert-manager || true
	kubectl delete namespace cert-manager || true

clean-metallb: ## Remove MetalLB
	kubectl delete -f manifests/metallb/metallb-config.yaml || true
	kubectl delete -f https://raw.githubusercontent.com/metallb/metallb/v0.14.8/config/manifests/metallb-native.yaml || true
	kubectl delete namespace metallb-system || true

clean-argocd: ## Remove ArgoCD
	kubectl delete -f manifests/argocd/sample-nginx-app.yaml || true
	kubectl delete -f manifests/argocd/argocd-server-nodeport.yaml || true
	kubectl delete -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml || true
	kubectl delete namespace argocd || true

clean: clean-harbor clean-traefik clean-cert-manager clean-argocd clean-metallb ## Remove all infrastructure components
	@echo "$(GREEN)All components removed$(NC)"

clean-phase1: ## Clean up Phase 1 installation (WARNING: destructive)
	@echo "$(RED)WARNING: This will completely remove k3s and all data!$(NC)"
	@read -p "Are you sure? (y/N): " confirm && [ "$$confirm" = "y" ]
	@sudo /usr/local/bin/k3s-uninstall.sh || echo "k3s not installed"
	@sudo rm -rf ~/.kube
	@docker system prune -af || echo "Docker cleanup skipped"

# ============================================================================
# Information and Utilities
# ============================================================================

info: ## Display service information and access URLs
	@echo "$(BLUE)=== k3s DevOps Pipeline - Service Information ===$(NC)"
	@echo ""
	@echo "$(YELLOW)NodePort Services (accessible via $(SERVER_IP)):$(NC)"
	@echo "  • $(GREEN)Traefik Dashboard:$(NC) http://$(SERVER_IP):30900/dashboard/"
	@echo "  • $(GREEN)Traefik HTTP:$(NC) http://$(SERVER_IP):30080"
	@echo "  • $(GREEN)Harbor Registry:$(NC) http://$(SERVER_IP):30880"
	@echo "  • $(GREEN)ArgoCD Web UI:$(NC) http://$(SERVER_IP):30808"
	@echo ""
	@echo "$(YELLOW)Default Credentials:$(NC)"
	@echo "  • $(GREEN)Harbor:$(NC) admin / Harbor12345"
	@if kubectl get secret argocd-initial-admin-secret -n argocd &> /dev/null; then \
		echo "  • $(GREEN)ArgoCD:$(NC) admin / $$(kubectl get secret argocd-initial-admin-secret -n argocd -o jsonpath='{.data.password}' | base64 -d 2>/dev/null || echo 'Unable to decode')"; \
	else \
		echo "  • $(GREEN)ArgoCD:$(NC) admin / [ArgoCD not deployed]"; \
	fi
	@echo ""
	@echo "$(YELLOW)Port Mapping:$(NC)"
	@echo "  • $(GREEN)Traefik Dashboard:$(NC) 30900"
	@echo "  • $(GREEN)Traefik HTTP:$(NC) 30080" 
	@echo "  • $(GREEN)Harbor Web UI:$(NC) 30880"
	@echo "  • $(GREEN)ArgoCD Web UI:$(NC) 30808"
	@echo ""

network-info: ## Display network information
	@echo "$(YELLOW)=== Network Information ===$(NC)"
	@echo "Server IP: $(SERVER_IP)"
	@echo "MetalLB Range: $(METALLB_RANGE)"
	@echo "Current IP: $$(hostname -I | awk '{print $$1}')"
	@echo ""
	@echo "$(YELLOW)=== Network Interfaces ===$(NC)"
	@ip addr show | grep -E "^[0-9]|inet " || echo "IP command failed"
	@echo ""
	@echo "$(YELLOW)=== MetalLB IP Pool ===$(NC)"
	@kubectl get ipaddresspool -n metallb-system -o wide 2>/dev/null || echo "MetalLB not configured"

logs: ## Show logs for key components
	@echo "$(YELLOW)=== k3s logs ===$(NC)"
	@sudo journalctl -u k3s -n 20 --no-pager 2>/dev/null || echo "k3s logs not available"
	@echo ""
	@echo "$(YELLOW)=== MetalLB controller logs ===$(NC)"
	@kubectl logs -n metallb-system deployment/controller --tail=10 2>/dev/null || echo "MetalLB not ready"

quick-test: ## Quick smoke test of the installation
	@echo "$(YELLOW)Running quick smoke test...$(NC)"
	@kubectl cluster-info
	@helm version --short
	@docker --version
	@echo "$(GREEN)✓ Quick test completed$(NC)"

backup-configs: ## Backup important configurations
	@echo "$(YELLOW)Backing up configurations...$(NC)"
	@mkdir -p backups/$$(date +%Y%m%d-%H%M%S)
	@sudo cp /etc/rancher/k3s/k3s.yaml backups/$$(date +%Y%m%d-%H%M%S)/ 2>/dev/null || echo "k3s config not found"
	@kubectl get all -A -o yaml > backups/$$(date +%Y%m%d-%H%M%S)/all-resources.yaml 2>/dev/null || echo "kubectl backup skipped"

.DEFAULT_GOAL := help