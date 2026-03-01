#!/bin/bash
set -eo pipefail

PUSH_IMAGES=false
if [[ "$1" == "--push" ]]; then
  PUSH_IMAGES=true
fi

IMAGES=(
  ghcr.io/ervinpopescu/arc-custom-runner:ubuntu-26.04
  ghcr.io/ervinpopescu/qtile-custom-runner:ubuntu-26.04
)

DIRS=(
  images/base/
  images/qtile/
)

for i in "${!IMAGES[@]}"; do
  echo "🛠️  Building image: ${IMAGES[i]}..."

  EXTRA_ARGS=()
  # Map the local base tag to the freshly built base image for dependent builds
  if [[ "${IMAGES[i]}" == *"qtile"* ]]; then
    EXTRA_ARGS+=(--build-context "arc-base:local=docker-image://${IMAGES[0]}")
  fi

  docker buildx build --platform linux/amd64 "${EXTRA_ARGS[@]}" -t "${IMAGES[i]}" "${DIRS[i]}" --load --progress=plain

  # Tag the base image locally for convenience
  if [[ "${IMAGES[i]}" == *"arc-custom-runner"* ]]; then
    echo "🏷️  Tagging ${IMAGES[i]} as arc-base:local..."
    docker tag "${IMAGES[i]}" arc-base:local
  fi
  if [[ "$PUSH_IMAGES" == "true" ]]; then
    echo "🚀 Pushing image: ${IMAGES[i]}..."
    docker push "${IMAGES[i]}"
  fi
  echo
done
