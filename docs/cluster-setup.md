# Cluster Setup Guide

## Infrastructure Overview

### Cluster Nodes

| Node | IP | Role | Notes |
|------|-----|------|-------|
| www01 | 192.168.100.70 | control-plane | ARM64, Debian 12 |
| www02 | 192.168.100.71 | control-plane | AMD64, Debian 13, hosts container registry |
| tr1 | 192.168.100.81 | control-plane | AMD64, Debian 13 |

### Container Registry

- **Local registry:** `192.168.100.71:5000`
- Used for all Docker images
- Accessible from all cluster nodes

### External Services (DMZ)

Services managed outside Kubernetes:

| Service | Host | Port | Notes |
|---------|------|------|-------|
| PostgreSQL | 192.168.100.69 | 5432 | Patroni HA cluster |
| Redis | 192.168.100.69 | 6379 | No password auth |
| MariaDB | (3 nodes) | 3306 | Galera cluster |
| etcd | (external) | 2379 | K3s backend |

## Local Development Cluster

A Kind cluster is available for local development. Config is in `cluster/kind-config.yaml`.

### Create Local Cluster

```bash
kind create cluster --config cluster/kind-config.yaml
```

### Port Mappings

| Container Port | Host Port | Purpose |
|----------------|-----------|---------|
| 80 | 80 | HTTP ingress |
| 443 | 443 | HTTPS ingress |
| 30800 | 30800 | Backend NodePort |
| 30801 | 30801 | Frontend NodePort |
| 30432 | 5433 | PostgreSQL access |
| 30379 | 6380 | Redis access |

### Loading Docker Images to Kind

Kind clusters run isolated containerd runtimes that cannot access your local Docker images. You must explicitly load images.

**Standard method (may hang with large images or multi-node clusters):**

```bash
kind load docker-image myimage:tag --name ediai-local
```

**Reliable method (direct containerd import):**

```bash
# Load to a single node
docker save myimage:tag | docker exec -i ediai-local-control-plane ctr --namespace=k8s.io images import -

# Load to all nodes in multi-node cluster
for node in ediai-local-control-plane ediai-local-control-plane2 ediai-local-control-plane3; do
  docker save myimage:tag | docker exec -i $node ctr --namespace=k8s.io images import -
done
```

**Verify image is loaded:**

```bash
docker exec ediai-local-control-plane crictl images | grep myimage
```

**Note:** The `kind load` command can hang indefinitely when loading large images (>1GB) to multi-node clusters. The direct `docker save | ctr import` method is more reliable.

## Kubectl Contexts

```bash
# List all contexts
kubectl config get-contexts

# Switch to production
kubectl config use-context ediai-production

# Switch to staging
kubectl config use-context ediai-staging

# Switch to local
kubectl config use-context kind-ediai-local
```

## Secret Generation

Generate secure secrets for deployments:

```bash
# Database password (24 chars)
openssl rand -base64 24

# JWT secret (64 hex chars)
openssl rand -hex 32

# Generic password
openssl rand -base64 24
```

## Troubleshooting

### Pods Not Starting

```bash
# Check pod events
kubectl describe pod <pod-name> -n <namespace>

# Check logs
kubectl logs <pod-name> -n <namespace>

# Check previous container logs (if restarting)
kubectl logs <pod-name> -n <namespace> --previous
```

### Database Connection Issues

```bash
# Check exporter pods
kubectl get pods -n monitoring | grep exporter

# Test postgres connection from a pod
kubectl exec -it deployment/backend -n ediai-staging -- \
  psql $DATABASE_URL -c '\l'
```

### Image Pull Errors

```bash
# Check if registry is accessible
curl http://192.168.100.71:5000/v2/_catalog

# Check if image exists
curl http://192.168.100.71:5000/v2/<image>/tags/list
```

### Secret Issues

```bash
# Check if secrets exist
kubectl get secrets -n <namespace>

# Describe secret (doesn't show values)
kubectl describe secret <secret-name> -n <namespace>

# Decode secret value (for debugging)
kubectl get secret <secret-name> -n <namespace> \
  -o jsonpath='{.data.<key>}' | base64 -d
```

## Rollback Procedures

### Rollback Deployment

```bash
# View rollout history
kubectl rollout history deployment/<name> -n <namespace>

# Rollback to previous version
kubectl rollout undo deployment/<name> -n <namespace>

# Rollback to specific revision
kubectl rollout undo deployment/<name> --to-revision=<N> -n <namespace>
```

### Rollback via Image Tag

```bash
# Set specific image version
kubectl set image deployment/<name> \
  <container>=<registry>/<image>:<tag> \
  -n <namespace>
```

## Security Best Practices

1. **Never commit secrets to git**
   - Use templates with placeholders
   - Use external secret management

2. **Rotate secrets regularly**
   - JWT secrets: every 90 days
   - Database passwords: every 90 days

3. **Use strong secrets**
   - Minimum 32 characters for JWT
   - Minimum 24 characters for passwords
   - Use cryptographic random generation

4. **Limit access**
   - Use Kubernetes RBAC
   - Restrict kubeconfig distribution
   - Review permissions regularly
