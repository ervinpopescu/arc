#!/bin/bash
set -eo pipefail

NAMESPACE="qtile-runners"
POD_NAME="debug"
PVC_YAML="./runners/qtile/manifests/tool-cache-pvc.yaml"
DEBUG_YAML="./runners/qtile/manifests/debug.yaml"

echo "🛠️  Setting up Qtile tools..."

# 0. Ensure Namespace exists
echo "🌐 Ensuring namespace $NAMESPACE exists..."
kubectl get ns "$NAMESPACE" >/dev/null 2>&1 || kubectl create ns "$NAMESPACE"

# 1. Apply PVC
echo "📦 Applying tool-cache PVC..."
kubectl apply -f "$PVC_YAML"

# 2. Apply Debug Pod
echo "🐞 Deploying debug pod..."
kubectl -n "$NAMESPACE" delete pod "$POD_NAME" --ignore-not-found
kubectl apply -f "$DEBUG_YAML"

# 3. Wait for Debug Pod to be ready
echo "⏳ Waiting for debug pod to be ready..."
kubectl -n "$NAMESPACE" wait --for=condition=Ready pod/"$POD_NAME" --timeout=300s

# 4. Install Rust if not present
echo "🦀 Checking for Rust installation..."
if kubectl -n "$NAMESPACE" exec "$POD_NAME" -- bash -c "ls /opt/hostedtoolcache/cargo/bin/rustc" >/dev/null 2>&1; then
    echo "✅ Rust is already installed."
else
    echo "🚀 Installing Rust via rustup..."
    kubectl -n "$NAMESPACE" exec "$POD_NAME" -- bash -c "curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --no-modify-path"
    echo "✅ Rust installation complete."
fi

# 4.1 Install nightly toolchain
echo "🌙 Checking for Rust nightly toolchain..."
if kubectl -n "$NAMESPACE" exec "$POD_NAME" -- bash -c "export RUSTUP_HOME=/opt/hostedtoolcache/rustup && export CARGO_HOME=/opt/hostedtoolcache/cargo && /opt/hostedtoolcache/cargo/bin/rustup toolchain list | grep -q nightly" >/dev/null 2>&1; then
    echo "✅ Rust nightly is already installed."
else
    echo "🚀 Installing Rust nightly toolchain..."
    kubectl -n "$NAMESPACE" exec "$POD_NAME" -- bash -c "export RUSTUP_HOME=/opt/hostedtoolcache/rustup && export CARGO_HOME=/opt/hostedtoolcache/cargo && /opt/hostedtoolcache/cargo/bin/rustup toolchain install nightly"
    echo "✅ Rust nightly installation complete."
fi

# 4.2 Install cargo-tarpaulin if not present
echo "📊 Checking for cargo-tarpaulin installation..."
if kubectl -n "$NAMESPACE" exec "$POD_NAME" -- bash -c "ls /opt/hostedtoolcache/cargo/bin/cargo-tarpaulin" >/dev/null 2>&1; then
    echo "✅ cargo-tarpaulin is already installed."
else
    echo "🚀 Installing cargo-tarpaulin..."
    kubectl -n "$NAMESPACE" exec "$POD_NAME" -- bash -c "export RUSTUP_HOME=/opt/hostedtoolcache/rustup && export CARGO_HOME=/opt/hostedtoolcache/cargo && /opt/hostedtoolcache/cargo/bin/cargo install cargo-tarpaulin"
    echo "✅ cargo-tarpaulin installation complete."
fi

# 5. Install uv if not present
echo "❄️  Checking for uv installation..."
if kubectl -n "$NAMESPACE" exec "$POD_NAME" -- bash -c "ls /opt/hostedtoolcache/uv/bin/uv" >/dev/null 2>&1; then
    echo "✅ uv is already installed."
else
    echo "🚀 Installing uv..."
    kubectl -n "$NAMESPACE" exec "$POD_NAME" -- bash -c "mkdir -p /opt/hostedtoolcache/uv/bin && export UV_INSTALL_DIR=/opt/hostedtoolcache/uv/bin && curl -LsSf https://astral.sh/uv/install.sh | sh"
    echo "✅ uv installation complete."
fi

echo "✨ Tool setup finished."
