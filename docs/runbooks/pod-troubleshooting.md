# Runbook: Pod Troubleshooting

## Pod Not Starting

### Symptoms
- Pod stuck in `Pending`, `ContainerCreating`, or `CrashLoopBackOff`

### Diagnosis

```bash
# Get pod status
kubectl get pod <pod-name> -n <namespace>

# Describe pod for events
kubectl describe pod <pod-name> -n <namespace>

# Check logs
kubectl logs <pod-name> -n <namespace>

# Check previous container logs (if restarting)
kubectl logs <pod-name> -n <namespace> --previous
```

### Common Causes & Fixes

#### Pending - No nodes available
```
Events:
  Warning  FailedScheduling  no nodes available to schedule pods
```
**Fix:** Check node status, add capacity, or adjust nodeSelector/affinity.

#### Pending - Insufficient resources
```
Events:
  Warning  FailedScheduling  Insufficient cpu/memory
```
**Fix:** Reduce resource requests or add node capacity.

#### Pending - Node selector mismatch
```
Events:
  Warning  FailedScheduling  node(s) didn't match Pod's node selector
```
**Fix:** Check `nodeSelector` in pod spec. Sentry requires `amd64` nodes.

#### ImagePullBackOff
```
Events:
  Warning  Failed  Failed to pull image
```
**Fix:** Check image name, registry credentials, or network connectivity.

#### CrashLoopBackOff
**Fix:** Check logs for application errors:
```bash
kubectl logs <pod-name> -n <namespace> --previous
```

---

## Pod OOMKilled

### Symptoms
- Pod terminated with reason `OOMKilled`
- Container restarts frequently

### Diagnosis

```bash
# Check termination reason
kubectl get pod <pod-name> -n <namespace> -o jsonpath='{.status.containerStatuses[0].lastState.terminated.reason}'

# Check memory limits
kubectl get pod <pod-name> -n <namespace> -o jsonpath='{.spec.containers[0].resources}'
```

### Fix

1. Increase memory limits in deployment:
```yaml
resources:
  limits:
    memory: "512Mi"  # Increase this
```

2. Or investigate memory leak in application.

**Known high-memory services:**
- Sentry Worker: Needs 4-8Gi
- Sentry Web: Needs 2-3Gi
- ClickHouse: Needs 2-4Gi

---

## Pod Evicted

### Symptoms
- Pod status `Evicted`
- Many pods evicted at once

### Diagnosis

```bash
# Check evicted pods
kubectl get pods -A | grep Evicted

# Check node pressure
kubectl describe node <node-name> | grep -A5 Conditions
```

### Common Causes

1. **DiskPressure** - Node disk full
2. **MemoryPressure** - Node out of memory
3. **PIDPressure** - Too many processes

### Fix

```bash
# Clean up evicted pods
kubectl get pods -A | grep Evicted | awk '{print $1" "$2}' | xargs -L1 kubectl delete pod -n

# Check disk usage on node
ssh root@<node-ip> df -h

# Check memory on node
ssh root@<node-ip> free -h
```

---

## Service Not Accessible

### Symptoms
- Cannot reach service from outside cluster
- Ingress returning 404 or 503

### Diagnosis

```bash
# Check service endpoints
kubectl get endpoints <service-name> -n <namespace>

# Check if pods are ready
kubectl get pods -n <namespace> -l app=<app-label>

# Check ingress
kubectl describe ingress <ingress-name> -n <namespace>

# Test from inside cluster
kubectl run test --rm -it --image=curlimages/curl -- curl http://<service-name>.<namespace>.svc.cluster.local
```

### Common Fixes

1. **No endpoints** - Pods not running or label selector mismatch
2. **Ingress 404** - Check host header and path rules
3. **Ingress 503** - Backend pods not ready

---

## DNS Resolution Failing

### Symptoms
- Pods cannot resolve internal service names
- `nslookup` fails inside pods

### Diagnosis

```bash
# Test DNS from a pod
kubectl run test --rm -it --image=busybox -- nslookup kubernetes.default

# Check CoreDNS pods
kubectl get pods -n kube-system -l k8s-app=kube-dns

# Check CoreDNS logs
kubectl logs -n kube-system -l k8s-app=kube-dns
```

### Fix

```bash
# Restart CoreDNS
kubectl rollout restart deployment/coredns -n kube-system
```
