# Runbook: Monitoring Issues

## Prometheus Not Scraping Targets

### Symptoms
- Metrics missing in Grafana
- Target shows as DOWN in Prometheus UI

### Diagnosis

```bash
# Check Prometheus targets
# Port-forward to Prometheus UI
kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-prometheus 9090:9090
# Visit http://localhost:9090/targets

# Check ServiceMonitor exists
kubectl get servicemonitors -n monitoring

# Check if service has correct labels
kubectl get svc -n monitoring --show-labels
```

### Common Fixes

1. **Missing `release: prometheus` label:**
```yaml
# ServiceMonitor needs this label to be discovered
metadata:
  labels:
    release: prometheus
```

2. **Wrong port name:**
```yaml
# Service port name must match ServiceMonitor
spec:
  ports:
    - name: metrics  # This must match
```

3. **Endpoint not responding:**
```bash
# Test endpoint directly
kubectl port-forward svc/<service> -n <namespace> 9090:9090
curl http://localhost:9090/metrics
```

---

## Grafana Dashboard Not Loading

### Symptoms
- Dashboard shows "No data"
- Panels show errors

### Diagnosis

```bash
# Check Grafana logs
kubectl logs -n monitoring deployment/prometheus-grafana

# Check datasource
# Dashboard Settings → Variables → Check datasource is set
```

### Common Fixes

1. **Datasource variable not set:**
   - Edit dashboard → Settings → Variables
   - Set datasource variable to Prometheus

2. **Query syntax error:**
   - Check Prometheus for metric existence
   - Use Explore view to test queries

3. **Time range issue:**
   - Check if metrics exist for selected time range
   - Some metrics need time to populate

---

## Alertmanager Not Sending Alerts

### Symptoms
- Alerts firing in Prometheus but no notifications

### Diagnosis

```bash
# Check Alertmanager config
kubectl get secret -n monitoring alertmanager-prometheus-kube-prometheus-alertmanager -o jsonpath='{.data.alertmanager\.yaml}' | base64 -d

# Check Alertmanager logs
kubectl logs -n monitoring alertmanager-prometheus-kube-prometheus-alertmanager-0
```

### Fix

Update alertmanager config in Helm values:
```yaml
alertmanager:
  config:
    route:
      receiver: 'slack'
    receivers:
      - name: 'slack'
        slack_configs:
          - api_url: 'https://hooks.slack.com/...'
            channel: '#alerts'
```

---

## Prometheus Storage Full

### Symptoms
- Prometheus pods restarting
- Old metrics missing

### Diagnosis

```bash
# Check PVC usage
kubectl exec -n monitoring prometheus-prometheus-kube-prometheus-prometheus-0 -- df -h /prometheus

# Check retention settings
kubectl get prometheus -n monitoring prometheus-kube-prometheus-prometheus -o yaml | grep retention
```

### Fix

1. **Increase PVC size:**
```yaml
# In prometheus-values.yaml
prometheus:
  prometheusSpec:
    storageSpec:
      volumeClaimTemplate:
        spec:
          resources:
            requests:
              storage: 100Gi  # Increase this
```

2. **Reduce retention:**
```yaml
prometheus:
  prometheusSpec:
    retention: 7d  # Reduce from default 10d
```

---

## UnPoller Not Collecting Metrics

### Symptoms
- UniFi dashboards show no data
- UnPoller target DOWN

### Diagnosis

```bash
# Check UnPoller pod
kubectl get pods -n monitoring -l app=unpoller

# Check logs
kubectl logs -n monitoring deployment/unpoller

# Test connectivity to UniFi controller
kubectl exec -n monitoring deployment/unpoller -- curl -k https://192.168.9.7:8443
```

### Common Fixes

1. **Firewall blocking connection:**
   - Ensure 192.168.100.x can reach 192.168.9.7:8443

2. **Wrong credentials:**
   - Check secret: `kubectl get secret -n monitoring unpoller-secret -o yaml`
   - Verify user exists in UniFi controller

3. **Timeout issues:**
   - Increase probe timeouts (already set to 10s)
   - Large networks need more time to collect metrics

---

## Postgres Exporter Not Working

### Symptoms
- PostgreSQL metrics missing
- postgres-exporter target DOWN

### Diagnosis

```bash
# Check exporter pod
kubectl get pods -n monitoring -l app=postgres-exporter

# Check logs
kubectl logs -n monitoring deployment/postgres-exporter

# Test connection
kubectl exec -n monitoring deployment/postgres-exporter -- pg_isready -h 192.168.100.69 -p 5432
```

### Fix

Update connection string in secret:
```bash
kubectl edit secret -n monitoring postgres-exporter-secret
# Ensure DATA_SOURCE_NAME is correct
```
