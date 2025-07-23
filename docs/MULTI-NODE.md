# Multi-Node k3s Cluster Guide

This guide provides comprehensive instructions for setting up and managing multi-node k3s clusters using the k8s-devops-pipeline.

## Table of Contents

- [Understanding k3s Architecture](#understanding-k3s-architecture)
- [Prerequisites](#prerequisites)
- [Setting Up Worker Nodes](#setting-up-worker-nodes)
- [Node Management](#node-management)
- [Networking Considerations](#networking-considerations)
- [Storage in Multi-Node Clusters](#storage-in-multi-node-clusters)
- [Troubleshooting](#troubleshooting)
- [Best Practices](#best-practices)

## Understanding k3s Architecture

### Server Node (Control Plane)
- Runs the Kubernetes API server
- Manages cluster state (etcd)
- Schedules workloads
- Contains the node token for authentication

### Worker Nodes (Agents)
- Run container workloads
- Connect to server node via token authentication
- Execute instructions from the control plane

### Node Token Explained

The k3s node token is a secure authentication mechanism that:
- Allows worker nodes to join the cluster
- Contains encrypted cluster CA information
- Is generated automatically when k3s server starts
- Should be treated like a password

## Prerequisites

### For All Nodes
- Ubuntu 20.04+ (tested on Ubuntu 24.04)
- Minimum 2 CPU cores, 2GB RAM
- Static IP address or reliable DHCP reservation
- Network connectivity between all nodes
- Open firewall ports (see Networking section)

### Network Requirements
- All nodes must be on the same network or have routing configured
- No NAT between nodes (or properly configured if required)

## Setting Up Worker Nodes

### Step-by-Step Process

#### 1. Prepare the Server Node

First, ensure your server node is running and get the required information:

```bash
# SSH into your server node
ssh user@server-ip

# Verify k3s is running
sudo systemctl status k3s

# Get the node token (SAVE THIS SECURELY)
sudo cat /var/lib/rancher/k3s/server/node-token

# Example token format:
# K10c843b1f6b8c1d23456789abcdef0123456789abcdef0123456789abcdef01::server:1234567890abcdef1234567890abcdef

# Get your server's IP address
hostname -I | awk '{print $1}'
# Example: 10.0.0.88
```

#### 2. Prepare the Worker Node

On a fresh Ubuntu installation:

```bash
# Option 1: One-line installation (recommended)
curl -sfL https://raw.githubusercontent.com/screwlewse/homelab/main/scripts/setup-fresh-ubuntu.sh | \
  bash -s -- worker https://YOUR_SERVER_IP:6443 YOUR_NODE_TOKEN

# Option 2: Clone and run locally
git clone https://github.com/screwlewse/homelab.git
cd homelab
./scripts/setup-fresh-ubuntu.sh worker https://10.0.0.88:6443 K10c843b1f6b8c1d23456789abcdef...
```

For existing Ubuntu installations with prerequisites:

```bash
# Just run the worker setup script (now includes kubectl configuration)
./scripts/setup-k3s-worker.sh https://10.0.0.88:6443 K10c843b1f6b8c1d23456789abcdef...
```

#### 3. Verify Node Joined

Back on the server node:

```bash
# Check nodes
kubectl get nodes

# Expected output:
NAME         STATUS   ROLES                  AGE   VERSION
k3s-server   Ready    control-plane,master   1d    v1.32.6+k3s1
k3s-worker1  Ready    <none>                 5m    v1.32.6+k3s1

# Get more details
kubectl get nodes -o wide

# Check node resources
kubectl top nodes
```

## Node Management

### Labeling Nodes

Labels help with workload scheduling:

```bash
# Add role label to worker
kubectl label node k3s-worker1 node-role.kubernetes.io/worker=worker

# Add custom labels
kubectl label node k3s-worker1 disktype=ssd
kubectl label node k3s-worker1 zone=us-east-1a

# View labels
kubectl get nodes --show-labels
```

### Node Taints and Tolerations

Control where pods can be scheduled:

```bash
# Taint a node for specific workloads
kubectl taint nodes k3s-worker1 dedicated=gpu:NoSchedule

# Remove a taint
kubectl taint nodes k3s-worker1 dedicated-

# Example pod with toleration:
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: gpu-pod
spec:
  tolerations:
  - key: "dedicated"
    operator: "Equal"
    value: "gpu"
    effect: "NoSchedule"
  containers:
  - name: gpu-container
    image: nvidia/cuda:11.0-base
EOF
```

### Draining and Removing Nodes

Safely remove a node from the cluster:

```bash
# Step 1: Cordon the node (prevent new pods)
kubectl cordon k3s-worker1

# Step 2: Drain the node (move existing pods)
kubectl drain k3s-worker1 --ignore-daemonsets --delete-emptydir-data

# Step 3: Delete the node from cluster
kubectl delete node k3s-worker1

# Step 4: On the worker node, uninstall k3s
sudo /usr/local/bin/k3s-agent-uninstall.sh
```

## Networking Considerations

### Required Ports

Ensure these ports are open between nodes:

| Port | Protocol | Direction | Purpose |
|------|----------|-----------|---------|
| 6443 | TCP | Worker→Server | Kubernetes API |
| 10250 | TCP | Bidirectional | Kubelet metrics |
| 10251 | TCP | Bidirectional | Scheduler |
| 10252 | TCP | Bidirectional | Controller |
| 8472 | UDP | Bidirectional | Flannel VXLAN |
| 51820 | UDP | Bidirectional | WireGuard (if using) |

### Firewall Configuration

Ubuntu with ufw:

```bash
# On server node
sudo ufw allow 6443/tcp
sudo ufw allow 10250/tcp
sudo ufw allow 8472/udp
sudo ufw allow 51820/udp

# On worker nodes
sudo ufw allow 10250/tcp
sudo ufw allow 8472/udp
sudo ufw allow 51820/udp
```

### Testing Connectivity

```bash
# From worker to server API
curl -k https://SERVER_IP:6443/healthz

# Check flannel interfaces
ip addr show | grep flannel

# Test pod-to-pod communication
kubectl run test-pod --image=busybox --rm -it -- /bin/sh
# Inside pod: ping other-pod-ip
```

## Storage in Multi-Node Clusters

### Local Storage Limitations

By default, k3s uses local-path-provisioner, which has limitations:
- Pods are tied to the node where the PVC was created
- No data replication
- Pod cannot migrate to another node

### Distributed Storage Options

#### 1. Longhorn (Recommended for homelab)

```bash
# Install Longhorn
kubectl apply -f https://raw.githubusercontent.com/longhorn/longhorn/v1.5.1/deploy/longhorn.yaml

# Create StorageClass
cat <<EOF | kubectl apply -f -
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: longhorn
provisioner: driver.longhorn.io
parameters:
  numberOfReplicas: "2"
  staleReplicaTimeout: "2880"
EOF
```

#### 2. NFS Storage

```bash
# Install NFS provisioner
helm repo add nfs-subdir-external-provisioner https://kubernetes-sigs.github.io/nfs-subdir-external-provisioner/
helm install nfs-subdir-external-provisioner nfs-subdir-external-provisioner/nfs-subdir-external-provisioner \
  --set nfs.server=NFS_SERVER_IP \
  --set nfs.path=/exported/path
```

## Troubleshooting

### Common Issues and Solutions

#### kubectl Permission Issues

If kubectl requires sudo or shows certificate errors:

```bash
# On control plane (server) node
sudo cp /etc/rancher/k3s/k3s.yaml ~/.kube/config
sudo chown $USER:$USER ~/.kube/config
chmod 600 ~/.kube/config

# Or use the fix script
./scripts/fix-kubectl-permissions.sh

# Or use k3s kubectl directly
sudo k3s kubectl get nodes
```

For worker nodes, kubectl should be configured automatically by the setup scripts. If not:

```bash
# Option 1: Copy from control plane
scp controlplane:~/.kube/config ~/.kube/config

# Option 2: Use the fix script with server info
./scripts/fix-kubectl-permissions.sh https://10.0.0.88:6443 K10abc123...

# Option 3: Access via SSH to control plane
ssh controlplane kubectl get nodes
```

#### Worker Node Won't Join

1. **Check token format**:
   ```bash
   # Token should look like:
   # K10[long-string]::server:[long-string]
   
   # If token is wrong, get it again from server:
   sudo cat /var/lib/rancher/k3s/server/node-token
   ```

2. **Verify network connectivity**:
   ```bash
   # From worker node
   ping SERVER_IP
   telnet SERVER_IP 6443
   curl -k https://SERVER_IP:6443
   ```

3. **Check k3s-agent logs**:
   ```bash
   # On worker node
   sudo journalctl -u k3s-agent -f
   
   # Common errors:
   # "certificate signed by unknown authority" - Wrong token
   # "connection refused" - Network/firewall issue
   # "unauthorized" - Token mismatch
   ```

#### Node Shows NotReady

```bash
# Check node conditions
kubectl describe node WORKER_NODE_NAME

# Check system resources
free -h
df -h

# Check k3s-agent service
sudo systemctl status k3s-agent
```

#### Pod Scheduling Issues

```bash
# Check node capacity
kubectl describe node WORKER_NODE_NAME | grep -A 10 "Allocated resources"

# Check for taints
kubectl describe node WORKER_NODE_NAME | grep Taints

# Force pod to specific node
kubectl run test --image=nginx --overrides='{"spec":{"nodeSelector":{"kubernetes.io/hostname":"WORKER_NODE_NAME"}}}'
```

### Debug Commands

```bash
# Overall cluster health
kubectl cluster-info
kubectl get componentstatuses

# Node debugging
kubectl get events --all-namespaces --sort-by='.lastTimestamp'
kubectl top nodes
kubectl describe nodes

# Network debugging
kubectl run debug --image=nicolaka/netshoot --rm -it -- /bin/bash
# Inside pod: various network tools available
```

## Best Practices

### 1. Node Naming
- Use descriptive names: `k3s-worker-gpu-01`, `k3s-worker-ssd-02`
- Include location or purpose in name

### 2. Resource Management
- Set resource requests and limits on pods
- Use node affinity for workload placement
- Monitor node resources regularly

### 3. High Availability
- For production, use odd number of server nodes (3, 5)
- Distribute workers across failure domains
- Use anti-affinity rules for replicated pods

### 4. Security
- Rotate tokens periodically
- Use network policies to restrict pod communication
- Enable audit logging
- Regular security updates

### 5. Monitoring
- Deploy Prometheus node-exporter on all nodes
- Set up alerts for node health
- Monitor disk usage on nodes

### Example: Deploy Workload Across Nodes

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: distributed-app
spec:
  replicas: 3
  selector:
    matchLabels:
      app: distributed-app
  template:
    metadata:
      labels:
        app: distributed-app
    spec:
      affinity:
        podAntiAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
          - labelSelector:
              matchExpressions:
              - key: app
                operator: In
                values:
                - distributed-app
            topologyKey: kubernetes.io/hostname
      containers:
      - name: app
        image: nginx
        resources:
          requests:
            memory: "64Mi"
            cpu: "250m"
          limits:
            memory: "128Mi"
            cpu: "500m"
```

This ensures pods are distributed across different nodes for high availability.

## Next Steps

After setting up your multi-node cluster:

1. **Install distributed storage** (Longhorn recommended)
2. **Deploy the DevOps stack** using the main README instructions
3. **Configure monitoring** to track all nodes
4. **Set up node-specific workloads** using labels and taints
5. **Test failover scenarios** to ensure resilience

For more help, refer to the main [README.md](../README.md) or open an issue on GitHub.