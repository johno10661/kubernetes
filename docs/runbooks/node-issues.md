# Runbook: Node Issues

## Node NotReady

### Symptoms
- Node shows `NotReady` status
- Pods on node are `Unknown` or not running

### Diagnosis

```bash
# Check node status
kubectl get nodes
kubectl describe node <node-name>

# Check kubelet on node
ssh root@<node-ip> systemctl status k3s

# Check kubelet logs
ssh root@<node-ip> journalctl -u k3s -f
```

### Common Causes & Fixes

#### Network connectivity
```bash
# From the problem node, check connectivity to other nodes
ping 192.168.100.70
ping 192.168.100.71
ping 192.168.100.81
```

#### Kubelet crashed
```bash
ssh root@<node-ip> systemctl restart k3s
```

#### Disk full
```bash
ssh root@<node-ip> df -h
# Clean up if needed
ssh root@<node-ip> crictl rmi --prune
```

#### Certificate expired
```bash
# Check certificate expiry
ssh root@<node-ip> openssl x509 -in /var/lib/rancher/k3s/server/tls/server-ca.crt -noout -dates
```

---

## Node Under Pressure

### Symptoms
- Pods being evicted
- Node conditions show pressure

### Diagnosis

```bash
# Check conditions
kubectl describe node <node-name> | grep -A10 Conditions

# Key conditions:
# - MemoryPressure
# - DiskPressure
# - PIDPressure
```

### Fix Memory Pressure

```bash
# SSH to node
ssh root@<node-ip>

# Check memory usage
free -h

# Find memory-heavy processes
ps aux --sort=-%mem | head -20

# If safe, restart k3s to clear caches
systemctl restart k3s
```

### Fix Disk Pressure

```bash
ssh root@<node-ip>

# Check disk usage
df -h

# Clean container images
crictl rmi --prune

# Clean old logs
journalctl --vacuum-time=7d

# Find large files
du -sh /var/lib/rancher/k3s/*
```

---

## Adding a New Node

### Prerequisites
- Debian 12+ or Ubuntu 22.04+
- Network connectivity to existing nodes
- SSH access

### Steps

1. **Get join token from existing node:**
```bash
ssh root@192.168.100.70 cat /var/lib/rancher/k3s/server/node-token
```

2. **Install K3s on new node:**
```bash
ssh root@<new-node-ip>
curl -sfL https://get.k3s.io | sh -s - server \
  --server https://192.168.100.70:6443 \
  --token <TOKEN> \
  --disable=traefik
```

3. **Verify node joined:**
```bash
kubectl get nodes
```

4. **Label node if needed:**
```bash
# Example: mark as amd64 for Sentry workloads
kubectl label node <node-name> kubernetes.io/arch=amd64
```

---

## Removing a Node

### Steps

1. **Cordon the node (prevent new pods):**
```bash
kubectl cordon <node-name>
```

2. **Drain pods from node:**
```bash
kubectl drain <node-name> --ignore-daemonsets --delete-emptydir-data
```

3. **On the node, uninstall K3s:**
```bash
ssh root@<node-ip> /usr/local/bin/k3s-uninstall.sh
```

4. **Remove node from cluster:**
```bash
kubectl delete node <node-name>
```

---

## Node Maintenance Window

Use the maintenance script:

```bash
# See current status
./scripts/node-maintenance.sh status www01

# Before maintenance
./scripts/node-maintenance.sh drain www01

# After maintenance
./scripts/node-maintenance.sh uncordon www01
```
