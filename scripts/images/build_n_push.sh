#!/bin/bash
set -eo pipefail

# Pinned commit SHA of the Dockerfile in qtile/qtile.
# Source: https://github.com/qtile/qtile/blob/<SHA>/Dockerfile
# Bump this via the weekly track-qtile-dockerfile workflow when upstream changes.
QTILE_DOCKERFILE_SHA="88ebca8938aeed637a2dec7eadca55f474076f67"

PUSH_IMAGES=false
if [[ "$1" == "--push" ]]; then
  PUSH_IMAGES=true
fi

push_if_requested() {
  local image="$1"
  if [[ "$PUSH_IMAGES" == "true" ]]; then
    echo " Pushing image: $image..."
    docker push "$image"
  fi
}

# ── 1. Ubuntu base runner (unchanged) ────────────────────────────────────────
BASE_IMAGE="ghcr.io/ervinpopescu/arc-custom-runner:ubuntu-26.04"
echo "  Building image: $BASE_IMAGE..."
docker build --platform linux/amd64 -t "$BASE_IMAGE" images/base/
push_if_requested "$BASE_IMAGE"
echo

# ── 2. qtile CI base (Fedora + Wayland stack from upstream Dockerfile) ────────
QTILE_CI_BASE_IMAGE="ghcr.io/ervinpopescu/qtile-ci-base:latest"
echo "  Building image: $QTILE_CI_BASE_IMAGE (SHA: ${QTILE_DOCKERFILE_SHA:0:8})..."
DOCKERFILE_URL="https://raw.githubusercontent.com/qtile/qtile/${QTILE_DOCKERFILE_SHA}/Dockerfile"
echo "  Fetching upstream Dockerfile from $DOCKERFILE_URL..."
curl -fsSL "$DOCKERFILE_URL" \
  | docker build --platform linux/amd64 -t "$QTILE_CI_BASE_IMAGE" -

push_if_requested "$QTILE_CI_BASE_IMAGE"
echo

# ── 3. qtile ARC runner (layers runner machinery on top of qtile-ci-base) ────
QTILE_RUNNER_IMAGE="ghcr.io/ervinpopescu/qtile-custom-runner:fedora-44"
echo "  Building image: $QTILE_RUNNER_IMAGE..."
docker build --platform linux/amd64 \
  --build-arg "QTILE_CI_BASE=$QTILE_CI_BASE_IMAGE" \
  -t "$QTILE_RUNNER_IMAGE" \
  images/qtile/
push_if_requested "$QTILE_RUNNER_IMAGE"
echo
