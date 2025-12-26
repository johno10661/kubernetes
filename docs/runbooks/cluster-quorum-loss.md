# Runbook: Cluster Quorum Loss (2 Nodes Dead)

## Understanding Quorum

K3s uses embedded etcd for cluster state. With 3 control-plane nodes:

| Nodes Alive | Quorum | Cluster State |
|-------------|--------|---------------|
| 3           | Yes    | Fully operational |
| 2           | Yes    | Operational (degraded) |
| 1           | No     | Read-only, no changes possible |
| 0           | No     | Down |

**Quorum = majority of nodes must be reachable** (2 of 3, 3 of 5, etc.)

## Scenario: 2 Nodes Temporarily Down

If nodes are coming back (reboot, network issue, maintenance):

### Just Wait

1. The surviving node keeps running pods but can't make changes
2. When one more node comes back, quorum is restored
3. Cluster automatically resumes normal operation

### Verify Recovery

```bash
# Check etcd cluster health
kubectl get --raw /healthz/etcd

# Check all nodes are Ready
kubectl get nodes

# Check etcd member list (from any node)
ssh root@192.168.100.70 \
  k3s kubectl exec -n kube-system etcd-www01 -- \
  etcdctl member list --write-out=table
```

## Scenario: 2 Nodes Permanently Lost

If two nodes are destroyed and not coming back, you must restore from
the surviving node.

### Step 1: Identify the Surviving Node

```bash
# SSH to each node IP and check if K3s is running
ssh root@192.168.100.70 systemctl status k3s  # www01
ssh root@192.168.100.71 systemctl status k3s  # www02
ssh root@192.168.100.81 systemctl status k3s  # tr1
```

### Step 2: Reset to Single-Node Cluster

On the **surviving node**, reset etcd to single-node mode:

```bash
# Stop K3s
systemctl stop k3s

# Backup current etcd data
cp -r /var/lib/rancher/k3s/server/db /var/lib/rancher/k3s/server/db.bak

# Reset cluster to single node
k3s server --cluster-reset

# This will:
# - Remove dead members from etcd
# - Reset cluster to single-node mode
# - Preserve all Kubernetes objects (deployments, services, etc.)

# Start K3s normally
systemctl start k3s
```

### Step 3: Verify Single-Node Operation

```bash
# Check node is Ready
kubectl get nodes

# Check pods are running
kubectl get pods -A

# Verify etcd has only one member now
kubectl get --raw /healthz/etcd
```

### Step 4: Provision Replacement Nodes

Install Debian/Ubuntu on new hardware, then join to cluster:

```bash
# Get join token from surviving node
ssh root@<surviving-node> cat /var/lib/rancher/k3s/server/node-token

# On first new node
curl -sfL https://get.k3s.io | sh -s - server \
  --server https://<surviving-node-ip>:6443 \
  --token <TOKEN> \
  --disable=traefik

# On second new node (same command)
curl -sfL https://get.k3s.io | sh -s - server \
  --server https://<surviving-node-ip>:6443 \
  --token <TOKEN> \
  --disable=traefik
```

### Step 5: Remove Old Node Entries

```bash
# List nodes (will show old dead nodes as NotReady)
kubectl get nodes

# Delete the dead node entries
kubectl delete node <dead-node-1>
kubectl delete node <dead-node-2>
```

### Step 6: Verify Full Recovery

```bash
# All 3 nodes should be Ready
kubectl get nodes

# Check etcd has 3 members
ssh root@<any-node> k3s kubectl get endpoints -n kube-system kube-etcd

# Check all pods recovered
kubectl get pods -A
```

## Scenario: All 3 Nodes Lost But Disks Intact

If all nodes crashed but disks are intact:

### Option A: Boot the Nodes

Just power them on. They'll reform the cluster automatically.

```bash
# After boot, verify from your workstation
kubectl get nodes
kubectl get pods -A
```

### Option B: One Node Won't Boot

Use the "2 Nodes Permanently Lost" procedure above with the two
working nodes.

## Scenario: All 3 Nodes Destroyed (Full Rebuild)

If all nodes and disks are gone:

1. Follow `docs/disaster-recovery.md` for full rebuild
2. You will lose:
   - Prometheus metrics history
   - Grafana dashboard customizations (unless exported)
   - Sentry event history (ClickHouse data)
   - Any data in PVCs

## Data Recovery Considerations

### What's Preserved in etcd (survives quorum recovery)

- Deployments, StatefulSets, DaemonSets
- Services, Ingresses
- ConfigMaps, Secrets
- PV/PVC definitions
- Custom Resources (ServiceMonitors, etc.)

### What's NOT in etcd (may be lost if node dies)

- **PVC data** on local-path storage - lives on specific node
- Prometheus TSDB data
- Grafana SQLite database
- ClickHouse data files
- Kafka logs

### Critical PVCs and Their Nodes

Check where important PVCs are bound:

```bash
kubectl get pvc -A -o wide
kubectl get pv -o custom-columns=\
'NAME:.metadata.name,NODE:.spec.nodeAffinity.required.nodeSelectorTerms[0].matchExpressions[0].values[0]'
```

If a node with critical PVC data dies permanently, that data is lost
unless you have backups.

## Prevention: Backup Strategy

To survive total cluster loss with data intact:

1. **PostgreSQL** - Already external (192.168.100.69), back up regularly
2. **Grafana dashboards** - Export JSON to this repo
3. **Prometheus** - Consider remote write to long-term storage
4. **ClickHouse** - Sentry data, consider backup CronJob

## Quick Reference

| Situation | Action |
|-----------|--------|
| 1 node down | Wait or replace, cluster operational |
| 2 nodes down temporarily | Wait for recovery |
| 2 nodes down permanently | `k3s server --cluster-reset` on survivor |
| 3 nodes down, disks OK | Power on, wait |
| 3 nodes destroyed | Full rebuild from disaster-recovery.md |
