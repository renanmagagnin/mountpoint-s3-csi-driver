#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NAMESPACE="mp-eviction-test"
PV_NAME="s3-pv-eviction-test"
TEST_BUCKET="${TEST_BUCKET:-}"

echo "Cleaning up issue-575 test resources..."

# Force-delete workload pod first so the CSI driver can unmount cleanly
kubectl delete pod cache-filler -n ${NAMESPACE} --force --grace-period=0 --ignore-not-found=true

# Remove finalizers from PVC so it doesn't block namespace deletion
kubectl patch pvc s3-pvc-eviction-test -n ${NAMESPACE} \
  -p '{"metadata":{"finalizers":[]}}' --type=merge 2>/dev/null || true

# Remove finalizers from PV and force-delete it
kubectl patch pv ${PV_NAME} \
  -p '{"metadata":{"finalizers":[]}}' --type=merge 2>/dev/null || true
kubectl delete pv ${PV_NAME} --force --grace-period=0 --ignore-not-found=true

# Delete namespace (cascades to PVC)
kubectl delete namespace ${NAMESPACE} --force --grace-period=0 --ignore-not-found=true

# Clean up any stale Mountpoint pods in Error/Evicted state
kubectl get pods -n mount-s3 --field-selector=status.phase!=Running \
  -o jsonpath='{.items[*].metadata.name}' 2>/dev/null \
  | tr ' ' '\n' | grep -v '^$' \
  | xargs -r kubectl delete pod -n mount-s3 --force --grace-period=0 --ignore-not-found=true

if [ -n "$TEST_BUCKET" ]; then
  echo "Deleting S3 bucket ${TEST_BUCKET}..."
  aws s3 rb s3://${TEST_BUCKET} --force
else
  echo "Skipping S3 bucket deletion (TEST_BUCKET not set)"
fi

echo "Done."
