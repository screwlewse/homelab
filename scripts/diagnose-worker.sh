#!/bin/bash

# Worker Node Diagnostic Script
# Run this on the worker node to diagnose connection issues

echo "🔍 k3s Worker Node Diagnostics"
echo "=============================="

# Basic info
echo "📋 System Info:"
echo "Hostname: $(hostname)"
echo "IP Address: $(hostname -I | awk '{print $1}')"
echo "Date: $(date)"
echo ""

# Network connectivity
echo "🌐 Network Connectivity:"
SERVER_IP="10.0.0.88"
echo "Testing connection to k3s server ($SERVER_IP)..."

# Test ping
if ping -c 3 "$SERVER_IP" >/dev/null 2>&1; then
    echo "✅ Ping to $SERVER_IP: SUCCESS"
else
    echo "❌ Ping to $SERVER_IP: FAILED"
fi

# Test port 6443
if nc -z -w5 "$SERVER_IP" 6443 >/dev/null 2>&1; then
    echo "✅ Port 6443 connection: SUCCESS"
else
    echo "❌ Port 6443 connection: FAILED"
fi

# Test HTTPS endpoint
if curl -k --max-time 10 "https://$SERVER_IP:6443/healthz" >/dev/null 2>&1; then
    echo "✅ HTTPS API endpoint: SUCCESS"
else
    echo "❌ HTTPS API endpoint: FAILED"
fi

echo ""

# k3s service status
echo "🔧 k3s Service Status:"
if systemctl is-active k3s-agent >/dev/null 2>&1; then
    echo "✅ k3s-agent service: ACTIVE"
else
    echo "❌ k3s-agent service: INACTIVE"
fi

if systemctl is-enabled k3s-agent >/dev/null 2>&1; then
    echo "✅ k3s-agent enabled: YES"
else
    echo "❌ k3s-agent enabled: NO"
fi

echo ""

# Recent logs
echo "📄 Recent k3s-agent logs (last 20 lines):"
echo "----------------------------------------"
sudo journalctl -u k3s-agent -n 20 --no-pager

echo ""

# Process info
echo "🔍 k3s Processes:"
ps aux | grep k3s | grep -v grep || echo "No k3s processes found"

echo ""

# Firewall status
echo "🔥 Firewall Status:"
if command -v ufw >/dev/null 2>&1; then
    sudo ufw status
else
    echo "ufw not installed"
fi

echo ""

# Disk space
echo "💾 Disk Space:"
df -h / /var /tmp

echo ""

# Memory
echo "🧠 Memory Usage:"
free -h

echo ""
echo "🎯 Quick Fixes to Try:"
echo "1. Restart k3s-agent: sudo systemctl restart k3s-agent"
echo "2. Check firewall: sudo ufw allow 6443/tcp"
echo "3. Get fresh token from server: sudo cat /var/lib/rancher/k3s/server/node-token"
echo "4. Reinstall with correct token"