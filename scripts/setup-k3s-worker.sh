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
    echo "  sudo cat /var/lib/rancher/k3s/server/node-token"
    exit 1
fi

K3S_URL="$1"
K3S_TOKEN="$2"

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