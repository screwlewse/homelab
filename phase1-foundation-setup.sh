
#!/bin/bash
# phase1-foundation-setup.sh
# Automated foundation setup for k3s cluster with Helm and networking

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Server IP configuration
SERVER_IP="10.0.0.88"
METALLB_IP_RANGE="10.0.0.200-10.0.0.210"

log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

warn() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] WARNING: $1${NC}"
}

error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR: $1${NC}"
    exit 1
}

check_prerequisites() {
    log "Checking prerequisites..."
    
    # Check if running as regular user
    if [ "$EUID" -eq 0 ]; then
        error "Please run this script as a regular user with sudo privileges"
    fi
    
    # Check sudo access
    if ! sudo -n true 2>/dev/null; then
        error "This script requires sudo privileges"
    fi
    
    # Check internet connectivity
    if ! ping -c 1 google.com &> /dev/null; then
        error "Internet connectivity required"
    fi
    
    log "Prerequisites check passed"
}

update_system() {
    log "Updating system packages..."
    sudo apt update && sudo apt upgrade -y
    sudo apt install -y curl wget git vim htop net-tools
    log "System packages updated"
}

install_docker() {
    log "Installing Docker..."
    
    if command -v docker &> /dev/null; then
        warn "Docker already installed, skipping"
        return 0
    fi
    
    curl -fsSL https://get.docker.com -o get-docker.sh
    sudo sh get-docker.sh
    sudo usermod -aG docker $USER
    rm get-docker.sh
    
    # Test docker installation
    if ! docker --version &> /dev/null; then
        error "Docker installation failed"
    fi
    
    log "Docker installed successfully"
}

install_helm() {
    log "Installing Helm..."
    
    if command -v helm &> /dev/null; then
        warn "Helm already installed, skipping"
        return 0
    fi
    
    curl https://baltocdn.com/helm/signing.asc | gpg --dearmor | sudo tee /usr/share/keyrings/helm.gpg > /dev/null
    sudo apt-get install apt-transport-https --yes
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/helm.gpg] https://baltocdn.com/helm/stable/debian/ all main" | sudo tee /etc/apt/sources.list.d/helm-stable-debian.list
    sudo apt-get update
    sudo apt-get install helm
    
    # Verify installation
    if ! helm version &> /dev/null; then
        error "Helm installation failed"
    fi
    
    log "Helm installed successfully"
}

install_k3s() {
    log "Installing k3s..."
    
    if command -v k3s &> /dev/null; then
        warn "k3s already installed, skipping"
        return 0
    fi
    
    # Install k3s with disabled components (we'll use Helm versions)
    curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="--disable traefik --disable servicelb --disable local-storage" sh -
    
    # Configure kubectl for regular user
    mkdir -p ~/.kube
    sudo cp /etc/rancher/k3s/k3s.yaml ~/.kube/config
    sudo chown $USER:$USER ~/.kube/config
    
    # Fix localhost issue for multi-node setup - replace 127.0.0.1 with actual server IP
    sed -i "s/127.0.0.1/${SERVER_IP}/g" ~/.kube/config
    
    # Add to shell profile
    if ! grep -q "KUBECONFIG" ~/.bashrc; then
        echo 'export KUBECONFIG=~/.kube/config' >> ~/.bashrc
    fi
    
    export KUBECONFIG=~/.kube/config
    
    # Wait for k3s to be ready
    log "Waiting for k3s cluster to be ready..."
    timeout 60 bash -c 'until kubectl get nodes | grep Ready; do sleep 5; done'
    
    log "k3s installed and ready"
}

install_metallb() {
    log "Installing MetalLB for LoadBalancer services..."
    
    # Apply MetalLB manifests
    kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.13.12/config/manifests/metallb-native.yaml
    
    # Wait for MetalLB to be ready
    log "Waiting for MetalLB to be ready..."
    kubectl wait --namespace metallb-system \
                    --for=condition=ready pod \
                    --selector=app=metallb \
                    --timeout=90s
    
    # Create IP address pool configuration
    log "Configuring MetalLB IP pool: $METALLB_IP_RANGE"
    cat <<EOF | kubectl apply -f -
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: default-pool
  namespace: metallb-system
spec:
  addresses:
  - $METALLB_IP_RANGE
---
apiVersion: metallb.io/v1beta1
kind: L2Advertisement
metadata:
  name: default-advertisement
  namespace: metallb-system
spec:
  ipAddressPools:
  - default-pool
EOF
    
    log "MetalLB installed and configured"
}

install_storage() {
    log "Installing local-path-provisioner via Helm..."
    
    # Add Helm repository
    helm repo add local-path-provisioner https://github.com/rancher/local-path-provisioner || true
    helm repo update
    
    # Install local-path-provisioner
    helm install local-path-provisioner local-path-provisioner/local-path-provisioner \
      --namespace local-path-storage \
      --create-namespace \
      --set storageClass.defaultClass=true \
      --wait
    
    log "Storage provisioner installed"
}

verify_installation() {
    log "Verifying installation..."
    
    # Check nodes
    kubectl get nodes
    
    # Check storage class
    kubectl get storageclass
    
    # Check MetalLB
    kubectl get pods -n metallb-system
    kubectl get ipaddresspool -n metallb-system
    
    # Check Helm
    helm list -A
    
    log "Verification complete"
}

display_summary() {
    log "Phase 1 Foundation Setup Complete!"
    echo
    echo "=================================================================="
    echo "INSTALLATION SUMMARY"
    echo "=================================================================="
    echo "Server IP: $SERVER_IP"
    echo "MetalLB IP Range: $METALLB_IP_RANGE"
    echo "k3s Version: $(k3s --version | head -n1)"
    echo "Helm Version: $(helm version --short)"
    echo "Docker Version: $(docker --version)"
    echo
    echo "Next Steps:"
    echo "1. Log out and log back in to refresh Docker group membership"
    echo "2. Run 'kubectl get nodes' to verify cluster access"
    echo "3. Proceed to Phase 2: Core Infrastructure"
    echo "=================================================================="
}

main() {
    log "Starting Phase 1: Foundation Setup"
    
    check_prerequisites
    update_system
    install_docker
    install_helm
    install_k3s
    install_metallb
    install_storage
    verify_installation
    display_summary
    
    log "Phase 1 completed successfully!"
}

# Run main function
main "$@"
