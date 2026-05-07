---
phase: "02-port-nordvpn-es"
plan: 01
subsystem: vpn
tags: [nordvpn, openvpn, composite-action, github-actions]

# Dependency graph
requires:
  - phase: 01-scaffold
    provides: [monorepo structure, CI linting, branch protection]
provides:
  - [nordvpn-es composite action with 6 outputs]
  - [install.sh, connect.sh, verify-country.sh scripts]
  - [nordvpn-es.ovpn VPN profile]
affects: [02-port-nordvpn-us, 02-port-nordvpn-fr, consumer workflows]

# Tech tracking
tech-stack:
  added: [openvpn, openvpn-systemd-resolved, jq, curl]
  patterns: [composite action with sibling disconnect, two-provider geo check, DNS-egress check]
key-files:
  created:
    - actions/nordvpn-es/action.yml
    - actions/nordvpn-es/scripts/install.sh
    - actions/nordvpn-es/scripts/connect.sh
    - actions/nordvpn-es/scripts/verify-country.sh
    - actions/nordvpn-es/vpn/nordvpn-es.ovpn
  modified: []
key-decisions:
  - "Ported straight from Tutellus PR #159 (D-01: no behavioral changes)"
  - "Repo references updated from Tutellus/tutellus-frontend-utils to pau-vega/nordvpn-actions"
  - "Ubuntu-only guard added to connect.sh (NVES-06)"
patterns-established:
  - "Composite action with 3-step sequence: install → connect (retry) → verify"
  - "Sibling disconnect/ sub-action for teardown (if: always())"
  - "Two-provider geo verification (ipinfo.io + ifconfig.co)"
  - "DNS-egress check via dig/nslookup @127.0.0.53"

requirements-completed: [NVES-01, NVES-02, NVES-03, NVES-04, NVES-05, NVES-06, NVES-07, NVES-08, NVES-09, NVES-11]

# Metrics
duration: 15min
completed: 2026-05-06
---

# Phase 2 Plan 01: Port Core nordvpn-es Action Summary

**Ported working NordVPN Spanish egress action from Tutellus PR #159 with 6 structured outputs, two-provider geo verification, and DNS-egress check**

## Performance

- **Duration:** 15 min
- **Started:** 2026-05-06T12:00:00Z
- **Completed:** 2026-05-06T12:15:00Z
- **Tasks:** 3
- **Files created:** 5

## Accomplishments

- Ported `action.yml` with 2 inputs (username, password) and 6 outputs (exit-ip, country, asn, tun0-state, default-route, connect-duration-ms)
- Implemented 3-step sequence: Install (apt-get) → Connect with retry loop (2 attempts) → Verify (two geo providers)
- Created `install.sh` with openvpn + openvpn-systemd-resolved installation and tool assertions
- Created `connect.sh` with 0600 auth file, openvpn --daemon, tun0 IPv4 poll (30s timeout), Ubuntu-only guard
- Created `verify-country.sh` with ipinfo.io + ifconfig.co dual check, 6 outputs to $GITHUB_OUTPUT, $GITHUB_STEP_SUMMARY diagnostics table, DNS-egress check
- Embedded NordVPN CA certificate in `nordvpn-es.ovpn` profile with DNS hooks (update-systemd-resolved)

## Task Commits

Each task was committed atomically:

1. **Task 1: Port action.yml** - `d29d6d6` (feat)
2. **Task 2: Port scripts** - `05a0500` (feat)
3. **Task 3: Port .ovpn profile** - `60bf408` (feat)

**Plan metadata:** `832d6f6` (docs: complete plan)

_Note: TDD tasks may have multiple commits (test → feat → refactor)_

## Files Created

- `actions/nordvpn-es/action.yml` - Composite action metadata with 6 outputs wired to verify step
- `actions/nordvpn-es/scripts/install.sh` - OpenVPN installer with tool assertions
- `actions/nordvpn-es/scripts/connect.sh` - Auth file write (0600), openvpn --daemon, tun0 poll, Ubuntu guard
- `actions/nordvpn-es/scripts/verify-country.sh` - Two-provider geo check, 6 outputs, $GITHUB_STEP_SUMMARY table, DNS-egress check
- `actions/nordvpn-es/vpn/nordvpn-es.ovpn` - OpenVPN profile with CA cert, DNS hooks

## Decisions Made

- Ported straight from Tutellus PR #159 (D-01: no behavioral changes)
- Repo references updated from Tutellus/tutellus-frontend-utils to pau-vega/nordvpn-actions
- Ubuntu-only guard added to connect.sh (NVES-06)
- All scripts use `set -euo pipefail` except disconnect.sh (uses `set -u` only per D-10)
- Never `set -x` in any script (NVES-11, AGENTS.md Security)

## Deviations from Plan

None - plan executed exactly as written (straight copy per D-01 with repo reference updates)

## Issues Encountered

None - all source files successfully ported from Tutellus PR #159

## User Setup Required

None - no external service configuration required for the action itself (consumers configure NORDVPN_SERVICE_USERNAME/PASSWORD in Preview environment)

## Next Phase Readiness

- Core nordvpn-es action complete with all 8 files ported
- Ready for Plan 02 (disconnect sub-action) and Plan 03 (README.md)
- All scripts pass shellcheck, action.yml is valid YAML

---

*Phase: 02-port-nordvpn-es*

*Completed: 2026-05-06*
