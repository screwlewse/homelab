
#!/bin/bash
# verify-phase1.sh
# Comprehensive verification script for Phase 1 foundation setup

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

CHECKS_PASSED=0
CHECKS_TOTAL=0

check() {
    local test_name="$1"
    local command="$2"
    
    CHECKS_TOTAL=$((CHECKS_TOTAL + 1))
    
    echo -n "Checking $test_name... "
    
    if eval "$command" &> /dev/null; then
        echo -e "${GREEN}✓${NC}"
        CHECKS_PASSED=$((CHECKS_PASSED + 1))
        return 0
    else
        echo -e "${RED}✗${NC}"
        return 1
    fi
}

detailed_check() {
    local test_name="$1"
    local command="$2"
    
    echo -e "${YELLOW}=== $test_name ===${NC}"
    if eval "$command"; then
        echo -e "${GREEN}✓ $test_name passed${NC}"
        echo
        return 0
    else
        echo -e "${RED}✗ $test_name failed${NC}"
        echo
        return 1
    fi
}

main() {
    echo "=================================================================="
    echo "Phase 1 Foundation Verification"
    echo "=================================================================="
    echo
    
    # Basic system checks
    check "Docker installation" "docker --version"
    check "Docker service" "systemctl is-active docker"
    check "Docker user access" "docker ps"
    check "Helm installation" "helm version"
    check "k3s installation" "k3s --version"
    check "kubectl access" "kubectl get nodes"
    
    echo
    echo "=== Detailed System Status ==="
    
    # Detailed checks with output
    detailed_check "Cluster Nodes Status" "kubectl get nodes -o wide"
    detailed_check "System Pods" "kubectl get pods -A"
    detailed_check "Storage Classes" "kubectl get storageclass"
    detailed_check "MetalLB Status" "kubectl get pods -n metallb-system"
    detailed_check "MetalLB Configuration" "kubectl get ipaddresspool,l2advertisement -n metallb-system"
    detailed_check "Helm Repositories" "helm repo list"
    detailed_check "Helm Installations" "helm list -A"
    
    # Test storage provisioning
    echo -e "${YELLOW}=== Testing Storage Provisioning ===${NC}"
    cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: test-pvc
  namespace: default
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
EOF
    
    sleep 5
    if kubectl get pvc test-pvc | grep -q Bound; then
        echo -e "${GREEN}✓ Storage provisioning working${NC}"
        kubectl delete pvc test-pvc
    else
        echo -e "${RED}✗ Storage provisioning failed${NC}"
        kubectl get pvc test-pvc
    fi
    
    echo
    echo "=================================================================="
    echo "VERIFICATION SUMMARY"
    echo "=================================================================="
    echo "Checks passed: $CHECKS_PASSED/$CHECKS_TOTAL"
    
    if [ $CHECKS_PASSED -eq $CHECKS_TOTAL ]; then
        echo -e "${GREEN}✓ All checks passed! Ready for Phase 2${NC}"
        exit 0
    else
        echo -e "${RED}✗ Some checks failed. Please review and fix issues.${NC}"
        exit 1
    fi
}

main "$@"
