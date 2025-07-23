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

# Validate arguments
if [[ $# -lt 2 ]]; then
    echo "Usage: $0 <k3s-server-url> <k3s-token>"
    echo ""
    echo "Example:"
    echo "  $0 https://10.0.0.88:6443 K10abc123def456..."
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
sudo apt-get install -y curl

# Install k3s as agent (worker node)
info "Installing k3s agent..."
curl -sfL https://get.k3s.io | K3S_URL="$K3S_URL" K3S_TOKEN="$K3S_TOKEN" sh -

# Wait for k3s agent to start
info "Waiting for k3s agent to start..."
sleep 10

# Check agent status
if sudo systemctl is-active --quiet k3s-agent; then
    info "✅ k3s agent is running"
else
    error "k3s agent failed to start"
fi

# Show node info
info "Worker node setup complete!"
info ""
info "To verify from the server node, run:"
info "  kubectl get nodes"
info ""
info "This node should appear in the list with status 'Ready'"
info ""
info "If the node doesn't appear or shows 'NotReady':"
info "  1. Check the agent logs: sudo journalctl -u k3s-agent -f"
info "  2. Verify network connectivity to $K3S_URL"
info "  3. Ensure the token is correct (get fresh token if needed)"
info ""
info "For detailed troubleshooting, see: docs/MULTI-NODE.md"