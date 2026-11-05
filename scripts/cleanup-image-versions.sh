#!/usr/bin/env bash
# Keeps the newest KEEP_VERSIONS promoted image versions and deletes older
# ones, plus any unpromoted (failed) versions except CURRENT_VERSION.
set -euo pipefail

: "${GALLERY_RESOURCE_GROUP:?}" "${GALLERY_NAME:?}" "${IMAGE_DEFINITION:?}"
KEEP_VERSIONS="${KEEP_VERSIONS:-3}"
CURRENT_VERSION="${CURRENT_VERSION:-}"
DRY_RUN="${DRY_RUN:-false}"

gallery_args=(--resource-group "$GALLERY_RESOURCE_GROUP" --gallery-name "$GALLERY_NAME"
              --gallery-image-definition "$IMAGE_DEFINITION")

mapfile -t promoted < <(az sig image-version list "${gallery_args[@]}" \
  --query "[?publishingProfile.excludeFromLatest==\`false\`].name" --output tsv | sort -V)
mapfile -t unpromoted < <(az sig image-version list "${gallery_args[@]}" \
  --query "[?publishingProfile.excludeFromLatest==\`true\`].name" --output tsv | sort -V)

to_delete=()
if (( ${#promoted[@]} > KEEP_VERSIONS )); then
  to_delete+=("${promoted[@]:0:${#promoted[@]}-KEEP_VERSIONS}")
fi
for v in "${unpromoted[@]}"; do
  [[ "$v" == "$CURRENT_VERSION" ]] || to_delete+=("$v")
done

echo "Promoted: ${promoted[*]:-none}"
echo "Unpromoted: ${unpromoted[*]:-none}"
if (( ${#to_delete[@]} == 0 )); then
  echo "Nothing to delete"
  exit 0
fi

for v in "${to_delete[@]}"; do
  if [[ "$DRY_RUN" == "true" ]]; then
    echo "[dry run] would delete $v"
  else
    echo "Deleting image version $v"
    az sig image-version delete "${gallery_args[@]}" --gallery-image-version "$v" --only-show-errors
  fi
done
