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
  docker buildx build -t "${IMAGES[i]}" "${DIRS[i]}" --load --progress=plain

  if [[ "$PUSH_IMAGES" == "true" ]]; then
    echo "🚀 Pushing image: ${IMAGES[i]}..."
    docker push "${IMAGES[i]}"
  fi
  echo
done
