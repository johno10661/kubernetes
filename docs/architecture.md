# Cluster Architecture

## Network Topology

```
                                    ┌─────────────────────────────────────────────────────────────┐
                                    │                      INTERNET                               │
                                    └─────────────────────────────────────────────────────────────┘
                                                              │
                                                              ▼
                                    ┌─────────────────────────────────────────────────────────────┐
                                    │                  Cloudflare (Proxy)                         │
                                    │  *.ediai.com, *.ediai.net, forum.gatesmills.app            │
                                    └─────────────────────────────────────────────────────────────┘
                                                              │
                                                              ▼
                                    ┌─────────────────────────────────────────────────────────────┐
                                    │              HAProxy (deploy.ediai.com)                     │
                                    │           Health checks → Kubernetes nodes                  │
                                    └─────────────────────────────────────────────────────────────┘
                                                              │
                           ┌──────────────────────────────────┼──────────────────────────────────┐
                           │                                  │                                  │
                           ▼                                  ▼                                  ▼
              ┌────────────────────────┐      ┌────────────────────────┐      ┌────────────────────────┐
              │        www01           │      │        www02           │      │         tr1            │
              │   192.168.100.70       │      │   192.168.100.71       │      │   192.168.100.81       │
              │   arm64 (Ampere)       │      │   amd64 (Intel)        │      │   amd64 (Intel)        │
              │   Debian 12            │      │   Debian 13            │      │   Debian 13            │
              │   control-plane        │      │   control-plane        │      │   control-plane        │
              └────────────────────────┘      └────────────────────────┘      └────────────────────────┘
                           │                                  │                                  │
                           └──────────────────────────────────┼──────────────────────────────────┘
                                                              │
                                    ┌─────────────────────────────────────────────────────────────┐
                                    │                K3s Cluster (v1.33.6)                        │
                                    │           3-node HA with embedded etcd                      │
                                    └─────────────────────────────────────────────────────────────┘
```

## External Services

```
┌─────────────────────────────────────────────────────────────────────────────────────────────────┐
│                              External Services (192.168.100.x)                                  │
├─────────────────────────────────────────────────────────────────────────────────────────────────┤
│                                                                                                 │
│   ┌─────────────────────────┐          ┌─────────────────────────┐                             │
│   │  PostgreSQL             │          │  Redis                   │                             │
│   │  192.168.100.69:5432    │          │  192.168.100.69:6379     │                             │
│   │                         │          │                          │                             │
│   │  Databases:             │          │  DB 8: Sentry            │                             │
│   │  - sentry               │          │                          │                             │
│   │  - ediai                │          └─────────────────────────┘                             │
│   │  - discourse            │                                                                   │
│   └─────────────────────────┘                                                                   │
│                                                                                                 │
│   ┌─────────────────────────┐                                                                   │
│   │  UniFi Controller       │                                                                   │
│   │  192.168.9.7:8443       │                                                                   │
│   │  (Network metrics)      │                                                                   │
│   └─────────────────────────┘                                                                   │
│                                                                                                 │
└─────────────────────────────────────────────────────────────────────────────────────────────────┘
```

## Namespace Layout

```
┌─────────────────────────────────────────────────────────────────────────────────────────────────┐
│                                    Kubernetes Namespaces                                        │
├─────────────────────────────────────────────────────────────────────────────────────────────────┤
│                                                                                                 │
│  ┌──────────────────┐  ┌──────────────────┐  ┌──────────────────┐  ┌──────────────────┐        │
│  │  kube-system     │  │  monitoring      │  │  sentry          │  │  arc-systems     │        │
│  │                  │  │                  │  │                  │  │                  │        │
│  │  - Traefik       │  │  - Prometheus    │  │  - Sentry Web    │  │  - ARC Controller│        │
│  │  - CoreDNS       │  │  - Grafana       │  │  - Workers       │  │                  │        │
│  │  - Metrics       │  │  - Alertmanager  │  │  - ClickHouse    │  │                  │        │
│  │                  │  │  - Exporters     │  │  - Kafka         │  │                  │        │
│  └──────────────────┘  └──────────────────┘  └──────────────────┘  └──────────────────┘        │
│                                                                                                 │
│  ┌──────────────────┐  ┌──────────────────┐  ┌──────────────────┐  ┌──────────────────┐        │
│  │  ediai-production│  │  ediai-staging   │  │  arc-runners     │  │  cert-manager    │        │
│  │                  │  │                  │  │                  │  │                  │        │
│  │  - Backend API   │  │  - Backend API   │  │  - runners-ediai │  │  - cert-manager  │        │
│  │  - Frontend      │  │  - Frontend      │  │  - runners-sop-* │  │  - issuers       │        │
│  │  - Celery        │  │  - Celery        │  │                  │  │                  │        │
│  └──────────────────┘  └──────────────────┘  └──────────────────┘  └──────────────────┘        │
│                                                                                                 │
│  ┌──────────────────┐  ┌──────────────────┐  ┌──────────────────┐  ┌──────────────────┐        │
│  │  discourse-prod  │  │  n8n             │  │  phpipam         │  │  sop             │        │
│  │                  │  │                  │  │                  │  │                  │        │
│  │  - Discourse     │  │  - n8n           │  │  - phpIPAM       │  │  - SOP App       │        │
│  │  - Sidekiq       │  │  (automation)    │  │  (IP management) │  │  (procedures)    │        │
│  └──────────────────┘  └──────────────────┘  └──────────────────┘  └──────────────────┘        │
│                                                                                                 │
└─────────────────────────────────────────────────────────────────────────────────────────────────┘
```

## Ingress Routes

| Domain | Namespace | Service | Port |
|--------|-----------|---------|------|
| ediai.com | ediai-production | frontend/backend | 80/8000 |
| ediai.net | ediai-staging | frontend/backend | 80/8000 |
| sentry.ediai.com | sentry | sentry-nginx | 8080 |
| sentry.ediai.net | sentry | sentry-nginx | 8080 |
| grafana.ediai.net | monitoring | prometheus-grafana | 80 |
| forum.gatesmills.app | discourse-production | discourse-web | 80 |
| mail.ediai.net | ediai-staging | mailpit | 80 |

## Node Affinity

Due to mixed architecture (arm64/amd64), workloads are scheduled based on image availability:

| Workload | Node Selector | Reason |
|----------|---------------|--------|
| Sentry (all components) | `kubernetes.io/arch: amd64` | x86-only images |
| ClickHouse | `kubernetes.io/arch: amd64` | x86-only images |
| Kafka | `kubernetes.io/arch: amd64` | x86-only images |
| EDIai Backend | any | Multi-arch images |
| Prometheus/Grafana | any | Multi-arch images |
| Traefik | any | Multi-arch images |

## Helm Releases

| Release | Namespace | Chart | Purpose |
|---------|-----------|-------|---------|
| traefik | kube-system | traefik/traefik | Ingress controller |
| traefik-crd | kube-system | traefik/traefik-crd | Traefik CRDs |
| prometheus | monitoring | kube-prometheus-stack | Monitoring stack |
| sentry | sentry | sentry/sentry | Error tracking |
| arc | arc-systems | gha-runner-scale-set-controller | GitHub Actions controller |
| runners-ediai | arc-runners | gha-runner-scale-set | EDIai CI runners |
| runners-sop-amd64 | arc-runners | gha-runner-scale-set | SOP CI runners (amd64) |
| runners-sop-arm64 | arc-runners | gha-runner-scale-set | SOP CI runners (arm64) |

## Traffic Flow

```
User Request → Cloudflare → HAProxy → Traefik (NodePort 30080/30444) → Service → Pod
                  │
                  ├── SSL termination (Cloudflare)
                  ├── DDoS protection
                  └── Caching (static assets)
```

## Monitoring Data Flow

```
┌─────────────┐     scrape      ┌─────────────┐     query      ┌─────────────┐
│  Targets    │ ──────────────► │ Prometheus  │ ◄───────────── │  Grafana    │
│             │                 │             │                │             │
│ - kubelet   │                 │ Stores TSDB │                │ Dashboards  │
│ - node      │                 │ 10d retain  │                │             │
│ - postgres  │                 │             │                │             │
│ - unpoller  │                 └─────────────┘                └─────────────┘
│ - apps      │                        │
└─────────────┘                        ▼
                               ┌─────────────┐
                               │ Alertmanager│
                               │             │
                               │ (alerts)    │
                               └─────────────┘
```

## Storage

All persistent storage uses the default K3s `local-path` provisioner:

| PVC | Namespace | Size | Purpose |
|-----|-----------|------|---------|
| prometheus-grafana | monitoring | 10Gi | Grafana data |
| prometheus-prometheus-* | monitoring | 50Gi | Prometheus TSDB |
| alertmanager-prometheus-* | monitoring | 1Gi | Alertmanager data |
| sentry-clickhouse-* | sentry | 50Gi | Event storage |
| sentry-kafka-* | sentry | 10Gi | Message queue |
| sentry-rabbitmq-* | sentry | 5Gi | Task broker |
| sentry-filestore | sentry | 20Gi | Attachments |
