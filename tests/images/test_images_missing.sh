#!/bin/bash
set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
FAKE_DOCKER_DIR=$(mktemp -d)
OUTPUT_FILE=$(mktemp)
trap 'rm -rf "$FAKE_DOCKER_DIR" "$OUTPUT_FILE"' EXIT

cat > "$FAKE_DOCKER_DIR/docker" <<'EOF'
#!/bin/bash

if [ "$1" = "image" ] && [ "$2" = "inspect" ]; then
    exit 1
fi

exit 0
EOF
chmod +x "$FAKE_DOCKER_DIR/docker"

if PATH="$FAKE_DOCKER_DIR:$PATH" "$SCRIPT_DIR/test_images.sh" >"$OUTPUT_FILE" 2>&1; then
    echo "test_images.sh passed despite missing required images" >&2
    exit 1
fi

grep -q "Image tests failed: 2 required image(s) are missing." "$OUTPUT_FILE"
