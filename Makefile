# Makefile for k3s DevOps Pipeline Setup
# Automates the entire infrastructure deployment process

.PHONY: help phase1 verify-phase1 clean-phase1 status

# Configuration
SERVER_IP := 10.0.0.88
METALLB_RANGE := 10.0.0.200-10.0.0.210

help: ## Display this help message
	@echo "k3s DevOps Pipeline Setup"
	@echo "========================="
	@echo "Available targets:"
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "  %-20s %s\n", $$1, $$2}' $(MAKEFILE_LIST)

phase1: ## Run Phase 1: Foundation setup (k3s, Helm, networking)
	@echo "Starting Phase 1: Foundation Setup"
	@chmod +x scripts/phase1-foundation-setup.sh
	@./scripts/phase1-foundation-setup.sh

verify-phase1: ## Verify Phase 1 installation
	@echo "Verifying Phase 1 installation"
	@chmod +x scripts/verify-phase1.sh
	@./scripts/verify-phase1.sh

status: ## Show cluster and service status
	@echo "=== Cluster Status ==="
	@kubectl get nodes -o wide || echo "kubectl not available"
	@echo
	@echo "=== System Pods ==="
	@kubectl get pods -A || echo "kubectl not available"
	@echo
	@echo "=== LoadBalancer Services ==="
	@kubectl get svc -A -o wide | grep LoadBalancer || echo "No LoadBalancer services found"
	@echo
	@echo "=== Storage Classes ==="
	@kubectl get storageclass || echo "kubectl not available"

test-storage: ## Test storage provisioning
	@echo "Testing storage provisioning..."
	@kubectl apply -f - <<< 'apiVersion: v1\nkind: PersistentVolumeClaim\nmetadata:\n  name: test-pvc-$$(date +%s)\nspec:\n  accessModes: [ReadWriteOnce]\n  resources:\n    requests:\n      storage: 1Gi'
	@sleep 5
	@kubectl get pvc

clean-test-storage: ## Clean up test storage resources
	@echo "Cleaning up test storage resources..."
	@kubectl delete pvc -l test=storage --ignore-not-found=true

metallb-config: ## Apply MetalLB configuration
	@echo "Applying MetalLB configuration..."
	@kubectl apply -f configs/metallb-config.yaml

logs: ## Show logs for key components
	@echo "=== k3s logs ==="
	@sudo journalctl -u k3s -n 20 --no-pager
	@echo
	@echo "=== MetalLB controller logs ==="
	@kubectl logs -n metallb-system deployment/controller --tail=10 || echo "MetalLB not ready"

clean-phase1: ## Clean up Phase 1 installation (WARNING: destructive)
	@echo "WARNING: This will completely remove k3s and all data!"
	@read -p "Are you sure? (y/N): " confirm && [ "$$confirm" = "y" ]
	@sudo /usr/local/bin/k3s-uninstall.sh || echo "k3s not installed"
	@sudo rm -rf ~/.kube
	@docker system prune -af || echo "Docker cleanup skipped"

backup-configs: ## Backup important configurations
	@echo "Backing up configurations..."
	@mkdir -p backups/$$(date +%Y%m%d-%H%M%S)
	@sudo cp /etc/rancher/k3s/k3s.yaml backups/$$(date +%Y%m%d-%H%M%S)/ 2>/dev/null || echo "k3s config not found"
	@kubectl get all -A -o yaml > backups/$$(date +%Y%m%d-%H%M%S)/all-resources.yaml 2>/dev/null || echo "kubectl backup skipped"

network-info: ## Display network information
	@echo "=== Network Information ==="
	@echo "Server IP: $(SERVER_IP)"
	@echo "MetalLB Range: $(METALLB_RANGE)"
	@echo "Current IP: $$(hostname -I | awk '{print $$1}')"
	@echo
	@echo "=== Network Interfaces ==="
	@ip addr show | grep -E "^[0-9]|inet " || echo "IP command failed"
	@echo
	@echo "=== MetalLB IP Pool ==="
	@kubectl get ipaddresspool -n metallb-system -o wide 2>/dev/null || echo "MetalLB not configured"

quick-test: ## Quick smoke test of the installation
	@echo "Running quick smoke test..."
	@kubectl cluster-info
	@helm version --short
	@docker --version
	@echo "✓ Quick test completed"

.DEFAULT_GOAL := help
