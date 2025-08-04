#!/bin/bash

# Step 1: Taint Kubernetes node
# Usage: ./1-setup-taint.sh [NODE_NAME]

set -e

# Set default node name or use provided argument
NODE_NAME=${1:-ip-192-168-86-196.us-west-2.compute.internal}

echo "=== Setting up node taint ==="
echo "Node: $NODE_NAME"

echo "Current taints on node:"
kubectl describe node ${NODE_NAME} | grep Taints

echo "Adding taint to node..."
kubectl taint nodes ${NODE_NAME} s3.csi.aws.com/agent-not-ready:NoExecute

echo "Updated taints on node:"
kubectl describe node ${NODE_NAME} | grep Taints

echo "✓ Node taint setup complete"
