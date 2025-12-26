# Disaster Recovery Guide

This guide covers how to rebuild the EDIai production Kubernetes cluster
from scratch.

## Cluster Overview

| Node  | IP             | Role          | Architecture | OS                   |
|-------|----------------|---------------|--------------|----------------------|
| www01 | 192.168.100.70 | control-plane | arm64        | Debian 12 (bookworm) |
| www02 | 192.168.100.71 | control-plane | amd64        | Debian 13 (trixie)   |
| tr1   | 192.168.100.81 | control-plane | amd64        | Debian 13 (trixie)   |

## External Dependencies

These services run outside Kubernetes and must be available:

| Service          | Host           | Port | Purpose                |
|------------------|----------------|------|------------------------|
| PostgreSQL       | 192.168.100.69 | 5432 | Sentry, EDIai databases|
| Redis            | 192.168.100.69 | 6379 | Sentry (DB 8), caching |
| UniFi Controller | 192.168.9.7    | 8443 | Network metrics source |

## Recovery Procedure

### Phase 1: K3s Cluster Setup

1. **Install K3s on first node (www01):**

    ```bash
    curl -sfL https://get.k3s.io | sh -s - server \
      --cluster-init \
      --disable=traefik \
      --tls-san=192.168.100.70 \
      --tls-san=192.168.100.71 \
      --tls-san=192.168.100.81
    ```

2. **Get join token:**

    ```bash
    cat /var/lib/rancher/k3s/server/node-token
    ```

3. **Join additional control-plane nodes:**

    ```bash
    curl -sfL https://get.k3s.io | sh -s - server \
      --server https://192.168.100.70:6443 \
      --token <TOKEN> \
      --disable=traefik
    ```

4. **Copy kubeconfig locally:**

    ```bash
    scp root@192.168.100.70:/etc/rancher/k3s/k3s.yaml ~/.kube/config
    # Edit server URL to 192.168.100.70:6443
    ```

### Phase 2: Core Infrastructure

1. **Add Helm repositories:**

    ```bash
    helm repo add traefik https://traefik.github.io/charts
    helm repo add prometheus-community \
      https://prometheus-community.github.io/helm-charts
    helm repo add sentry https://sentry-kubernetes.github.io/charts
    helm repo add actions-runner-controller \
      https://actions-runner-controller.github.io/actions-runner-controller
    helm repo update
    ```

2. **Install Traefik (ingress controller):**

    ```bash
    helm install traefik traefik/traefik \
      --namespace kube-system \
      --values helm-values/traefik-values.yaml
    ```

3. **Install cert-manager:**

    ```bash
    kubectl apply -f https://github.com/cert-manager/cert-manager/\
    releases/download/v1.16.2/cert-manager.yaml
    kubectl apply -f infrastructure/certificates/cluster-issuers.yaml
    ```

4. **Apply CoreDNS Consul integration:**

    ```bash
    kubectl apply -f cluster/coredns-consul.yaml
    ```

### Phase 3: Monitoring Stack

1. **Create monitoring namespace:**

    ```bash
    kubectl create namespace monitoring
    ```

2. **Install kube-prometheus-stack:**

    ```bash
    helm install prometheus prometheus-community/kube-prometheus-stack \
      --namespace monitoring \
      --values helm-values/prometheus-values.yaml
    ```

3. **Apply Grafana ingress:**

    ```bash
    kubectl apply -f namespaces/monitoring/grafana-ingress.yaml
    ```

4. **Deploy exporters:**

    ```bash
    kubectl apply -f namespaces/monitoring/exporters/postgres-exporter.yaml
    kubectl apply -f namespaces/monitoring/exporters/unpoller.yaml
    ```

    Note: Update secrets with actual passwords before applying.

### Phase 4: Sentry

See `../sentry/README.md` for Sentry installation. Key steps:

1. Create namespace and secrets
2. Install via Helm:

    ```bash
    helm install sentry sentry/sentry -n sentry -f ../sentry/k8s/values.yaml
    ```

### Phase 5: GitHub Actions Runners

1. **Install ARC controller:**

    ```bash
    helm install arc \
      oci://ghcr.io/actions/actions-runner-controller-charts/\
    gha-runner-scale-set-controller \
      --namespace arc-systems \
      --create-namespace \
      --values helm-values/arc-controller-values.yaml
    ```

2. **Install runner scale sets:**

    ```bash
    helm install runners-ediai \
      oci://ghcr.io/actions/actions-runner-controller-charts/\
    gha-runner-scale-set \
      --namespace arc-runners \
      --create-namespace \
      --values helm-values/runners-ediai-values.yaml

    helm install runners-sop-amd64 \
      oci://ghcr.io/actions/actions-runner-controller-charts/\
    gha-runner-scale-set \
      --namespace arc-runners \
      --values helm-values/runners-sop-amd64-values.yaml

    helm install runners-sop-arm64 \
      oci://ghcr.io/actions/actions-runner-controller-charts/\
    gha-runner-scale-set \
      --namespace arc-runners \
      --values helm-values/runners-sop-arm64-values.yaml
    ```

### Phase 6: Application Deployments

Deploy applications in order:

1. **EDIai Production/Staging** - Deployed via GitHub Actions CI/CD
2. **Discourse** - See namespace resources
3. **n8n** - See namespace resources
4. **phpIPAM** - See namespace resources
5. **SOP** - See namespace resources

## Data Recovery

### PostgreSQL Databases

Databases are on external PostgreSQL (192.168.100.69). Ensure backups
exist for:

- `sentry` - Sentry error tracking
- `ediai` - EDIai application data
- `discourse` - Discourse forum data

### Persistent Volumes

Check storage class and PV/PVC status:

```bash
kubectl get pv
kubectl get pvc -A
```

Key persistent data:

- Grafana dashboards/config (`prometheus-grafana`)
- ClickHouse data (`sentry-clickhouse`)
- Kafka data (`sentry-kafka`)

## Verification Checklist

After recovery, verify:

- [ ] All nodes Ready: `kubectl get nodes`
- [ ] All pods Running: `kubectl get pods -A`
- [ ] Traefik ingress working
- [ ] Grafana accessible at <https://grafana.ediai.com>
- [ ] Prometheus scraping targets: Check Prometheus UI
- [ ] Sentry accessible at <https://sentry.ediai.com>
- [ ] GitHub Actions runners online: Check GitHub repo settings
- [ ] DNS resolution working

## Secrets Required

These secrets must be recreated with actual values:

| Namespace   | Secret Name              | Keys                            |
|-------------|--------------------------|---------------------------------|
| monitoring  | postgres-exporter-secret | DATA_SOURCE_NAME                |
| monitoring  | unpoller-secret          | UP_UNIFI_DEFAULT_USER/PASS      |
| sentry      | sentry-secrets           | admin-password, sentry-secret   |
| arc-runners | controller-manager       | github_token                    |

## Contact

For infrastructure questions, check the cluster-setup.md documentation
or review Helm values in this repo.
