#!/bin/bash

# Robust k3s Worker Setup with Comprehensive Debugging
# Usage: ./setup-worker-robust.sh SERVER_IP TOKEN

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
SERVER_URL="https://$SERVER_IP:6443"

echo "🚀 Robust k3s Worker Setup"
echo "=========================="
echo "Server: $SERVER_IP"
echo "Token: ${TOKEN:0:20}..."
echo ""

# Pre-flight checks
echo "🔍 Pre-flight checks..."

# 1. Network connectivity
echo "Testing network connectivity..."
if ! ping -c 3 "$SERVER_IP" >/dev/null 2>&1; then
    echo "❌ Cannot ping server $SERVER_IP"
    echo "Check network connectivity and server IP"
    exit 1
fi
echo "✅ Ping successful"

# 2. Port 6443 check
echo "Testing port 6443..."
if ! nc -z -w10 "$SERVER_IP" 6443 >/dev/null 2>&1; then
    echo "❌ Cannot reach port 6443 on $SERVER_IP"
    echo "Check firewall settings on both server and worker"
    exit 1
fi
echo "✅ Port 6443 reachable"

# 3. API endpoint check
echo "Testing k3s API endpoint..."
if ! timeout 10 curl -k "$SERVER_URL/healthz" >/dev/null 2>&1; then
    echo "⚠️  API endpoint not responding (but port is open)"
    echo "Continuing anyway - this may be normal during startup"
else
    echo "✅ API endpoint responding"
fi

echo ""

# Clean up any previous installation
echo "🧹 Cleaning up previous installation..."
sudo pkill -f k3s-agent 2>/dev/null || true
sudo systemctl stop k3s-agent 2>/dev/null || true
sudo systemctl disable k3s-agent 2>/dev/null || true

if command -v k3s-agent-uninstall.sh &>/dev/null; then
    echo "Uninstalling previous k3s-agent..."
    sudo /usr/local/bin/k3s-agent-uninstall.sh || true
fi

# Remove any cached certificates that might cause issues
sudo rm -rf /var/lib/rancher/k3s/agent/ 2>/dev/null || true

echo ""

# Install k3s agent with verbose logging
echo "📦 Installing k3s agent..."
echo "This may take 2-3 minutes..."

# Create a script to run the installation with better error handling
cat > /tmp/k3s-install.sh << EOF
#!/bin/bash
set -x
export K3S_URL="$SERVER_URL"
export K3S_TOKEN="$TOKEN"
export INSTALL_K3S_EXEC="agent --debug --kubelet-arg=v=2 --kube-proxy-arg=v=2"
curl -sfL https://get.k3s.io | sh -
EOF

chmod +x /tmp/k3s-install.sh

if timeout 600 /tmp/k3s-install.sh; then
    echo "✅ k3s installation completed"
else
    echo "❌ k3s installation failed or timed out"
    echo ""
    echo "📄 Installation logs:"
    cat /var/log/k3s-install.log 2>/dev/null || echo "No install log found"
    exit 1
fi

rm -f /tmp/k3s-install.sh

echo ""

# Wait for service with detailed monitoring
echo "⏳ Waiting for k3s-agent to become ready..."
echo "Monitoring service startup (max 5 minutes)..."

max_attempts=60  # 5 minutes with 5-second intervals
attempt=0

while [ $attempt -lt $max_attempts ]; do
    if sudo systemctl is-active --quiet k3s-agent; then
        echo "✅ k3s-agent service is active"
        break
    fi
    
    if sudo systemctl is-failed --quiet k3s-agent; then
        echo "❌ k3s-agent service failed"
        echo ""
        echo "📄 Service status:"
        sudo systemctl status k3s-agent --no-pager
        echo ""
        echo "📄 Recent logs:"
        sudo journalctl -u k3s-agent -n 30 --no-pager
        exit 1
    fi
    
    attempt=$((attempt + 1))
    echo "Waiting for service... ($attempt/$max_attempts)"
    
    # Show logs every 30 seconds
    if [ $((attempt % 6)) -eq 0 ]; then
        echo "📄 Current logs (last 5 lines):"
        sudo journalctl -u k3s-agent -n 5 --no-pager || true
        echo ""
    fi
    
    sleep 5
done

if [ $attempt -eq $max_attempts ]; then
    echo "❌ Service failed to start within 5 minutes"
    echo ""
    echo "📄 Final service status:"
    sudo systemctl status k3s-agent --no-pager
    echo ""
    echo "📄 Full logs:"
    sudo journalctl -u k3s-agent --no-pager
    exit 1
fi

echo ""

# Verify node registration
echo "🔗 Verifying node registration..."
echo "Checking if node appears in cluster..."

# Wait up to 2 minutes for node to register
for i in {1..24}; do
    if timeout 10 sudo k3s kubectl get nodes 2>/dev/null | grep -q "$(hostname)"; then
        echo "✅ Node successfully registered in cluster!"
        echo ""
        echo "📋 Cluster nodes:"
        sudo k3s kubectl get nodes 2>/dev/null || echo "Unable to list nodes from worker"
        break
    fi
    
    if [ $i -eq 24 ]; then
        echo "⚠️  Node registration taking longer than expected"
        echo "This may be normal - check from control plane:"
        echo "  ssh $SERVER_IP 'kubectl get nodes'"
    else
        echo "Waiting for node registration... ($i/24)"
        sleep 5
    fi
done

echo ""

# Final status
echo "🎉 Setup complete!"
echo "=================="
echo "✅ k3s-agent service: $(sudo systemctl is-active k3s-agent)"
echo "🏷️  Node hostname: $(hostname)"
echo "🔗 Server URL: $SERVER_URL"
echo ""
echo "📋 Verify from control plane ($SERVER_IP):"
echo "   kubectl get nodes"
echo "   kubectl get nodes -o wide"
echo ""
echo "🔧 If issues persist:"
echo "   1. Check logs: sudo journalctl -u k3s-agent -f"
echo "   2. Run diagnostics: curl -sfL https://raw.githubusercontent.com/screwlewse/homelab/main/scripts/diagnose-worker.sh | bash"
echo "   3. Restart service: sudo systemctl restart k3s-agent"