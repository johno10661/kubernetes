# Grafana Monitoring Documentation

## Overview

Grafana is deployed as part of the **kube-prometheus-stack** Helm chart (version 79.6.1) and provides the primary visualization layer for all cluster and application metrics.

**Access URL:** https://grafana.ediai.net

## Authentication

| Setting | Value |
|---------|-------|
| Admin User | `admin` |
| Admin Password | Stored in secret `prometheus-grafana` |
| Default Password | `changeme123` (from Helm values - CHANGE THIS) |

To retrieve the password:
```bash
kubectl get secret prometheus-grafana -n monitoring -o jsonpath="{.data.admin-password}" | base64 --decode
```

## Datasources

Grafana is configured with two primary datasources:

### 1. Prometheus (Default)
- **Type:** Prometheus
- **UID:** `prometheus`
- **URL:** `http://prometheus-kube-prometheus-prometheus.monitoring:9090/`
- **HTTP Method:** POST
- **Scrape Interval:** 30s

### 2. Alertmanager
- **Type:** Alertmanager
- **UID:** `alertmanager`
- **URL:** `http://prometheus-kube-prometheus-alertmanager.monitoring:9093/`
- **Implementation:** Prometheus

## Pre-installed Dashboards

The kube-prometheus-stack includes 27 pre-configured dashboards:

### Kubernetes Core
| Dashboard | Description |
|-----------|-------------|
| `k8s-resources-cluster` | Cluster-wide CPU, memory, network |
| `k8s-resources-namespace` | Per-namespace resource consumption |
| `k8s-resources-node` | Node-level resource metrics |
| `k8s-resources-pod` | Pod resource usage and limits |
| `k8s-resources-workload` | Workload metrics |
| `k8s-resources-workloads-namespace` | Workloads by namespace |

### Node Dashboards
| Dashboard | Description |
|-----------|-------------|
| `nodes` | Comprehensive node metrics (Linux) |
| `nodes-darwin` | macOS node metrics |
| `node-rsrc-use` | Node resource utilization |
| `node-cluster-rsrc-use` | Cluster-wide node resources |

### Kubernetes Components
| Dashboard | Description |
|-----------|-------------|
| `apiserver` | Kubernetes API server metrics |
| `controller-manager` | Controller manager metrics |
| `scheduler` | Scheduler metrics and latency |
| `etcd` | etcd cluster health |
| `kubelet` | Kubelet metrics |
| `proxy` | kube-proxy metrics |
| `k8s-coredns` | CoreDNS performance |

### Networking
| Dashboard | Description |
|-----------|-------------|
| `cluster-total` | Cluster network traffic |
| `namespace-by-pod` | Network by pod |
| `namespace-by-workload` | Network by workload |
| `pod-total` | Pod network metrics |
| `workload-total` | Workload network metrics |

### Monitoring Stack
| Dashboard | Description |
|-----------|-------------|
| `grafana-overview` | Grafana self-monitoring |
| `prometheus` | Prometheus metrics and targets |
| `alertmanager-overview` | Alertmanager overview |

### Storage
| Dashboard | Description |
|-----------|-------------|
| `persistentvolumesusage` | PVC and PV usage |

## Custom Monitoring - External Database Exporters

### MariaDB (3 Galera Nodes)
- **Deployments:** `mariadb-exporter-node1`, `mariadb-exporter-node2`, `mariadb-exporter-node3`
- **Port:** 9104
- **ServiceMonitor:** `mariadb-exporter`
- **Scrape Interval:** 30s

Key metrics:
- `mysql_global_status_connections` - Connection count
- `mysql_global_status_queries` - Query throughput
- `mysql_global_status_wsrep_*` - Galera replication status

### PostgreSQL (Patroni HA)
- **Deployment:** `postgres-exporter`
- **Port:** 9187
- **ServiceMonitors:** `postgres-exporter`, `patroni-external`
- **Scrape Interval:** 30s

Key metrics:
- `pg_stat_activity_count` - Active connections
- `pg_stat_replication_*` - Replication lag
- `patroni_*` - Cluster leadership/health

### Redis
- **Deployment:** `redis-exporter`
- **Port:** 9121
- **ServiceMonitor:** `redis-exporter`
- **Scrape Interval:** 30s

Key metrics:
- `redis_memory_used_bytes` - Memory usage
- `redis_connected_clients` - Client connections
- `redis_commands_processed_total` - Command throughput

### External etcd
- **ServiceMonitor:** `etcd-external`
- **Service:** `etcd-external` (headless, port 2379)

### External Node Exporter (Database Servers)
- **ServiceMonitor:** `node-exporter-external`
- **Service:** `node-exporter-db` (port 9100)

## ServiceMonitor Pattern

All custom ServiceMonitors require the `release: prometheus` label:

```yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  labels:
    release: prometheus  # REQUIRED
  name: my-exporter
  namespace: monitoring
spec:
  endpoints:
  - interval: 30s
    port: metrics
  selector:
    matchLabels:
      app: my-exporter
```

## Prometheus Configuration

| Setting | Value |
|---------|-------|
| Retention | 30 days |
| Storage | 50Gi PVC (local-path) |
| Scrape Interval | Default 30s |

## Alertmanager Configuration

| Setting | Value |
|---------|-------|
| Group By | namespace |
| Group Wait | 30s |
| Group Interval | 5m |
| Repeat Interval | 12h |
| Receiver | null (not configured) |

**Note:** Alerts are generated but not forwarded anywhere. Configure receivers for Slack/PagerDuty/email as needed.

## Alert Rules

35 PrometheusRule resources cover:
- Alertmanager health
- etcd cluster
- API server SLOs
- Container resources (CPU, memory)
- Kubernetes apps/resources/storage
- Node health
- Network issues
- Prometheus operator

## Storage

### Grafana PVC
- **Name:** `prometheus-grafana`
- **Size:** 10Gi
- **Class:** local-path

### Prometheus PVC
- **Size:** 50Gi
- **Class:** local-path

## Adding Custom Dashboards

### Via ConfigMap (GitOps)
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: my-dashboard
  namespace: monitoring
  labels:
    grafana_dashboard: "1"
data:
  my-dashboard.json: |
    { ... dashboard JSON ... }
```

### Via Grafana UI
Dashboards saved in UI persist to the 10Gi PVC but are NOT backed up in git.

## Useful Commands

```bash
# Port-forward to Grafana
kubectl port-forward svc/prometheus-grafana 3000:80 -n monitoring

# Port-forward to Prometheus
kubectl port-forward svc/prometheus-kube-prometheus-prometheus 9090 -n monitoring

# Check Prometheus targets
# Open http://localhost:9090/targets after port-forward

# View Grafana logs
kubectl logs -l app.kubernetes.io/name=grafana -n monitoring

# Check ServiceMonitor discovery
kubectl get servicemonitors -n monitoring
```

## Digital Signage / TV Display

Grafana is configured for embedding on digital signage systems (e.g., Kitcast on Apple TV).

### Configuration

The following settings enable embedding and anonymous access:

```yaml
grafana:
  grafana.ini:
    security:
      allow_embedding: true
      cookie_samesite: none
      cookie_secure: true
    auth.anonymous:
      enabled: true
      org_role: Viewer
    server:
      domain: grafana.ediai.net
      root_url: https://grafana.ediai.net
      serve_from_sub_path: true
  imageRenderer:
    enabled: true
```

### Image Renderer

The Grafana Image Renderer is enabled for displaying static PNG snapshots on devices that cannot run Grafana's JavaScript (like Apple TV browsers).

**Render URL format:**

```text
https://grafana.ediai.net/render/d/<dashboard-uid>/<dashboard-slug>?orgId=1&width=1728&height=972&kiosk=1
```

**Parameters:**

- `width` / `height`: Image dimensions (use 90% of target resolution for Kitcast border compensation)
- `kiosk=1`: Removes all UI chrome for clean display
- `orgId=1`: Organization ID

**Example - Cluster Health Dashboard:**

```text
https://grafana.ediai.net/render/d/cluster-health-001/cluster-health?orgId=1&width=1728&height=972&kiosk=1
```

**Note:** For 1920x1080 displays on Kitcast, use 1728x972 (90%) to compensate for the platform's 10% border/safe zone.

## Troubleshooting

### ServiceMonitor Not Discovered
1. Verify `release: prometheus` label
2. Check selector matches service labels
3. Restart Prometheus operator if needed

### Missing Metrics
1. Check exporter pod is running
2. Verify network connectivity to target
3. Test metrics endpoint: `curl http://<service>:<port>/metrics`
