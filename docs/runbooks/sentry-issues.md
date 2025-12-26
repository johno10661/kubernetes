# Runbook: Sentry Issues

## Sentry Web Not Starting

### Symptoms
- Sentry web UI not accessible
- sentry-web pods crashing

### Diagnosis

```bash
# Check pod status
kubectl get pods -n sentry -l app=sentry,role=web

# Check logs
kubectl logs -n sentry deployment/sentry-web

# Check if PostgreSQL is accessible
kubectl exec -n sentry deployment/sentry-web -- python -c "import psycopg2; psycopg2.connect('host=192.168.100.69 dbname=sentry user=sentry password=<password>')"
```

### Common Fixes

1. **Database connection issues:**
   - Check PostgreSQL is running on 192.168.100.69
   - Verify network connectivity
   - Check credentials in sentry-secrets

2. **Migration needed:**
```bash
kubectl exec -n sentry deployment/sentry-web -- sentry upgrade
```

3. **Memory issues (OOMKilled):**
   - Increase memory limits in Helm values
   - Minimum recommended: 3Gi for web

---

## Sentry Worker Stuck

### Symptoms
- Events not being processed
- Worker pods stuck or restarting

### Diagnosis

```bash
# Check worker logs
kubectl logs -n sentry deployment/sentry-worker

# Check RabbitMQ queue depth
kubectl exec -n sentry sentry-rabbitmq-0 -- rabbitmqctl list_queues
```

### Common Fixes

1. **Clear stuck tasks:**
```bash
kubectl exec -n sentry deployment/sentry-worker -- sentry queues purge
```

2. **Restart workers:**
```bash
kubectl rollout restart deployment/sentry-worker -n sentry
```

---

## Kafka Issues

### Symptoms
- Consumer lag increasing
- Events not being processed

### Diagnosis

```bash
# Check Kafka pod
kubectl get pods -n sentry -l app.kubernetes.io/name=kafka

# Check topics
kubectl exec -n sentry sentry-kafka-controller-0 -- kafka-topics.sh --list --bootstrap-server localhost:9092

# Check consumer groups
kubectl exec -n sentry sentry-kafka-controller-0 -- kafka-consumer-groups.sh --bootstrap-server localhost:9092 --list
```

### Common Fixes

1. **Restart Kafka:**
```bash
kubectl rollout restart statefulset/sentry-kafka-controller -n sentry
```

2. **Check disk space:**
```bash
kubectl exec -n sentry sentry-kafka-controller-0 -- df -h /bitnami/kafka
```

---

## ClickHouse Issues

### Symptoms
- Queries timing out
- Events not visible in UI

### Diagnosis

```bash
# Check ClickHouse pod
kubectl get pods -n sentry -l app.kubernetes.io/name=clickhouse

# Check disk usage
kubectl exec -n sentry sentry-clickhouse-shard0-0 -- df -h /var/lib/clickhouse

# Check recent errors
kubectl logs -n sentry sentry-clickhouse-shard0-0 --tail=100
```

### Common Fixes

1. **Clear old data (if disk full):**
```bash
# Run cleanup job manually
kubectl create job --from=cronjob/sentry-sentry-cleanup manual-cleanup -n sentry
```

2. **Restart ClickHouse:**
```bash
kubectl rollout restart statefulset/sentry-clickhouse-shard0 -n sentry
```

---

## Helm Upgrade Failed

### Symptoms
- Helm release shows `failed` status
- Resources partially updated

### Diagnosis

```bash
# Check Helm status
helm status sentry -n sentry

# Check history
helm history sentry -n sentry
```

### Fix

1. **Rollback to previous version:**
```bash
helm rollback sentry <revision> -n sentry
```

2. **Fix issues and retry:**
```bash
helm upgrade sentry sentry/sentry -n sentry -f ../sentry/k8s/values.yaml --timeout 20m
```

3. **If stuck, reset release:**
```bash
# DANGER: Only if upgrade is truly stuck
helm uninstall sentry -n sentry --keep-history
helm install sentry sentry/sentry -n sentry -f ../sentry/k8s/values.yaml
```

---

## Reset Admin Password

```bash
kubectl exec -n sentry deployment/sentry-web -- sentry createuser \
  --email admin@sentry.local \
  --superuser \
  --force-update
```
