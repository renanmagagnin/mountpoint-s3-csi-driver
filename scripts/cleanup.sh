#!/bin/bash

# Cleanup script for after test completion
# Usage: ./cleanup.sh [NODE_NAME] [EXAMPLE_FILE_NAME]

set -e

# Set defaults or use provided arguments
NODE_NAME=${1:-ip-192-168-86-196.us-west-2.compute.internal}
EXAMPLE_FILE_NAME=${2:-static_provisioning}

echo "=== Cleaning up after test ==="
echo "Node: $NODE_NAME"
echo "Example file: $EXAMPLE_FILE_NAME"

echo "Uninstalling CSI Driver..."
helm uninstall aws-mountpoint-s3-csi-driver --namespace kube-system --ignore-not-found --wait --cascade foreground

echo "Deleting workload..."
kubectl delete -f ../examples/kubernetes/static_provisioning/${EXAMPLE_FILE_NAME}.yaml
kubectl delete pod s3-app --grace-period=0 --force

echo "Removing taint from node..."
kubectl taint nodes ${NODE_NAME} s3.csi.aws.com/agent-not-ready:NoExecute-

echo "✓ Cleanup complete"
