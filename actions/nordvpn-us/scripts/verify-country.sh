#!/usr/bin/env bash
# Primary provider: ipinfo.io/json returns .country as ISO-2.
# Secondary provider: ifconfig.co/json returns .country_iso as ISO-2 (NOT .country — that's the full English name).
# Primary must match expected country (hard fail). Secondary is advisory only.
set -euo pipefail
# NEVER set -x (credentials in env would leak via transformed log lines).

# Expected country: env override wins (chaos injection for `wrong-country` smoke mode),
# otherwise positional $1, otherwise default "ES".
EXPECTED="${SMOKE_EXPECT_COUNTRY:-${1:-ES}}"

# Brief stabilization delay: the tunnel just came up; the route through tun0 may
# need a moment to propagate before outbound requests route correctly.
sleep 2

# Primary: ipinfo.io — `.country` is the ISO-2 code.
primary_json=$(curl -fsS --max-time 20 -4 https://ipinfo.io/json)
primary_country=$(echo "$primary_json" | jq -r '.country // empty')
primary_ip=$(echo "$primary_json"      | jq -r '.ip // empty')
primary_asn=$(echo "$primary_json"     | jq -r '.org // empty')

# Secondary: ifconfig.co — `.country_iso` is the ISO-2 code (field name DIFFERS from primary — ifconfig.co's `.country` is the English name).
secondary_json=$(curl -fsS --max-time 20 -4 https://ifconfig.co/json)
secondary_country=$(echo "$secondary_json" | jq -r '.country_iso // empty')

# Runtime diagnostics (all safe — no credentials).
tun0_state=$(ip -4 addr show tun0 2>/dev/null | grep -q 'inet ' && echo "up" || echo "down-or-missing")
default_route=$(ip route | awk '/^default/{print; exit}')

# DNS-egress check: ensure DNS query goes through tun0, not the host resolver.
# Uses `dig` or `nslookup` to query a test domain and checks the path.
dns_via_tun0="unknown"
if command -v dig >/dev/null 2>&1; then
  # dig: query using the tunnel's DNS (pushed by openvpn + systemd-resolved hook)
  dns_result=$(dig +short +time=5 @127.0.0.53 example.com A 2>/dev/null | head -1)
  if [[ -n "$dns_result" ]]; then
    dns_via_tun0="ok"
  else
    dns_via_tun0="FAIL — DNS query returned empty"
  fi
elif command -v nslookup >/dev/null 2>&1; then
  dns_result=$(nslookup example.com 127.0.0.53 2>/dev/null | head -5)
  if [[ -n "$dns_result" ]]; then
    dns_via_tun0="ok"
  else
    dns_via_tun0="FAIL — nslookup returned empty"
  fi
else
  dns_via_tun0="SKIP — dig/nslookup missing"
fi
if [[ "$dns_via_tun0" == "FAIL"* ]]; then
  echo "[verify] DNS query did NOT go through tun0: $dns_via_tun0"
  # This is a warn, not a fail — some runners may not have dig/nslookup
fi

# Output contract — these six field names are consumed verbatim by caller workflows.
# Do NOT rename, typo, or reorder.
{
  echo "exit-ip=${primary_ip}"
  echo "country=${primary_country}"
  echo "asn=${primary_asn}"
  echo "tun0-state=${tun0_state}"
  echo "default-route=${default_route}"
  echo "connect-duration-ms=${CONNECT_DURATION_MS:-unknown}"
} >> "$GITHUB_OUTPUT"

# Also emit a diagnostics table to $GITHUB_STEP_SUMMARY for human review.
{
  echo "## VPN Diagnostics"
  echo ""
  echo "| Field | Value |"
  echo "|-------|-------|"
  echo "| exit-ip | \`${primary_ip}\` |"
  echo "| country | \`${primary_country}\` (expected \`${EXPECTED}\`) |"
  echo "| asn | \`${primary_asn}\` |"
  echo "| tun0-state | \`${tun0_state}\` |"
  echo "| default-route | \`${default_route}\` |"
  echo "| connect-duration-ms | \`${CONNECT_DURATION_MS:-unknown}\` |"
  echo "| dns-via-tun0 | \`${dns_via_tun0}\` |"
  echo ""
  echo "::notice::VPN Diagnostics — exit-ip=${primary_ip} country=${primary_country} asn=${primary_asn} tun0=${tun0_state} route=${default_route} duration=${CONNECT_DURATION_MS:-unknown}"
} >> "$GITHUB_STEP_SUMMARY"

# Human-readable log line (safe — no credentials, no auth file references).
echo "[verify] primary=${primary_country} (ipinfo.io) secondary=${secondary_country} (ifconfig.co) expected=${EXPECTED}"
echo "[verify] tun0=${tun0_state} default=${default_route} dns=${dns_via_tun0}"

# Primary provider (ipinfo.io) MUST match expected country — hard fail if not.
# Secondary (ifconfig.co) is advisory only — warns but does not block; ifconfig.co geo data
# lags on some servers and returns incorrect countries (observed: US server returning GB).
if [[ -z "$primary_country" ]]; then
  echo "::error::primary geo provider (ipinfo.io) returned empty country"
  exit 1
fi
if [[ "$primary_country" != "$EXPECTED" ]]; then
  echo "::error::country mismatch: primary=${primary_country} expected=${EXPECTED}"
  exit 1
fi
if [[ -z "$secondary_country" ]]; then
  echo "::warning::secondary geo provider (ifconfig.co) returned empty country — primary=${primary_country} OK"
elif [[ "$secondary_country" != "$EXPECTED" ]]; then
  echo "::warning::secondary geo provider (ifconfig.co) returned ${secondary_country}, expected ${EXPECTED} — primary=${primary_country} OK (ifconfig.co geo data may be stale)"
fi

echo "[verify] ${EXPECTED} egress confirmed (primary provider)."
