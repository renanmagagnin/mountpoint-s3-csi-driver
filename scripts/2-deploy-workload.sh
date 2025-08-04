#!/bin/bash

# Step 2: Deploy workload (will remain pending because of Taint)
# Usage: ./2-deploy-workload.sh [EXAMPLE_FILE_NAME]

set -e

# Set default example file or use provided argument
EXAMPLE_FILE_NAME=${1:-static_provisioning}

echo "=== Deploying workload ==="
echo "Example file: $EXAMPLE_FILE_NAME"

echo "Applying workload configuration..."
kubectl apply -f ../examples/kubernetes/static_provisioning/${EXAMPLE_FILE_NAME}.yaml

echo "Checking pod status..."
kubectl describe po s3-app

echo "✓ Workload deployment complete (should be pending due to taint)"
