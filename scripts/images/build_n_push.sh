#!/bin/bash

IMAGES=(
  ghcr.io/ervinpopescu/arc-custom-runner:ubuntu-24.04
  ghcr.io/ervinpopescu/qtile-custom-runner:ubuntu-24.04
)

DIRS=(
  images/base/
  images/qtile/
)
for i in "${!IMAGES[@]}"; do
  docker buildx build -t "${IMAGES[i]}" "${DIRS[i]}" --progress=plain && docker push "${IMAGES[i]}" &>/dev/null
  echo
done
