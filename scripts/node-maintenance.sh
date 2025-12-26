#!/bin/bash
# Node maintenance helper script
# Usage: ./node-maintenance.sh [cordon|drain|uncordon] <node-name>

set -e

ACTION=$1
NODE=$2

if [[ -z "$ACTION" || -z "$NODE" ]]; then
    echo "Usage: $0 [cordon|drain|uncordon|status] <node-name>"
    echo ""
    echo "Actions:"
    echo "  cordon   - Mark node as unschedulable (no new pods)"
    echo "  drain    - Safely evict all pods from node"
    echo "  uncordon - Mark node as schedulable again"
    echo "  status   - Show node status and pods"
    echo ""
    echo "Nodes:"
    kubectl get nodes -o wide
    exit 1
fi

case $ACTION in
    cordon)
        echo "Cordoning node $NODE (marking unschedulable)..."
        kubectl cordon "$NODE"
        echo "Node cordoned. New pods will not be scheduled here."
        ;;

    drain)
        echo "Draining node $NODE..."
        echo "This will evict all pods (except DaemonSets) from the node."
        read -p "Continue? (y/n) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            kubectl drain "$NODE" \
                --ignore-daemonsets \
                --delete-emptydir-data \
                --force \
                --grace-period=60
            echo "Node drained. Safe to perform maintenance."
        else
            echo "Aborted."
        fi
        ;;

    uncordon)
        echo "Uncordoning node $NODE (marking schedulable)..."
        kubectl uncordon "$NODE"
        echo "Node is now schedulable again."
        ;;

    status)
        echo "=== Node Status ==="
        kubectl get node "$NODE" -o wide
        echo ""
        echo "=== Node Conditions ==="
        kubectl get node "$NODE" -o jsonpath='{range .status.conditions[*]}{.type}{": "}{.status}{" ("}{.reason}{")\n"}{end}'
        echo ""
        echo "=== Pods on Node ==="
        kubectl get pods -A --field-selector spec.nodeName="$NODE" -o wide
        ;;

    *)
        echo "Unknown action: $ACTION"
        echo "Use: cordon, drain, uncordon, or status"
        exit 1
        ;;
esac
