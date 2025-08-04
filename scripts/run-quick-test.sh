#!/bin/bash

# Main script to run the complete "Quick Test to Validate Implemented Solution"
# Usage: ./run-quick-test.sh [NODE_NAME] [EXAMPLE_FILE_NAME]

set -e

# Set defaults or use provided arguments
NODE_NAME=${1:-ip-192-168-86-196.us-west-2.compute.internal}
EXAMPLE_FILE_NAME=${2:-static_provisioning}

echo "=== Quick Test to Validate Implemented Solution ==="
echo "Node: $NODE_NAME"
echo "Example file: $EXAMPLE_FILE_NAME"
echo ""

# Step 1: Setup taint
echo "Running Step 1: Setup taint..."
./scripts/1-setup-taint.sh "$NODE_NAME"
echo ""

# Step 2: Deploy workload
echo "Running Step 2: Deploy workload..."
./scripts/2-deploy-workload.sh "$EXAMPLE_FILE_NAME"
echo ""

# Step 3: Install CSI driver
echo "Running Step 3: Install CSI driver..."
./scripts/3-install-csi-driver.sh
echo ""

# Step 4: Manual monitoring step
echo "=== Step 4: Monitor CSI driver logs ==="
echo "Run this command in a separate terminal to monitor logs:"
echo "kubectl logs -n kube-system -l app=s3-csi-node -f"
echo ""
echo "Press Enter to continue to Step 5..."
read -r

# Step 5: Check workload
echo "Running Step 5: Check workload status..."
./scripts/5-check-workload.sh "$NODE_NAME"
echo ""

echo "✓ Quick test complete!"
echo ""
echo "To clean up, run: ./scripts/cleanup.sh $NODE_NAME $EXAMPLE_FILE_NAME"
