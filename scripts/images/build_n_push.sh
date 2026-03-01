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
  docker buildx build --platform linux/amd64 -t "${IMAGES[i]}" "${DIRS[i]}" --load --progress=plain

  # Tag the base image locally so dependent images use the local version
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
