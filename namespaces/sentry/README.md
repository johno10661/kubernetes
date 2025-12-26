# Sentry Namespace

## Source of Truth

**The actual Sentry deployment configuration lives in the dedicated sentry repo:**

```
../sentry/k8s/
├── values.yaml          # Helm values for deployment
├── secrets.yaml         # Secrets (not in git)
├── secrets.yaml.template
└── namespace.yaml
```

Use that repo for:
- Installing Sentry: `helm install sentry sentry/sentry -f k8s/values.yaml`
- Upgrading Sentry: `helm upgrade sentry sentry/sentry -f k8s/values.yaml`
- Modifying configuration

## What's Here

The files in this directory are **exported snapshots** from the running cluster:
- `resources.yaml` - Exported deployments, services, statefulsets
- `secrets-list.txt` - List of secret names (not values)

These are for documentation and disaster recovery reference only.

## Current Status

| Component | Status |
|-----------|--------|
| Helm Release | `sentry` (revision 25, status: failed) |
| Namespace | `sentry` |
| Domain | sentry.ediai.com |

## Key Components

- ClickHouse (event storage)
- Kafka (event streaming)
- RabbitMQ (task broker)
- Sentry Web/Worker/Cron
- Relay (event ingestion)
- Nginx (reverse proxy)

External dependencies:
- PostgreSQL: 192.168.100.69:5432
- Redis: 192.168.100.69:6379 (DB 8)
