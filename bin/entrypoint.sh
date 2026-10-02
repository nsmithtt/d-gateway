#!/usr/bin/env bash
# Keeps a detached tmux server alive for the lifetime of the container, so
# agent sessions survive `docker compose restart` of neighbouring services and
# reconnect after a VM reboot.
set -euo pipefail

SESSION="${GATEWAY_SESSION:-gateway}"
CONF="${TMUX_CONF:-/etc/gateway/tmux.conf}"

case "${1:-supervise}" in
  supervise)
    if ! tmux -f "$CONF" has-session -t "$SESSION" 2>/dev/null; then
      tmux -f "$CONF" new-session -d -s "$SESSION" -c /workspace
    fi

    echo "gateway: tmux session '$SESSION' ready"
    echo "gateway: attach with  make attach"
    tmux -f "$CONF" list-sessions

    # Block on the tmux server. If it ever dies the container exits and the
    # restart policy brings it back with a fresh session.
    while tmux -f "$CONF" has-session -t "$SESSION" 2>/dev/null; do
      sleep 30
    done
    echo "gateway: tmux session '$SESSION' exited" >&2
    exit 1
    ;;
  *)
    exec "$@"
    ;;
esac
