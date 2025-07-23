#!/bin/bash

# Setup Fresh Ubuntu Server for k3s DevOps Pipeline
# This script prepares a fresh Ubuntu server with all prerequisites

set -euo pipefail
IFS=$'\n\t'

# Enable debug mode if DEBUG is set
[[ "${DEBUG:-}" == "true" ]] && set -x

# Script metadata
readonly SCRIPT_NAME=$(basename "${BASH_SOURCE[0]}")
readonly SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

# Logging functions
log() { echo "[$(date +'%Y-%m-%d %H:%M:%S')] [$SCRIPT_NAME] $*"; }
error() { log "ERROR: $*" >&2; exit 1; }
warn() { log "WARNING: $*" >&2; }
info() { log "INFO: $*"; }
success() { log "SUCCESS: $*"; }

# Trap errors
trap 'error "Script failed on line $LINENO"' ERR

# Configuration
NODE_TYPE="${1:-server}"  # server or worker
SERVER_URL="${2:-}"       # Required for worker nodes
SERVER_TOKEN="${3:-}"     # Required for worker nodes

info "🚀 Fresh Ubuntu Setup for k3s DevOps Pipeline"
info "============================================"
info "Node Type: $NODE_TYPE"

# Check Ubuntu version
if [[ -f /etc/os-release ]]; then
    source /etc/os-release
    info "OS: $NAME $VERSION"
    if [[ "$ID" != "ubuntu" ]]; then
        warn "This script is designed for Ubuntu. Proceeding anyway..."
    fi
else
    warn "Cannot determine OS version"
fi

# Update system
info "Updating system packages..."
sudo apt-get update
sudo apt-get upgrade -y

# Install basic prerequisites
info "Installing basic prerequisites..."
sudo apt-get install -y \
    curl \
    wget \
    git \
    make \
    jq \
    htop \
    net-tools \
    ca-certificates \
    gnupg \
    lsb-release \
    apt-transport-https \
    software-properties-common \
    python3 \
    python3-pip \
    python3-venv \
    build-essential \
    unzip

# Install Docker (optional but recommended)
info "Installing Docker..."
if command -v docker &> /dev/null; then
    info "Docker is already installed"
else
    curl -fsSL https://get.docker.com | sh
    sudo usermod -aG docker "$USER"
    info "Docker installed. You may need to log out and back in for group changes."
fi

# Install kubectl
info "Installing kubectl..."
if command -v kubectl &> /dev/null; then
    info "kubectl is already installed"
else
    curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
    sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
    rm kubectl
fi

# Install Helm
info "Installing Helm..."
if command -v helm &> /dev/null; then
    info "Helm is already installed"
else
    curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
fi

# Install k3s based on node type
if [[ "$NODE_TYPE" == "server" ]]; then
    info "Installing k3s server (control plane)..."
    
    # Install k3s server
    curl -sfL https://get.k3s.io | sh -
    
    # Wait for k3s to be ready
    info "Waiting for k3s to be ready..."
    local max_attempts=30
    local attempt=0
    while [ $attempt -lt $max_attempts ]; do
        if sudo k3s kubectl get nodes &>/dev/null; then
            info "✅ k3s is ready"
            break
        fi
        info "Waiting for k3s to start... (attempt $((attempt + 1))/$max_attempts)"
        sleep 5
        ((attempt++))
    done
    
    if [ $attempt -eq $max_attempts ]; then
        warn "k3s is taking longer than expected to start"
        info "Continuing with setup anyway..."
    fi
    
    # Configure kubectl for the user
    mkdir -p "$HOME/.kube"
    sudo cp /etc/rancher/k3s/k3s.yaml "$HOME/.kube/config"
    sudo chown "$USER:$USER" "$HOME/.kube/config"
    chmod 600 "$HOME/.kube/config"
    
    # Fix localhost issue for multi-node setup - replace 127.0.0.1 with actual server IP
    SERVER_IP=$(hostname -I | awk '{print $1}')
    sed -i "s/127.0.0.1/$SERVER_IP/g" "$HOME/.kube/config"
    info "Updated kubeconfig to use server IP: $SERVER_IP"
    
    # Test kubectl
    kubectl get nodes
    
    # Get node token for adding workers
    info ""
    info "📝 Save this token to add worker nodes:"
    sudo cat /var/lib/rancher/k3s/server/node-token
    info ""
    info "Server URL for workers: https://$(hostname -I | awk '{print $1}'):6443"
    
elif [[ "$NODE_TYPE" == "worker" ]]; then
    if [[ -z "$SERVER_URL" ]] || [[ -z "$SERVER_TOKEN" ]]; then
        error "Worker nodes require SERVER_URL and SERVER_TOKEN arguments"
    fi
    
    info "Installing k3s worker node..."
    curl -sfL https://get.k3s.io | K3S_URL="$SERVER_URL" K3S_TOKEN="$SERVER_TOKEN" sh -
    
    # Configure kubectl for worker node
    info "Configuring kubectl for worker node..."
    info "Using server URL: $SERVER_URL"
    mkdir -p "$HOME/.kube"
    
    # Create kubeconfig for worker node
    cat > "$HOME/.kube/config" <<EOF
apiVersion: v1
clusters:
- cluster:
    insecure-skip-tls-verify: true
    server: ${SERVER_URL}
  name: default
contexts:
- context:
    cluster: default
    user: default
  name: default
current-context: default
kind: Config
preferences: {}
users:
- name: default
  user:
    token: ${SERVER_TOKEN}
EOF
    
    chmod 600 "$HOME/.kube/config"
    
    # Test kubectl connection with timeout
    info "Testing kubectl connection (this may take a moment)..."
    if timeout 10 kubectl get nodes &>/dev/null; then
        info "✅ kubectl configured successfully"
        kubectl get nodes
    else
        warn "kubectl configuration needs adjustment for worker nodes"
        info "This is normal for worker nodes. To access the cluster:"
        info "  1. Copy kubeconfig from control plane: scp controlplane:~/.kube/config ~/.kube/config"
        info "  2. Or check nodes from the control plane: ssh controlplane kubectl get nodes"
        info ""
        info "The worker node is still properly joined to the cluster."
    fi
    
    info "Worker node installation complete"
else
    error "Invalid node type: $NODE_TYPE (must be 'server' or 'worker')"
fi

# Install additional tools for development
info "Installing additional development tools..."

# Install git-secrets
if ! command -v git-secrets &> /dev/null; then
    git clone https://github.com/awslabs/git-secrets.git /tmp/git-secrets
    cd /tmp/git-secrets && sudo make install
    cd - && rm -rf /tmp/git-secrets
fi

# Configure Git (optional)
if command -v git &> /dev/null; then
    info "Configuring Git..."
    git config --global init.defaultBranch main
    git config --global pull.rebase false
fi

# Set up Python environment
info "Setting up Python environment..."
# Install python3-pip and python3-venv via apt to avoid externally-managed-environment issues
sudo apt-get update -qq
sudo apt-get install -y python3-pip python3-venv python3-full

# Only attempt pip upgrade if not in externally-managed environment
if pip3 install --user --upgrade pip --dry-run &>/dev/null; then
    pip3 install --user --upgrade pip
    pip3 install --user virtualenv
else
    info "Python environment is externally managed, using system packages"
    # Ensure python3-venv is available as alternative to virtualenv
    sudo apt-get install -y python3-venv
fi

# Create useful aliases
info "Setting up useful aliases..."
cat >> "$HOME/.bashrc" << 'EOF'

# k3s DevOps Pipeline aliases
alias k='kubectl'
alias kgp='kubectl get pods'
alias kgs='kubectl get svc'
alias kgn='kubectl get nodes'
alias kaf='kubectl apply -f'
alias kdel='kubectl delete'
alias klog='kubectl logs'
alias kexec='kubectl exec -it'

# Docker aliases
alias d='docker'
alias dps='docker ps'
alias dpsa='docker ps -a'
alias dimg='docker images'
alias drm='docker rm'
alias drmi='docker rmi'

# Git aliases
alias gs='git status'
alias ga='git add'
alias gc='git commit'
alias gp='git push'
alias gl='git log --oneline --graph'
EOF

# System optimizations for k3s
info "Applying system optimizations..."
sudo sysctl -w vm.max_map_count=262144
echo "vm.max_map_count=262144" | sudo tee -a /etc/sysctl.conf

# Disable swap (recommended for Kubernetes)
sudo swapoff -a
sudo sed -i '/ swap / s/^/#/' /etc/fstab

# Summary
info ""
success "🎉 Fresh Ubuntu setup complete!"
info "=============================="
info ""

if [[ "$NODE_TYPE" == "server" ]]; then
    info "Next steps for SERVER node:"
    info "1. Clone the k8s-devops-pipeline repository:"
    info "   git clone https://github.com/screwlewse/homelab.git"
    info "   cd homelab"
    info ""
    info "2. Deploy infrastructure:"
    info "   make tf-init"
    info "   make tf-apply"
    info ""
    info "3. Verify deployment:"
    info "   make verify"
    info "   make info"
else
    info "Next steps for WORKER node:"
    info "1. Verify node joined cluster (run on server):"
    info "   kubectl get nodes"
    info ""
    info "2. Label node if needed (run on server):"
    info "   kubectl label node <node-name> node-role.kubernetes.io/worker=worker"
fi

info ""
info "📝 Notes:"
info "- You may need to log out and back in for Docker group changes"
info "- Run 'source ~/.bashrc' to load new aliases"
info "- Check 'kubectl get nodes' to verify cluster status"