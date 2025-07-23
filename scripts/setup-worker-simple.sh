#!/bin/bash

# Simple k3s Worker Setup
# Usage: ./setup-worker-simple.sh SERVER_IP TOKEN

set -e

if [[ $# -ne 2 ]]; then
    echo "Usage: $0 SERVER_IP TOKEN"
    echo ""
    echo "Get token from server: sudo cat /var/lib/rancher/k3s/server/node-token"
    echo "Example: $0 10.0.0.88 K10abc123..."
    exit 1
fi

SERVER_IP="$1"
TOKEN="$2"

echo "🚀 Setting up k3s worker node..."
echo "Server: $SERVER_IP"
echo "Token: ${TOKEN:0:20}..."

# Clean up any previous installation
sudo pkill -f k3s-agent 2>/dev/null || true
if command -v k3s-agent-uninstall.sh &>/dev/null; then
    sudo /usr/local/bin/k3s-agent-uninstall.sh || true
fi

# Install k3s agent
echo "Installing k3s agent..."
curl -sfL https://get.k3s.io | K3S_URL="https://$SERVER_IP:6443" K3S_TOKEN="$TOKEN" sh -

# Wait for service to start
echo "Waiting for k3s-agent to start..."
for i in {1..30}; do
    if sudo systemctl is-active --quiet k3s-agent; then
        echo "✅ k3s-agent is running"
        break
    fi
    echo "Waiting... ($i/30)"
    sleep 2
done

# Check service status
if sudo systemctl is-active --quiet k3s-agent; then
    echo "✅ Worker node setup complete!"
    echo ""
    echo "Check from control plane:"
    echo "  ssh $SERVER_IP 'kubectl get nodes'"
else
    echo "❌ Setup failed. Check logs:"
    echo "  sudo journalctl -u k3s-agent -n 20"
    exit 1
fi