#!/bin/bash
# Copyright 2025 The Kubernetes Authors
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

set -euo pipefail

# Script to verify that the main CSI driver container image referenced in the Helm chart
# is available in public ECR before publishing the chart.
# This prevents publishing a Helm chart that references a non-existent CSI driver image.
#
# Note: This script only verifies the main CSI driver image that we build and publish.
# Sidecar images (node-driver-registrar, livenessprobe, pause) are maintained by other
# AWS teams in different public ECR accounts and are not verified here.
#
# Prerequisites:
#   - yq: YAML processor (https://github.com/mikefarah/yq)
#   - aws: AWS CLI (https://aws.amazon.com/cli/)
#   - AWS credentials for account s3-csi-driver+prod@amazon.com (https://isengard.amazon.com/manage-accounts/211164257204) with ecr-public:DescribeImages permission
#
# To set up AWS credentials locally:
#   ada credentials update --account=211164257204 --provider=isengard --role=ReadOnly --once

CHART_DIR="${1:-charts/aws-mountpoint-s3-csi-driver}"
VALUES_FILE="${CHART_DIR}/values.yaml"

echo "Checking prerequisites..."

if ! command -v yq &> /dev/null; then
  echo "ERROR: 'yq' is not installed or not in PATH"
  echo "Install from: https://github.com/mikefarah/yq"
  echo ""
  echo "On macOS: brew install yq"
  echo "On Linux: wget https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64 -O /usr/local/bin/yq && chmod +x /usr/local/bin/yq"
  exit 1
fi

if ! command -v aws &> /dev/null; then
  echo "ERROR: 'aws' CLI is not installed or not in PATH"
  echo "Install from: https://aws.amazon.com/cli/"
  exit 1
fi

# Check if AWS credentials are configured
if ! aws sts get-caller-identity &> /dev/null; then
  echo "ERROR: AWS credentials are not configured or have expired"
  echo ""
  echo "To set up credentials for the s3-csi-driver+prod@amazon.com account (211164257204):"
  echo "  ada credentials update --account=211164257204 --provider=isengard --role=ReadOnly --once"
  exit 1
fi

echo "✓ Prerequisites satisfied"
echo ""

if [[ ! -f "${VALUES_FILE}" ]]; then
  echo "ERROR: values.yaml not found at ${VALUES_FILE}"
  exit 1
fi

echo "Verifying CSI driver image referenced in ${VALUES_FILE}..."
echo ""

FAILED=0

# Function to verify public ECR image exists using AWS CLI
verify_public_ecr_image_aws() {
  local full_image=$1
  local description=$2
  
  # Parse image reference: public.ecr.aws/namespace/repo:tag
  # For public ECR, the repository name is just the last part after the namespace
  local without_registry=$(echo "${full_image}" | sed 's|public.ecr.aws/||')
  local repo_name=$(echo "${without_registry}" | cut -d: -f1 | awk -F/ '{print $NF}')
  local tag=$(echo "${full_image}" | cut -d: -f2)
  
  echo "Checking ${description}:"
  echo "  Image: ${full_image}"
  echo "  Repository: ${repo_name}"
  echo "  Tag: ${tag}"
  
  if aws ecr-public describe-images \
    --region us-east-1 \
    --repository-name "${repo_name}" \
    --image-ids imageTag="${tag}" &>/dev/null; then
    echo "  Status: ✅ Found"
    echo ""
    return 0
  else
    echo "  Status: ❌ NOT FOUND"
    echo ""
    FAILED=1
    return 1
  fi
}

# Verify main CSI driver image (the one we build and publish)
echo "=== Main CSI Driver Image ==="
MAIN_REPO=$(yq eval '.image.repository' "${VALUES_FILE}")
MAIN_TAG=$(yq eval '.image.tag' "${VALUES_FILE}")
verify_public_ecr_image_aws "${MAIN_REPO}:${MAIN_TAG}" "CSI Driver"

# TODO: Consider if we need to check the architecture specific images too

# Summary
echo "========================================"
if [[ ${FAILED} -eq 0 ]]; then
  echo "✅ SUCCESS: CSI driver image verified successfully!"
  echo "The Helm chart is safe to publish."
  exit 0
else
  echo "❌ FAILURE: CSI driver image is missing!"
  echo "DO NOT publish the Helm chart until the image is available."
  exit 1
fi
