# Phase 3: Mirror nordvpn-us + nordvpn-fr - Context

**Gathered:** 2026-05-06
**Status:** Ready for planning
**Mode:** Infrastructure phase (mirror) — auto-generated per smart discuss

<domain>
## Phase Boundary

Mirror the `nordvpn-es` tree to create `nordvpn-us` and `nordvpn-fr` actions. Each new region must have identical input/output contracts to `nordvpn-es`, routing through the correct exit country (US/France) and verified by the same two-provider check. The three region trees must be byte-for-byte diffable in CI so drift is flagged at PR time.

</domain>

<decisions>
## Implementation Decisions

### Region Configuration
- **nordvpn-us**: Country code `US`, NordVPN country_id `230`, server hostname `us.nordvpn.com`
- **nordvpn-fr**: Country code `FR`, NordVPN country_id `76`, server hostname `fr.nordvpn.com`

### the agent's Discretion
All implementation choices are at the agent's discretion — infrastructure mirror phase. Use Phase 2 (`nordvpn-es`) as the source of truth. Key patterns to replicate:
- Composite action structure (`action.yml` with 2 inputs, 6 outputs)
- Script organization (install.sh, connect.sh, verify-country.sh, disconnect.sh)
- DNS-egress check via systemd-resolved
- Two-provider geo verification (ipinfo.io + ifconfig.co)
- Auth file mode 0600, Ubuntu-only guard, no `set -x`
- Sibling `disconnect/` sub-action with `set -u` only

### CI Drift Check
Add a CI step that diffs `scripts/*.sh` across the three region directories (ignoring the hardcoded country code) and fails on divergence.

</decisions>

<code_context>
## Existing Code Insights

### Source Tree (from Phase 2)
- `actions/nordvpn-es/action.yml` — composite action with retry loop
- `actions/nordvpn-es/scripts/install.sh` — OpenVPN + openvpn-systemd-resolved installer
- `actions/nordvpn-es/scripts/connect.sh` — Auth file, openvpn --daemon, tun0 poll
- `actions/nordvpn-es/scripts/verify-country.sh` — Two-provider geo check, 6 outputs
- `actions/nordvpn-es/vpn/nordvpn-es.ovpn` — OpenVPN profile with es.nordvpn.com
- `actions/nordvpn-es/disconnect/` — Sibling teardown sub-action

### Patterns to Replicate
- All Bash scripts: `set -euo pipefail` (disconnect.sh uses `set -u` only)
- No `set -x` (security)
- `$GITHUB_ACTION_PATH` for script paths
- `$GITHUB_OUTPUT` for step outputs
- `$GITHUB_STEP_SUMMARY` for diagnostics table
- `actions-lint.yml` already covers all `actions/**/*.yml`

</code_context>

<specifics>
## Specific Ideas

No specific requirements — infrastructure mirror phase. Mirror nordvpn-es exactly with region-specific substitutions:
- Country code: ES → US/FR
- Country ID: 202 → 230/76
- Server hostname: es.nordvpn.com → us.nordvpn.com / fr.nordvpn.com
- OpenVPN config: `remote us.nordvpn.com 1194` / `remote fr.nordvpn.com 1194`

</specifics>

<deferred>
## Deferred Ideas

None — infrastructure mirror phase.

</deferred>
