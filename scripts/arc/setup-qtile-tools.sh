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

# Release versions and checksums are pinned so shared tool-cache contents cannot
# be replaced by an unreviewed network response. Changing a version requires a
# corresponding reviewed checksum update.
RUSTUP_VERSION="${RUSTUP_VERSION:-1.28.2}"
RUSTUP_SHA256="${RUSTUP_SHA256:-20a06e644b0d9bd2fbdbfd52d42540bdde820ea7df86e92e533c073da0cdd43c}"
BINSTALL_VERSION="${BINSTALL_VERSION:-1.20.1}"
BINSTALL_SHA256="${BINSTALL_SHA256:-350a7bd4bf083fc90e00a15b5b71cffa1c9f6f08816fd03907afbde18698bbcb}"
TARPAULIN_VERSION="${TARPAULIN_VERSION:-0.35.5}"
TARPAULIN_SHA256="${TARPAULIN_SHA256:-da111367889603726aba2e25041985b33138ea6a679fb000fc3de111a32d347c}"
SCCACHE_VERSION="${SCCACHE_VERSION:-v0.16.0}"
SCCACHE_SHA256="${SCCACHE_SHA256:-aec995a83ad3dff3d14b6314e08858b7b73d35ca85a5bcf3d3a9ec07dee35588}"
CARGO_LLVM_COV_VERSION="${CARGO_LLVM_COV_VERSION:-v0.6.18}"
CARGO_LLVM_COV_SHA256="${CARGO_LLVM_COV_SHA256:-fa0c94ec63f604aef6f953e83202dab4f64bd7673e024fa1b5dec208a73cea9b}"
UV_VERSION="${UV_VERSION:-0.12.19}"
UV_SHA256="${UV_SHA256:-23bf5552d220e0842b65c862097b2ebaeba0064b74eda5e565e77fd25969d8c8}"

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
    kubectl -n "$NAMESPACE" exec "$POD_NAME" -- bash -c "
      set -euo pipefail
      tmpdir=\$(mktemp -d)
      trap 'rm -rf \"\$tmpdir\"' EXIT
      curl -fL -o \"\$tmpdir/rustup-init\" 'https://static.rust-lang.org/rustup/archive/$RUSTUP_VERSION/x86_64-unknown-linux-gnu/rustup-init'
      printf '%s  %s\\n' '$RUSTUP_SHA256' \"\$tmpdir/rustup-init\" | sha256sum --check --status
      chmod 0755 \"\$tmpdir/rustup-init\"
      \"\$tmpdir/rustup-init\" -y --no-modify-path
    "
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

# 4.1.1 Pre-install llvm-tools-preview component for stable and nightly.
# CI's `prepare` job runs `rustup component add llvm-tools-preview` on every PR/branch,
# and its concurrency lock only serializes same-PR/branch runs -- concurrent
# PRs race on the same shared RUSTUP_HOME downloads dir on the PVC, causing
# "could not rename ... .partial file: No such file or directory" failures.
# Installing the component here makes CI's `component add` a no-op that never
# touches the shared downloads dir.
for toolchain in stable nightly; do
    echo " Checking for llvm-tools-preview component on $toolchain..."
    if kubectl -n "$NAMESPACE" exec "$POD_NAME" -- bash -c "/opt/hostedtoolcache/cargo/bin/rustup component list --toolchain $toolchain --installed | grep -q '^llvm-tools-preview'" >/dev/null 2>&1; then
        echo " llvm-tools-preview already installed for $toolchain."
    else
        echo " Installing llvm-tools-preview for $toolchain..."
        kubectl -n "$NAMESPACE" exec "$POD_NAME" -- bash -c "/opt/hostedtoolcache/cargo/bin/rustup component add llvm-tools-preview --toolchain $toolchain"
        echo " llvm-tools-preview installation complete for $toolchain."
    fi
done

# 4.2 Install cargo-binstall if not present
echo " Checking for cargo-binstall installation..."
if kubectl -n "$NAMESPACE" exec "$POD_NAME" -- bash -c "ls /opt/hostedtoolcache/cargo/bin/cargo-binstall" >/dev/null 2>&1; then
    echo " cargo-binstall is already installed."
else
    echo " Installing cargo-binstall..."
    kubectl -n "$NAMESPACE" exec "$POD_NAME" -- bash -c "
      set -euo pipefail
      tmpdir=\$(mktemp -d)
      trap 'rm -rf \"\$tmpdir\"' EXIT
      curl -fL -o \"\$tmpdir/cargo-binstall.tgz\" 'https://github.com/cargo-bins/cargo-binstall/releases/download/v$BINSTALL_VERSION/cargo-binstall-x86_64-unknown-linux-gnu.tgz'
      printf '%s  %s\\n' '$BINSTALL_SHA256' \"\$tmpdir/cargo-binstall.tgz\" | sha256sum --check --status
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
    kubectl -n "$NAMESPACE" exec "$POD_NAME" -- bash -c "
      set -euo pipefail
      tmpdir=\$(mktemp -d)
      trap 'rm -rf \"\$tmpdir\"' EXIT
      curl -fL -o \"\$tmpdir/cargo-tarpaulin.tar.gz\" 'https://github.com/xd009642/tarpaulin/releases/download/$TARPAULIN_VERSION/cargo-tarpaulin-x86_64-unknown-linux-gnu.tar.gz'
      printf '%s  %s\\n' '$TARPAULIN_SHA256' \"\$tmpdir/cargo-tarpaulin.tar.gz\" | sha256sum --check --status
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
    local bin=$1 url=$2 sha256=$3
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
        archive=\"\$tmp/$bin.tar.gz\"
        curl -fLsS -o \"\$archive\" '$url'
        printf '%s  %s\\n' '$sha256' \"\$archive\" | sha256sum --check --status
        tar xzf \"\$archive\" -C \"\$tmp\"
        src=\$(find \"\$tmp\" -type f -name '$bin' -executable -print -quit)
        [ -n \"\$src\" ] || { echo 'binary $bin not found in release tarball' >&2; exit 1; }
        install -m 0755 \"\$src\" /opt/hostedtoolcache/cargo/bin/$bin
    "
    echo " $bin installation complete."
}

install_release_bin sccache \
    "https://github.com/mozilla/sccache/releases/download/${SCCACHE_VERSION}/sccache-${SCCACHE_VERSION}-x86_64-unknown-linux-musl.tar.gz" \
    "$SCCACHE_SHA256"
install_release_bin cargo-llvm-cov \
    "https://github.com/taiki-e/cargo-llvm-cov/releases/download/${CARGO_LLVM_COV_VERSION}/cargo-llvm-cov-x86_64-unknown-linux-gnu.tar.gz" \
    "$CARGO_LLVM_COV_SHA256"

# 5. Install uv if not present
echo "  Checking for uv installation..."
if kubectl -n "$NAMESPACE" exec "$POD_NAME" -- bash -c "ls /opt/hostedtoolcache/uv/bin/uv" >/dev/null 2>&1; then
    echo " uv is already installed."
else
    echo " Installing uv..."
    kubectl -n "$NAMESPACE" exec "$POD_NAME" -- bash -c "
      set -euo pipefail
      tmpdir=\$(mktemp -d)
      trap 'rm -rf \"\$tmpdir\"' EXIT
      archive=\"\$tmpdir/uv.tar.gz\"
      curl -fLsS -o \"\$archive\" 'https://github.com/astral-sh/uv/releases/download/$UV_VERSION/uv-x86_64-unknown-linux-gnu.tar.gz'
      printf '%s  %s\\n' '$UV_SHA256' \"\$archive\" | sha256sum --check --status
      mkdir -p /opt/hostedtoolcache/uv/bin
      tar xzf \"\$archive\" -C \"\$tmpdir\"
      src=\$(find \"\$tmpdir\" -type f -name uv -executable -print -quit)
      [ -n \"\$src\" ] || { echo 'uv binary not found in release tarball' >&2; exit 1; }
      install -m 0755 \"\$src\" /opt/hostedtoolcache/uv/bin/uv
    "
    echo " uv installation complete."
fi

echo " Tool setup finished."
