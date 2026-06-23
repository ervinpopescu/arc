#!/bin/bash
set -eo pipefail

NAMESPACE="qtile-runners"
POD_NAME="debug"
PVC_YAML="./runners/qtile/manifests/tool-cache-pvc.yaml"
DEBUG_YAML="./runners/qtile/manifests/debug.yaml"

echo "  Setting up Qtile tools..."

# 0. Ensure Namespace exists
echo " Ensuring namespace $NAMESPACE exists..."
kubectl get ns "$NAMESPACE" >/dev/null 2>&1 || kubectl create ns "$NAMESPACE"

# 1. Apply PVC
echo " Applying tool-cache PVC..."
kubectl apply -f "$PVC_YAML"

# 2. Apply Debug Pod
echo " Deploying debug pod..."
kubectl -n "$NAMESPACE" delete pod "$POD_NAME" --ignore-not-found
kubectl apply -f "$DEBUG_YAML"

# 3. Wait for Debug Pod to be ready
echo " Waiting for debug pod to be ready..."
kubectl -n "$NAMESPACE" wait --for=condition=Ready pod/"$POD_NAME" --timeout=300s

# 4. Install Rust if not present
echo " Checking for Rust installation..."
if kubectl -n "$NAMESPACE" exec "$POD_NAME" -- bash -c "ls /opt/hostedtoolcache/cargo/bin/rustc" >/dev/null 2>&1; then
    echo " Rust is already installed."
elif kubectl -n "$NAMESPACE" exec "$POD_NAME" -- bash -c "ls /opt/hostedtoolcache/cargo/bin/rustup" >/dev/null 2>&1; then
    echo " rustup present but stable missing — installing stable toolchain..."
    kubectl -n "$NAMESPACE" exec "$POD_NAME" -- bash -c "/opt/hostedtoolcache/cargo/bin/rustup toolchain install stable"
    echo " Rust stable installation complete."
else
    echo " Installing Rust via rustup..."
    kubectl -n "$NAMESPACE" exec "$POD_NAME" -- bash -c "curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --no-modify-path"
    echo " Rust installation complete."
fi

# 4.1 Install nightly toolchain
echo " Checking for Rust nightly toolchain..."
if kubectl -n "$NAMESPACE" exec "$POD_NAME" -- bash -c "/opt/hostedtoolcache/cargo/bin/rustup toolchain list | grep -q nightly" >/dev/null 2>&1; then
    echo " Rust nightly is already installed."
else
    echo " Installing Rust nightly toolchain..."
    kubectl -n "$NAMESPACE" exec "$POD_NAME" -- bash -c "/opt/hostedtoolcache/cargo/bin/rustup toolchain install nightly"
    echo " Rust nightly installation complete."
fi

# 4.2 Install cargo-binstall if not present
echo " Checking for cargo-binstall installation..."
if kubectl -n "$NAMESPACE" exec "$POD_NAME" -- bash -c "ls /opt/hostedtoolcache/cargo/bin/cargo-binstall" >/dev/null 2>&1; then
    echo " cargo-binstall is already installed."
else
    echo " Installing cargo-binstall..."
    BINSTALL_VERSION="${BINSTALL_VERSION:-1.20.1}"
    kubectl -n "$NAMESPACE" exec "$POD_NAME" -- bash -c "
      set -euo pipefail
      tmpdir=\$(mktemp -d)
      trap 'rm -rf \"\$tmpdir\"' EXIT
      curl -fL -o \"\$tmpdir/cargo-binstall.tgz\" 'https://github.com/cargo-bins/cargo-binstall/releases/download/v$BINSTALL_VERSION/cargo-binstall-x86_64-unknown-linux-gnu.tgz'
      tar xzf \"\$tmpdir/cargo-binstall.tgz\" -C \"\$tmpdir\"
      install -m 755 \"\$tmpdir/cargo-binstall\" /opt/hostedtoolcache/cargo/bin/
    "
    echo " cargo-binstall installation complete."
fi

# 4.3 Install cargo-tarpaulin if not present
echo " Checking for cargo-tarpaulin installation..."
if kubectl -n "$NAMESPACE" exec "$POD_NAME" -- bash -c "ls /opt/hostedtoolcache/cargo/bin/cargo-tarpaulin" >/dev/null 2>&1; then
    echo " cargo-tarpaulin is already installed."
else
    echo " Installing cargo-tarpaulin..."
    TARPAULIN_VERSION="${TARPAULIN_VERSION:-0.35.5}"
    kubectl -n "$NAMESPACE" exec "$POD_NAME" -- bash -c "
      set -euo pipefail
      tmpdir=\$(mktemp -d)
      trap 'rm -rf \"\$tmpdir\"' EXIT
      curl -fL -o \"\$tmpdir/cargo-tarpaulin.tar.gz\" 'https://github.com/xd009642/tarpaulin/releases/download/$TARPAULIN_VERSION/cargo-tarpaulin-x86_64-unknown-linux-gnu.tar.gz'
      tar xzf \"\$tmpdir/cargo-tarpaulin.tar.gz\" -C \"\$tmpdir\"
      install -m 755 \"\$tmpdir/cargo-tarpaulin\" /opt/hostedtoolcache/cargo/bin/
    "
    echo " cargo-tarpaulin installation complete."
fi

# 4.4 Install sccache and cargo-llvm-cov from GitHub release tarballs.
# Pre-warm these into the PVC so the qtile-cmd-client CI prepare job's
# `cargo binstall -y sccache cargo-llvm-cov` is a no-op fast path.
# We download release tarballs directly because cargo-binstall has been
# observed to log "INFO Done in <Ns>" without actually writing the binaries
# to disk -- the CI then dies later with "sccache: command not found".
# Extracting to a tmpdir and copying the binary fails loudly on any breakage.
install_release_bin() {
    local bin=$1 url=$2
    echo " Checking for $bin installation..."
    if kubectl -n "$NAMESPACE" exec "$POD_NAME" -- bash -c "test -x /opt/hostedtoolcache/cargo/bin/$bin" >/dev/null 2>&1; then
        echo " $bin is already installed."
        return
    fi
    echo " Installing $bin from $url..."
    kubectl -n "$NAMESPACE" exec "$POD_NAME" -- bash -c "
        set -euo pipefail
        tmp=\$(mktemp -d)
        trap 'rm -rf \"\$tmp\"' EXIT
        curl -fLsS '$url' | tar xz -C \"\$tmp\"
        src=\$(find \"\$tmp\" -type f -name '$bin' -executable -print -quit)
        [ -n \"\$src\" ] || { echo 'binary $bin not found in release tarball' >&2; exit 1; }
        install -m 0755 \"\$src\" /opt/hostedtoolcache/cargo/bin/$bin
    "
    echo " $bin installation complete."
}

SCCACHE_VERSION="${SCCACHE_VERSION:-v0.16.0}"
CARGO_LLVM_COV_VERSION="${CARGO_LLVM_COV_VERSION:-v0.6.18}"
install_release_bin sccache \
    "https://github.com/mozilla/sccache/releases/download/${SCCACHE_VERSION}/sccache-${SCCACHE_VERSION}-x86_64-unknown-linux-musl.tar.gz"
install_release_bin cargo-llvm-cov \
    "https://github.com/taiki-e/cargo-llvm-cov/releases/download/${CARGO_LLVM_COV_VERSION}/cargo-llvm-cov-x86_64-unknown-linux-gnu.tar.gz"

# 5. Install uv if not present
echo "  Checking for uv installation..."
if kubectl -n "$NAMESPACE" exec "$POD_NAME" -- bash -c "ls /opt/hostedtoolcache/uv/bin/uv" >/dev/null 2>&1; then
    echo " uv is already installed."
else
    echo " Installing uv..."
    kubectl -n "$NAMESPACE" exec "$POD_NAME" -- bash -c "mkdir -p /opt/hostedtoolcache/uv/bin && export UV_INSTALL_DIR=/opt/hostedtoolcache/uv/bin && curl -LsSf https://astral.sh/uv/install.sh | sh"
    echo " uv installation complete."
fi

echo " Tool setup finished."
