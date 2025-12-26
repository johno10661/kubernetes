# Kubernetes Cluster Configuration

Infrastructure as Code repository for the production K3s cluster.

## Cluster Overview

| Component | Details |
|-----------|---------|
| **Platform** | K3s v1.33.6+k3s1 |
| **Topology** | 3-node HA (all control-plane) |
| **Ingress** | Traefik v3.5.1 |
| **TLS** | cert-manager + Let's Encrypt |
| **Storage** | local-path (default) + NFS |
| **Monitoring** | Prometheus + Grafana |

## Nodes

| Node | IP | OS | Architecture | Role |
|------|-----|-----|--------------|------|
| www01 | 192.168.100.70 | Debian 12 | arm64 | control-plane |
| www02 | 192.168.100.71 | Debian 13 | amd64 | control-plane |
| tr1 | 192.168.100.81 | Debian 13 | amd64 | control-plane |

## Namespaces & Workloads

| Namespace | Application | Description |
|-----------|-------------|-------------|
| `ediai-production` | Frontend, Backend, ARQ workers | Main application (3 replicas each) |
| `ediai-staging` | Same + Mailpit | Staging environment |
| `discourse-production` | Discourse + Sidekiq | Forum (forum.gatesmills.app) |
| `sentry` | Self-hosted Sentry | Error tracking (Kafka, ClickHouse, etc.) |
| `n8n` | n8n | Workflow automation |
| `phpipam` | phpIPAM | IP address management |
| `sop` | cosplay50, shoots, wordpress | Multiple apps with HPA |
| `arc-runners` | GitHub Actions runners | CI/CD for ediai + sop |
| `arc-systems` | ARC controller | GitHub Actions Runner Controller |
| `monitoring` | Prometheus, Grafana, exporters | Full observability stack |
| `cert-manager` | cert-manager | TLS certificate automation |
| `kubernetes-dashboard` | Dashboard | Cluster UI |

## Ingresses

| Host | Namespace | Service |
|------|-----------|---------|
| ediai.com | ediai-production | frontend |
| ediai.net | ediai-staging | frontend |
| forum.gatesmills.app | discourse-production | discourse-web |
| grafana.ediai.net | monitoring | grafana |
| sentry.ediai.com | sentry | sentry-nginx |
| mail.ediai.net | ediai-staging | mailpit |

## Helm Releases

| Release | Namespace | Chart | Status |
|---------|-----------|-------|--------|
| prometheus | monitoring | kube-prometheus-stack-79.6.1 | deployed |
| arc | arc-systems | gha-runner-scale-set-controller-0.13.0 | deployed |
| runners-ediai | arc-runners | gha-runner-scale-set-0.13.0 | deployed |
| runners-sop-amd64 | arc-runners | gha-runner-scale-set-0.13.0 | deployed |
| runners-sop-arm64 | arc-runners | gha-runner-scale-set-0.13.0 | deployed |
| sentry | sentry | sentry-27.8.0 | failed (needs attention) |
| traefik | kube-system | traefik-37.1.1 | deployed |

## Repository Structure

```
kubernetes/
├── README.md                    # This file
├── cluster/                     # Cluster-level configuration
├── docs/
│   └── grafana.md              # Grafana documentation
├── helm-values/                 # Helm release values
│   ├── prometheus-values.yaml
│   ├── arc-controller-values.yaml
│   ├── runners-*.yaml
│   ├── sentry-values.yaml
│   └── traefik-values.yaml
├── infrastructure/
│   ├── certificates/           # ClusterIssuers, Certificates
│   ├── ingress/                # All Ingress resources
│   └── storage/                # PVs, PVCs, StorageClasses
└── namespaces/
    ├── arc-runners/
    ├── arc-systems/
    ├── cert-manager/
    ├── discourse-production/
    ├── ediai-production/
    ├── ediai-staging/
    ├── kubernetes-dashboard/
    ├── kube-system/
    ├── monitoring/
    ├── n8n/
    ├── phpipam/
    ├── sentry/
    └── sop/
```

## Quick Access

### Switch kubectl context
```bash
# Production
kubectl config use-context ediai-production

# Staging
kubectl config use-context ediai-staging
```

### Access Grafana
```bash
kubectl port-forward svc/prometheus-grafana 3000:80 -n monitoring
# Open http://localhost:3000
# User: admin, Password: see docs/grafana.md
```

### Access Kubernetes Dashboard
```bash
kubectl port-forward svc/kubernetes-dashboard 8443:443 -n kubernetes-dashboard
# Open https://localhost:8443
```

## External Dependencies

The cluster connects to external services not managed by Kubernetes:

| Service | Purpose | Monitored |
|---------|---------|-----------|
| MariaDB Galera (3 nodes) | Database | Yes (mariadb-exporter) |
| PostgreSQL/Patroni | Database | Yes (postgres-exporter) |
| Redis | Cache | Yes (redis-exporter) |
| etcd | K3s backend | Yes (etcd-external) |

## Disaster Recovery

To recreate this cluster:

1. **Provision nodes** - Install Debian on www01, www02, tr1
2. **Install K3s** - Set up 3-node HA cluster
3. **Apply infrastructure** - Storage classes, cert-manager, ingress
4. **Deploy Helm releases** - Use values from `helm-values/`
5. **Apply namespace resources** - Deploy workloads from `namespaces/`

See individual namespace directories for specific manifests.

## Monitoring

Full documentation: [docs/grafana.md](docs/grafana.md)

- **Grafana:** https://grafana.ediai.net
- **Prometheus:** Internal only (port-forward to access)
- **Alertmanager:** Internal only

## Known Issues

1. **Sentry Helm release failed** - Revision 25, needs investigation
2. **phpipam pod restarts** - 522 restarts on one replica, investigate
