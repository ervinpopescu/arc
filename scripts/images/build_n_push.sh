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
  if [[ "${IMAGES[i]}" == *"qtile"* ]]; then
    EXTRA_ARGS+=(--build-arg "BASE_IMAGE=arc-base:local")
  fi

  docker build --platform linux/amd64 "${EXTRA_ARGS[@]}" -t "${IMAGES[i]}" "${DIRS[i]}"

  # Tag the base image locally for inheritance
  if [[ "${IMAGES[i]}" == *"arc-custom-runner"* ]]; then
    echo "🏷️  Tagging ${IMAGES[i]} as arc-base:local..."
    docker tag "${IMAGES[i]}" arc-base:local
  fi

  if [[ "$PUSH_IMAGES" == "true" ]]; then    echo "🚀 Pushing image: ${IMAGES[i]}..."
    docker push "${IMAGES[i]}"
  fi
  echo
done
