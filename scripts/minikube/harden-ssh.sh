#!/bin/bash
# Disable OpenSSH's PerSourcePenalties on every minikube node in $PROFILE.
#
# Why: fresh minikube ISOs ship OpenSSH 9.8+ with PerSourcePenalties enabled
# by default.  Many minikube operations (notably `minikube start` on a
# running cluster, `minikube node add`, libmachine's join-token generation)
# fire bursts of parallel SSH connections; some race with sshd's auth and
# fail, which immediately bans 192.168.39.1 (the host).  Subsequent
# connections die with `ssh: handshake failed: connection reset by peer`
# and minikube exits with GUEST_START / GUEST_NODE_ADD errors.
#
# Idempotent: skips a node that already has the setting.

set -eo pipefail

PROFILE="${DEFAULT_MINIKUBE_PROFILE:-prod}"

if ! minikube status -p "$PROFILE" >/dev/null 2>&1; then
  echo "harden-ssh: cluster '$PROFILE' is not reachable, skipping." >&2
  exit 0
fi

# Loop in a way that survives nodes minikube isn't fully tracking.
nodes=$(minikube -p "$PROFILE" node list 2>/dev/null | awk '{print $1}')
if [[ -z "$nodes" ]]; then
  echo "harden-ssh: no nodes found in profile '$PROFILE', skipping." >&2
  exit 0
fi

for node in $nodes; do
  echo "harden-ssh: configuring $node..."
  minikube -p "$PROFILE" ssh -n "$node" -- '
    if grep -q "^PerSourcePenalties" /etc/ssh/sshd_config; then
      echo "  already set";
    else
      echo "PerSourcePenalties no" | sudo tee -a /etc/ssh/sshd_config >/dev/null
      sudo systemctl restart sshd
      echo "  disabled and sshd restarted";
    fi
  ' || echo "  WARNING: failed to harden $node (may need manual fix)" >&2
done
