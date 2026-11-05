#!/usr/bin/env bash
# Boots a VM from a new gallery image version in a private subnet, runs
# vm-checks.sh through "az vm run-command", and on success promotes the
# version so it becomes "latest". The VM is always deleted.
set -euo pipefail

: "${BUILD_RESOURCE_GROUP:?}" "${GALLERY_RESOURCE_GROUP:?}" "${GALLERY_NAME:?}"
: "${IMAGE_DEFINITION:?}" "${IMAGE_VERSION:?}" "${SMOKE_TEST_SUBNET_ID:?}"
VM_SIZE="${VM_SIZE:-Standard_D2ps_v5}"
VM_NAME="smoke-${IMAGE_VERSION//./-}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

cleanup() {
  echo "Deleting test VM $VM_NAME"
  az vm delete --resource-group "$BUILD_RESOURCE_GROUP" --name "$VM_NAME" --yes --only-show-errors || true
}
trap cleanup EXIT

image_id=$(az sig image-version show \
  --resource-group "$GALLERY_RESOURCE_GROUP" --gallery-name "$GALLERY_NAME" \
  --gallery-image-definition "$IMAGE_DEFINITION" --gallery-image-version "$IMAGE_VERSION" \
  --query id --output tsv)

echo "Creating test VM $VM_NAME from $IMAGE_VERSION"
az vm create \
  --resource-group "$BUILD_RESOURCE_GROUP" --name "$VM_NAME" \
  --image "$image_id" --size "$VM_SIZE" \
  --subnet "$SMOKE_TEST_SUBNET_ID" --public-ip-address "" --nsg "" \
  --admin-username azureuser --generate-ssh-keys \
  --os-disk-delete-option Delete --nic-delete-option Delete \
  --tags purpose=smoke-test image_version="$IMAGE_VERSION" \
  --only-show-errors --output none

echo "Running checks inside the VM"
output=$(az vm run-command invoke \
  --resource-group "$BUILD_RESOURCE_GROUP" --name "$VM_NAME" \
  --command-id RunShellScript --scripts "@${SCRIPT_DIR}/vm-checks.sh" \
  --query 'value[0].message' --output tsv)
echo "$output"

grep -q "IMAGE_VERSION=${IMAGE_VERSION}$" <<<"$output" \
  || { echo "::error::The VM did not report image version $IMAGE_VERSION"; exit 1; }
grep -q '^SMOKE_TEST_RESULT=PASS' <<<"$output" \
  || { echo "::error::Smoke test failed for $IMAGE_VERSION"; exit 1; }

echo "Promoting $IMAGE_VERSION to latest"
az sig image-version update \
  --resource-group "$GALLERY_RESOURCE_GROUP" --gallery-name "$GALLERY_NAME" \
  --gallery-image-definition "$IMAGE_DEFINITION" --gallery-image-version "$IMAGE_VERSION" \
  --set publishingProfile.excludeFromLatest=false \
  --only-show-errors --output none
echo "Smoke test passed"
