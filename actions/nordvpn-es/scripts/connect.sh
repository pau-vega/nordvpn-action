#!/usr/bin/env bash
# Writes credentials to a 0600 file in $RUNNER_TEMP, starts openvpn --daemon against
# .github/vpn/nordvpn-es.ovpn, and polls `ip -4 addr show tun0` until an IPv4 is assigned
# (NOT the daemon's exit code — it forks and exits 0 before the handshake completes).
set -euo pipefail
# NEVER set -x — any transformation bypasses GitHub's exact-match log masking.

# Ubuntu-only guard (NVES-06, AGENTS.md Security section)
if [[ "${RUNNER_OS:-}" != "Linux" ]]; then
  echo "::error::Ubuntu runner required (detected ${RUNNER_OS:-unknown})"
  exit 1
fi

# Credentials must arrive via env vars set by the composite step.
# The `: "${VAR:?message}"` idiom fails loudly under set -u if the caller forgot them.
: "${NORDVPN_USERNAME:?NORDVPN_USERNAME env var required}"
: "${NORDVPN_PASSWORD:?NORDVPN_PASSWORD env var required}"

# Chaos injection (`wrong-creds` smoke mode): replace password with a deliberately
# wrong value. Production callers never set this env var.
if [[ -n "${SMOKE_PASSWORD_OVERRIDE:-}" ]]; then
  NORDVPN_PASSWORD="$SMOKE_PASSWORD_OVERRIDE"
fi

AUTH_FILE="$RUNNER_TEMP/nordvpn-auth.txt"
PID_FILE="$RUNNER_TEMP/openvpn.pid"
CONFIG_FILE="${GITHUB_ACTION_PATH}/vpn/nordvpn-es.ovpn"

# Auth file at 0600 in $RUNNER_TEMP (outside workspace globs, auto-cleaned by runner).
# Use printf (deterministic) NOT echo (shell-dependent escape interpretation).
umask 077
printf '%s\n%s\n' "$NORDVPN_USERNAME" "$NORDVPN_PASSWORD" > "$AUTH_FILE"
chmod 600 "$AUTH_FILE"

# Resolve a currently-online Spanish openvpn_tcp server via NordVPN's public
# recommendations API. The original design assumed DNS round-robin at
# `es.nordvpn.com`, but that hostname does not exist as a DNS record — only
# server-specific names like `esNNN.nordvpn.com` resolve. country_id=202 is
# Spain; filters by openvpn_tcp technology; limit=1 returns the lowest-load
# online server. The --remote CLI flag overrides the config file's remote line.
NORD_API='https://api.nordvpn.com/v1/servers/recommendations'
NORD_QUERY='filters%5Bcountry_id%5D=202&filters%5Bservers_technologies%5D%5Bidentifier%5D=openvpn_tcp&limit=1'
if ! NORDVPN_REMOTE_HOST=$(curl -fsS --max-time 10 "${NORD_API}?${NORD_QUERY}" | jq -r '.[0].hostname'); then
  echo "::error::failed to query api.nordvpn.com for recommended ES server"
  exit 1
fi
if [[ -z "$NORDVPN_REMOTE_HOST" || "$NORDVPN_REMOTE_HOST" == "null" ]]; then
  echo "::error::api.nordvpn.com returned empty hostname for ES openvpn_tcp"
  exit 1
fi
echo "[connect.sh] NordVPN server: $NORDVPN_REMOTE_HOST"

# Chaos injection (`tun0-timeout` smoke mode): skip the openvpn invocation so the
# tun0 readiness poll times out. Production callers never set this env var.
if [[ "${SMOKE_SKIP_OPENVPN_START:-0}" != "1" ]]; then
  sudo openvpn \
    --config "$CONFIG_FILE" \
    --auth-user-pass "$AUTH_FILE" \
    --remote "$NORDVPN_REMOTE_HOST" 443 \
    --daemon \
    --writepid "$PID_FILE" \
    --log "$RUNNER_TEMP/openvpn.log"
fi

# Readiness is `ip -4 addr show tun0` returning `inet ` — NOT `openvpn --daemon`'s exit
# (the daemon forks and exits 0 before the handshake completes).
# Poll every 2s, 30s total timeout. Interface existence is not enough; require IPv4 assigned.
start_ms=$(date +%s%3N)
timeout_s=30
deadline=$(( $(date +%s) + timeout_s ))
while (( $(date +%s) < deadline )); do
  if ip -4 addr show tun0 2>/dev/null | grep -q 'inet '; then
    end_ms=$(date +%s%3N)
    # Pass the connect duration across the composite-step boundary via $GITHUB_ENV
    # so verify-country.sh (next step) can emit it in the output diagnostics bundle.
    echo "CONNECT_DURATION_MS=$(( end_ms - start_ms ))" >> "$GITHUB_ENV"
    echo "[connect.sh] tun0 up after $(( end_ms - start_ms ))ms."
    exit 0
  fi
  sleep 2
done

echo "::error::tun0 did not come up within ${timeout_s}s"
# Diagnostic dump — no credential paths leaked; ip tool output is safe.
ip addr show tun0 2>/dev/null || echo "[connect.sh] tun0 interface absent"
ip route || true
if [[ -f "$RUNNER_TEMP/openvpn.log" ]]; then
  echo "::group::openvpn daemon log (tail 80)"
  sudo tail -80 "$RUNNER_TEMP/openvpn.log" 2>/dev/null || tail -80 "$RUNNER_TEMP/openvpn.log"
  echo "::endgroup::"
fi
exit 1
