#!/bin/bash
# Export current cluster state to this repository
# Run periodically to keep exported resources up to date

set -e

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
NAMESPACES=$(kubectl get namespaces -o jsonpath='{.items[*].metadata.name}')

echo "Exporting cluster state to $REPO_DIR"

# Export namespace resources
for ns in $NAMESPACES; do
    if [[ "$ns" == "default" || "$ns" == "kube-node-lease" || "$ns" == "kube-public" ]]; then
        continue
    fi

    echo "Exporting namespace: $ns"
    mkdir -p "$REPO_DIR/namespaces/$ns"

    kubectl get deployments,statefulsets,services,configmaps,ingresses -n "$ns" \
        -o yaml --ignore-not-found > "$REPO_DIR/namespaces/$ns/resources.yaml" 2>/dev/null || true
done

# Export Helm values
echo "Exporting Helm values..."
mkdir -p "$REPO_DIR/helm-values"
for release in $(helm list -A -q); do
    ns=$(helm list -A | grep "^$release" | awk '{print $2}')
    echo "  $release ($ns)"
    helm get values "$release" -n "$ns" > "$REPO_DIR/helm-values/${release}-values.yaml" 2>/dev/null || true
done

# Export infrastructure
echo "Exporting infrastructure..."
kubectl get ingress -A -o yaml > "$REPO_DIR/infrastructure/ingress/all-ingresses.yaml" 2>/dev/null || true
kubectl get certificates,clusterissuers -A -o yaml > "$REPO_DIR/infrastructure/certificates/certificates.yaml" 2>/dev/null || true
kubectl get pv,storageclass -o yaml > "$REPO_DIR/infrastructure/storage/persistent-volumes.yaml" 2>/dev/null || true
kubectl get networkpolicies -A -o yaml > "$REPO_DIR/infrastructure/network-policies/all-policies.yaml" 2>/dev/null || true

echo "Done! Review changes with: git status"
