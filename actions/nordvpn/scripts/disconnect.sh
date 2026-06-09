#!/usr/bin/env bash
# Best-effort cleanup: kills openvpn, removes the 0600 auth file from $RUNNER_TEMP.
# MUST NOT fail the job — runs as the caller's `if: always()` sibling step
# because composite actions don't support `post:` (GitHub Community Discussion #26743).

set -u  # NOT -e — a single failing teardown step must not abort later teardown.
# NEVER set -x (credentials in env would leak via transformed log lines).

PID_FILE="${RUNNER_TEMP:-/tmp}/openvpn.pid"
AUTH_FILE="${RUNNER_TEMP:-/tmp}/nordvpn-auth.txt"

if [[ -f "$PID_FILE" ]]; then
  pid=$(cat "$PID_FILE")
  if kill -0 "$pid" 2>/dev/null; then
    sudo kill -TERM "$pid" 2>/dev/null || true
    # Give openvpn 5s to exit gracefully; escalate to SIGKILL.
    for _ in 1 2 3 4 5; do
      kill -0 "$pid" 2>/dev/null || break
      sleep 1
    done
    kill -0 "$pid" 2>/dev/null && sudo kill -KILL "$pid" 2>/dev/null || true
  fi
fi

# Auth file must never linger on disk.
rm -f "$AUTH_FILE"

# Belt-and-braces: catch any openvpn that spawned without writing the PID file.
sudo pkill -TERM -x openvpn 2>/dev/null || true

# Non-fatal diagnostic: default route should no longer route via tun0 after kill.
if ip route | grep -q 'dev tun0'; then
  echo "[disconnect.sh] WARNING: tun0 still in default route after kill (cleanup best-effort)."
fi

echo "[disconnect.sh] cleanup complete."
exit 0
