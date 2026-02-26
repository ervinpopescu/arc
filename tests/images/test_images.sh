#!/bin/bash
set -eo pipefail

BASE_IMAGE="ghcr.io/ervinpopescu/arc-custom-runner:ubuntu-26.04"
QTILE_IMAGE="ghcr.io/ervinpopescu/qtile-custom-runner:ubuntu-26.04"

test_image() {
    local image=$1
    local name=$2
    echo "🧪 Testing image: $name ($image)"

    # Check for basic binaries
    docker run --rm "$image" git --version >/dev/null
    docker run --rm "$image" curl --version >/dev/null
    docker run --rm "$image" sudo --version >/dev/null
    docker run --rm "$image" jq --version >/dev/null

    # Check runner user
    local uid=$(docker run --rm "$image" id -u)
    if [ "$uid" != "1001" ]; then
        echo "❌ User ID is not 1001 (found $uid)"
        exit 1
    fi

    # Check sudo access
    docker run --rm "$image" sudo whoami >/dev/null

    echo "✅ Image $name passed basic checks."
}

test_qtile_specifics() {
    echo "🧪 Testing Qtile specific image features..."
    # Check for extra tools if any (gcc, g++, etc)
    docker run --rm "$QTILE_IMAGE" gcc --version >/dev/null
    docker run --rm "$QTILE_IMAGE" g++ --version >/dev/null
    
    # Check for env vars (RUSTUP_HOME, CARGO_HOME, UV_CACHE_DIR are set in values.yaml but lets check image defaults or if they exist)
    # The Dockerfile doesn't set them, the Helm chart does.
    
    echo "✅ Qtile image passed specific checks."
}

# Run tests
if docker image inspect "$BASE_IMAGE" >/dev/null 2>&1; then
    test_image "$BASE_IMAGE" "Base Runner"
else
    echo "⚠️  Base image not found locally, skipping test. Run 'make build' first."
fi

if docker image inspect "$QTILE_IMAGE" >/dev/null 2>&1; then
    test_image "$QTILE_IMAGE" "Qtile Runner"
    test_qtile_specifics
else
    echo "⚠️  Qtile image not found locally, skipping test. Run 'make build' first."
fi
