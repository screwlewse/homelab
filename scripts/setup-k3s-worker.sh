#!/bin/bash

# Setup k3s Worker Node
# This script joins a k3s worker node to an existing cluster

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

# Trap errors
trap 'error "Script failed on line $LINENO"' ERR

# Check for debug mode
DEBUG_MODE=false
if [[ "${1:-}" == "--debug" ]]; then
    DEBUG_MODE=true
    shift
    set -x
    info "🐛 Debug mode enabled"
fi

# Validate arguments
if [[ $# -lt 2 ]]; then
    echo "Usage: $0 [--debug] <k3s-server-url> <k3s-token>"
    echo ""
    echo "Options:"
    echo "  --debug    Enable verbose debug output"
    echo ""
    echo "Example:"
    echo "  $0 https://10.0.0.88:6443 K10abc123def456..."
    echo "  $0 --debug https://10.0.0.88:6443 K10abc123def456..."
    echo ""
    echo "To get the token from the server node:"
    echo "  1. SSH into your k3s server/control plane node"
    echo "  2. Run: sudo cat /var/lib/rancher/k3s/server/node-token"
    echo "  3. Copy the entire token (it's long!)"
    echo ""
    echo "The token format looks like:"
    echo "  K10[long-string]::server:[long-string]"
    exit 1
fi

K3S_URL="$1"
K3S_TOKEN="$2"

# Validate URL format
if ! [[ "$K3S_URL" =~ ^https://[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+:6443$ ]]; then
    warn "Server URL format looks incorrect. Expected format: https://IP:6443"
    warn "Got: $K3S_URL"
    echo ""
    echo "Continuing anyway, but this might fail..."
fi

# Validate token format (basic check)
if ! [[ "$K3S_TOKEN" =~ ^K1[01] ]]; then
    error "Token format looks incorrect. k3s tokens typically start with 'K10' or 'K11'"
fi

if [[ ${#K3S_TOKEN} -lt 100 ]]; then
    error "Token seems too short. k3s tokens are typically 100+ characters long"
fi

info "🚀 Setting up k3s worker node"
info "================================"
info "Server URL: $K3S_URL"

# Check if k3s is already installed
if command -v k3s &> /dev/null; then
    warn "k3s is already installed. Checking if it's a worker node..."
    if [[ -f /etc/systemd/system/k3s-agent.service ]]; then
        info "This is already a k3s worker node"
        exit 0
    else
        error "This appears to be a k3s server node. Cannot convert to worker."
    fi
fi

# Install prerequisites
info "Installing prerequisites..."
sudo apt-get update
sudo apt-get install -y curl netcat-openbsd

# Pre-installation connectivity checks
info "Checking connectivity to k3s server..."
if ! curl -k --max-time 10 "${K3S_URL}/healthz" &>/dev/null; then
    if ! nc -z -w5 $(echo "$K3S_URL" | cut -d'/' -f3 | cut -d':' -f1) 6443 &>/dev/null; then
        error "Cannot reach k3s server at $K3S_URL. Check network connectivity and firewall."
    fi
    warn "Server API not responding but port 6443 is reachable. Continuing..."
fi

# Clean up any previous installation attempts
info "Cleaning up any previous k3s agent installation..."
if command -v k3s-agent-uninstall.sh &>/dev/null; then
    sudo /usr/local/bin/k3s-agent-uninstall.sh || warn "Previous uninstall failed or no previous installation"
fi

# Kill any hanging k3s processes
sudo pkill -f k3s-agent || true
sudo systemctl stop k3s-agent 2>/dev/null || true
sudo systemctl disable k3s-agent 2>/dev/null || true

# Install k3s as agent (worker node) with timeout
info "Installing k3s agent with timeout protection..."

# Choose installation command based on debug mode
if [[ "$DEBUG_MODE" == "true" ]]; then
    info "🐛 Installing with debug output..."
    timeout 300 bash -c "
        curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC='agent --debug' K3S_URL='$K3S_URL' K3S_TOKEN='$K3S_TOKEN' sh -
    " || {
        error "k3s installation timed out after 5 minutes. Check logs: sudo journalctl -u k3s-agent"
    }
else
    timeout 300 bash -c "
        curl -sfL https://get.k3s.io | K3S_URL='$K3S_URL' K3S_TOKEN='$K3S_TOKEN' sh -
    " || {
        error "k3s installation timed out after 5 minutes. Check logs: sudo journalctl -u k3s-agent"
    }
fi

# Wait for k3s agent to start with better error reporting
info "Waiting for k3s agent to start..."
max_attempts=24
attempt=0
while [ $attempt -lt $max_attempts ]; do
    if sudo systemctl is-active --quiet k3s-agent; then
        info "✅ k3s agent is active"
        break
    fi
    
    # Check for common failure states
    if sudo systemctl is-failed --quiet k3s-agent; then
        error "k3s-agent service failed to start. Check logs: sudo journalctl -u k3s-agent -n 20"
    fi
    
    info "Waiting for k3s-agent to start... (attempt $((attempt + 1))/$max_attempts)"
    if [ $((attempt % 6)) -eq 5 ]; then
        info "📋 Current agent logs (last 5 lines):"
        sudo journalctl -u k3s-agent -n 5 --no-pager || true
    fi
    
    sleep 5
    ((attempt++))
done

# Check agent status with detailed diagnostics
if sudo systemctl is-active --quiet k3s-agent; then
    info "✅ k3s agent is running"
    
    # Show agent status
    info "📊 Agent service status:"
    sudo systemctl status k3s-agent --no-pager -l || true
    
    # Test connection to server
    info "🔗 Testing connection to k3s server..."
    if timeout 10 sudo k3s kubectl get nodes 2>/dev/null; then
        info "✅ Successfully connected to k3s server"
    else
        warn "Agent is running but cannot connect to server API. This may be normal for worker nodes."
    fi
else
    error "k3s agent failed to start. Detailed logs:"
    sudo journalctl -u k3s-agent -n 20 --no-pager || true
    echo ""
    info "Common fixes:"
    info "1. Verify token: sudo cat /var/lib/rancher/k3s/server/node-token (on server)"
    info "2. Check network: nc -zv $(echo '$K3S_URL' | cut -d'/' -f3 | cut -d':' -f1) 6443"
    info "3. Check firewall: sudo ufw status"
    info "4. Retry with: sudo systemctl restart k3s-agent"
    exit 1
fi

# Configure kubectl for worker node
info "Configuring kubectl for worker node..."
info "Using server URL: $K3S_URL"
mkdir -p "$HOME/.kube"

# Create kubeconfig for worker node
cat > "$HOME/.kube/config" <<EOF
apiVersion: v1
clusters:
- cluster:
    insecure-skip-tls-verify: true
    server: ${K3S_URL}
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
    token: ${K3S_TOKEN}
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

# Final verification
info "🔍 Final verification..."
HOSTNAME=$(hostname)
info "Worker node hostname: $HOSTNAME"

# Wait a moment for node registration
sleep 10

# Check if node appears in cluster (from server perspective)
info "Checking if node is registered in cluster..."
if timeout 30 sudo k3s kubectl get nodes 2>/dev/null | grep -q "$HOSTNAME"; then
    info "✅ Worker node successfully registered in cluster!"
    info "📋 Current cluster nodes:"
    sudo k3s kubectl get nodes 2>/dev/null || true
else
    warn "Node registration may still be in progress. Check from control plane:"
    info "  ssh controlplane 'kubectl get nodes'"
fi

# Show final status
info ""
info "🎉 Worker node setup complete!"
info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
info "✅ k3s-agent service: $(sudo systemctl is-active k3s-agent)"
info "🏷️  Node hostname: $HOSTNAME"
info "🔗 Server URL: $K3S_URL"
info ""
info "📋 To verify from the server node:"
info "   kubectl get nodes"
info "   kubectl get nodes -o wide"
info ""
info "🔧 If the node doesn't appear or shows 'NotReady':"
info "   1. Check agent logs: sudo journalctl -u k3s-agent -f"
info "   2. Verify network: nc -zv $(echo '$K3S_URL' | cut -d'/' -f3 | cut -d':' -f1) 6443"
info "   3. Check token: sudo cat /var/lib/rancher/k3s/server/node-token (on server)"
info "   4. Restart agent: sudo systemctl restart k3s-agent"
info ""
info "📖 For detailed troubleshooting: docs/MULTI-NODE.md"
info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"