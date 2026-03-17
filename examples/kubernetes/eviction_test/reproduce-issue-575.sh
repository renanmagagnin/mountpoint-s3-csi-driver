#!/bin/bash
set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEST_BUCKET="${TEST_BUCKET:-mp-cache-test-$(date +%s)}"
AWS_REGION="${AWS_REGION:-us-west-2}"
NAMESPACE="mp-eviction-test"

echo -e "${GREEN}=== Issue #575: Cache Eviction Prevention Test ===${NC}"
echo -e "Bucket: ${TEST_BUCKET} | Region: ${AWS_REGION} | Namespace: ${NAMESPACE}\n"

# Namespace
kubectl create namespace ${NAMESPACE} 2>/dev/null || echo "Namespace already exists"

# S3 test data (10 files x 10MB = 100MB, enough to exceed the 50Mi cache limit)
if ! aws s3 ls s3://${TEST_BUCKET} 2>/dev/null; then
  aws s3 mb s3://${TEST_BUCKET} --region ${AWS_REGION}
fi
for i in {1..10}; do
  if ! aws s3 ls s3://${TEST_BUCKET}/testdata/file-${i}.bin >/dev/null 2>&1; then
    dd if=/dev/urandom of=/tmp/testfile-${i}.bin bs=1M count=10 2>/dev/null
    aws s3 cp /tmp/testfile-${i}.bin s3://${TEST_BUCKET}/testdata/file-${i}.bin --quiet
    rm /tmp/testfile-${i}.bin
    echo -ne "  Uploaded ${i}/10\r"
  fi
done
echo -e "\n  ${GREEN}✓${NC} Test data ready"

# PV/PVC and workload
sed "s/bucketName: .*/bucketName: ${TEST_BUCKET}/" "${SCRIPT_DIR}/issue-575-pv.yaml" > /tmp/issue-575-pv-updated.yaml
kubectl apply -f /tmp/issue-575-pv-updated.yaml
kubectl apply -f "${SCRIPT_DIR}/issue-575-workload.yaml"
echo -e "  ${GREEN}✓${NC} PV, PVC and workload pod created"

# Wait for workload to be ready
kubectl wait --for=condition=Ready pod/cache-filler -n ${NAMESPACE} --timeout=120s 2>/dev/null || true

# Find the Mountpoint pod
sleep 5
MP_POD=$(kubectl get pods -n mount-s3 -l s3.csi.aws.com/volume-id=s3-csi-eviction-test-volume \
  -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")

echo ""
if [ -n "$MP_POD" ]; then
  echo -e "Mountpoint pod: ${GREEN}${MP_POD}${NC}"
else
  echo -e "${YELLOW}Mountpoint pod not found yet — it may still be starting.${NC}"
  echo "  kubectl get pods -n mount-s3 -l s3.csi.aws.com/volume-id=s3-csi-eviction-test-volume"
fi

echo -e "\n${YELLOW}=== What to observe ===${NC}"
echo "The workload reads files in a loop, filling the 50Mi emptyDir cache."
echo "With the fix, Mountpoint self-evicts cache blocks before Kubernetes evicts the pod."
echo ""
echo -e "  ${GREEN}✅ Expected (fixed):${NC}  Mountpoint pod stays Running, cache stays under 50Mi"
echo -e "  ${RED}❌ Regression:${NC}        Mountpoint pod gets Evicted by kubelet"
echo ""
echo "Watch with:"
echo "  kubectl get pods -n mount-s3 -w"
echo "  kubectl get pods -n ${NAMESPACE} -w"
[ -n "$MP_POD" ] && echo "  kubectl logs -n mount-s3 ${MP_POD} -f"
echo ""
echo "When done: ./cleanup.sh"
