#!/bin/bash

# Step 3: Install Mountpoint S3 CSI Driver (Helm chart from source)

set -e

echo "=== Installing CSI Driver ==="

# Change to the mountpoint-s3-csi-driver directory
CSI_DRIVER_DIR="$HOME/workplace/awslabs-forks/mountpoint-s3-csi-driver"
echo "Changing to CSI driver directory: $CSI_DRIVER_DIR"
cd "$CSI_DRIVER_DIR"

echo "Deploying local changes..."
if [ -f "$HOME/workplace/csi-driver-scripts/deploy-local-changes.sh" ]; then
    "$HOME/workplace/csi-driver-scripts/deploy-local-changes.sh"
else
    echo "Error: deploy-local-changes.sh not found at $HOME/workplace/csi-driver-scripts/"
    echo "This script is mandatory for deploying local changes"
    exit 1
fi

echo "Installing CSI driver via Helm..."
if [ -f "$HOME/workplace/csi-driver-scripts/install-csi-driver-helm-chart.sh" ]; then
    "$HOME/workplace/csi-driver-scripts/install-csi-driver-helm-chart.sh"
else
    echo "Error: install-csi-driver-helm-chart.sh not found at $HOME/workplace/csi-driver-scripts/"
    echo "Please ensure this script exists"
    exit 1
fi

echo "✓ CSI Driver installation complete"
