#!/bin/bash
set -euo pipefail

WORKFLOW='.github/workflows/cleanup-images.yaml'

if ! grep -Fq 'ubuntu-26.04|ubuntu-24.04|fedora-44"; then' "$WORKFLOW"; then
    echo "Cleanup workflow does not preserve the deployed qtile fedora-44 tag" >&2
    exit 1
fi

echo "Cleanup workflow preserves deployed image tags."
