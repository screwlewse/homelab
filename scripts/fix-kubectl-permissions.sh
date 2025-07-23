#!/bin/bash

# Fix kubectl permissions for k3s
# This script fixes common kubectl permission issues with k3s

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

info "🔧 Fixing kubectl permissions for k3s"
info "===================================="

# Check if k3s is installed
if ! command -v k3s &> /dev/null; then
    error "k3s is not installed on this system"
fi

# Check if this is a server or agent node
if systemctl is-active --quiet k3s 2>/dev/null; then
    NODE_TYPE="server"
    info "Detected k3s server (control plane) node"
elif systemctl is-active --quiet k3s-agent 2>/dev/null; then
    NODE_TYPE="agent"
    info "Detected k3s agent (worker) node"
else
    error "k3s service is not running"
fi

# Create .kube directory
mkdir -p "$HOME/.kube"

if [[ "$NODE_TYPE" == "server" ]]; then
    # For server nodes, copy the k3s config
    info "Configuring kubectl for server node..."
    
    if [[ -f /etc/rancher/k3s/k3s.yaml ]]; then
        # Backup existing config if it exists
        if [[ -f "$HOME/.kube/config" ]]; then
            cp "$HOME/.kube/config" "$HOME/.kube/config.backup-$(date +%Y%m%d-%H%M%S)"
            info "Backed up existing kubeconfig"
        fi
        
        # Copy and fix permissions
        sudo cp /etc/rancher/k3s/k3s.yaml "$HOME/.kube/config"
        sudo chown "$USER:$USER" "$HOME/.kube/config"
        chmod 600 "$HOME/.kube/config"
        
        # Fix localhost issue for multi-node setup - replace 127.0.0.1 with actual server IP
        SERVER_IP=$(hostname -I | awk '{print $1}')
        sed -i "s/127.0.0.1/$SERVER_IP/g" "$HOME/.kube/config"
        info "Updated kubeconfig to use server IP: $SERVER_IP"
        
        # Test kubectl
        if kubectl get nodes &>/dev/null; then
            success "✅ kubectl configured successfully for server node"
            kubectl get nodes
        else
            error "kubectl configuration failed"
        fi
    else
        error "k3s configuration file not found at /etc/rancher/k3s/k3s.yaml"
    fi
    
elif [[ "$NODE_TYPE" == "agent" ]]; then
    # For agent nodes, we need server info
    info "Configuring kubectl for worker node..."
    
    echo "This is a worker node. To configure kubectl, you need:"
    echo "1. The server URL (e.g., https://10.0.0.88:6443)"
    echo "2. The node token from the server"
    echo ""
    echo "Options:"
    echo "1. Run this script with server info:"
    echo "   $0 <server-url> <token>"
    echo ""
    echo "2. Copy kubeconfig from server:"
    echo "   scp server:~/.kube/config ~/.kube/config"
    echo ""
    echo "3. Use server kubectl remotely:"
    echo "   ssh server kubectl get nodes"
    
    # Check if arguments were provided
    if [[ $# -ge 2 ]]; then
        SERVER_URL="$1"
        SERVER_TOKEN="$2"
        
        info "Creating kubeconfig for worker node..."
        cat <<EOF > "$HOME/.kube/config"
apiVersion: v1
clusters:
- cluster:
    insecure-skip-tls-verify: true
    server: $SERVER_URL
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
    token: $SERVER_TOKEN
EOF
        
        chmod 600 "$HOME/.kube/config"
        
        # Test kubectl connection
        if kubectl get nodes &>/dev/null; then
            success "✅ kubectl configured successfully for worker node"
            kubectl get nodes
        else
            warn "kubectl configuration may need adjustment"
            info "You may need to copy the full kubeconfig from the control plane"
        fi
    fi
fi

# Add kubectl completion and aliases
info "Setting up kubectl enhancements..."

# Add to bashrc if not already present
if ! grep -q "kubectl completion" "$HOME/.bashrc" 2>/dev/null; then
    cat >> "$HOME/.bashrc" <<'EOF'

# kubectl completion and aliases
if command -v kubectl &> /dev/null; then
    source <(kubectl completion bash)
    alias k=kubectl
    complete -F __start_kubectl k
fi
EOF
    info "Added kubectl completion and aliases to ~/.bashrc"
fi

success "kubectl permissions fixed!"
info ""
info "Next steps:"
info "1. Source your bashrc: source ~/.bashrc"
info "2. Test kubectl: kubectl get nodes"
info "3. Use 'k' as shortcut for kubectl"