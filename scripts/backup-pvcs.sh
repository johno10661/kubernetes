#!/bin/bash
# Backup PVC data from important namespaces
# Requires: kubectl, tar, and SSH access to nodes

set -e

BACKUP_DIR="${BACKUP_DIR:-/tmp/k8s-backups}"
DATE=$(date +%Y%m%d-%H%M%S)

echo "Kubernetes PVC Backup - $DATE"
echo "Backup directory: $BACKUP_DIR"
mkdir -p "$BACKUP_DIR"

# List all PVCs
echo ""
echo "=== Current PVCs ==="
kubectl get pvc -A

# Function to backup a PVC by creating a temporary pod
backup_pvc() {
    local namespace=$1
    local pvc_name=$2
    local backup_name="${namespace}-${pvc_name}-${DATE}.tar.gz"

    echo ""
    echo "Backing up $namespace/$pvc_name..."

    # Create temporary backup pod
    cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: backup-pod-${pvc_name}
  namespace: ${namespace}
spec:
  containers:
  - name: backup
    image: busybox
    command: ["sleep", "3600"]
    volumeMounts:
    - name: data
      mountPath: /data
  volumes:
  - name: data
    persistentVolumeClaim:
      claimName: ${pvc_name}
  restartPolicy: Never
EOF

    # Wait for pod to be ready
    echo "Waiting for backup pod..."
    kubectl wait --for=condition=Ready pod/backup-pod-${pvc_name} -n ${namespace} --timeout=60s

    # Create tarball
    echo "Creating backup archive..."
    kubectl exec -n ${namespace} backup-pod-${pvc_name} -- tar czf - /data > "$BACKUP_DIR/$backup_name"

    # Cleanup
    kubectl delete pod backup-pod-${pvc_name} -n ${namespace}

    echo "Backup saved: $BACKUP_DIR/$backup_name"
}

# Important PVCs to backup (customize as needed)
echo ""
echo "=== Starting Backups ==="

# Uncomment the PVCs you want to backup:
# backup_pvc monitoring prometheus-grafana
# backup_pvc sentry data-sentry-clickhouse-shard0-0
# backup_pvc sentry data-sentry-kafka-controller-0

echo ""
echo "=== Backup Complete ==="
echo "Files in $BACKUP_DIR:"
ls -lh "$BACKUP_DIR"

echo ""
echo "Note: For production backups, consider:"
echo "  - Using Velero for scheduled backups"
echo "  - Backing up external PostgreSQL separately"
echo "  - Storing backups off-cluster (S3, etc.)"
