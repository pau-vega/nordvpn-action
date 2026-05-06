# Phase 2: Port nordvpn-es - Context

**Gathered:** 2026-05-06
**Status:** Ready for planning

<domain>
## Phase Boundary

Port the working `nordvpn-es` composite action from `Tutellus/tutellus-frontend-utils` PR #159 to this repo with the input/output contract frozen for v1. The action connects a runner through a NordVPN ES exit node, verifies geo via two providers, emits six structured outputs + `$GITHUB_STEP_SUMMARY` diagnostics table, and tears down via sibling `disconnect/` sub-action.

Source PR is MERGED and accessible. All 8 files ported: `action.yml`, `disconnect/action.yml`, `scripts/connect.sh`, `scripts/disconnect.sh`, `scripts/install.sh`, `scripts/verify-country.sh`, `vpn/nordvpn-es.ovpn`, `README.md`.

</domain>

<decisions>
## Implementation Decisions

### Porting Approach
- **D-01:** Straight copy from Tutellus PR #159, no behavioral changes — zero risk to v1 contract
- **D-02:** Use source PR's bundled `.ovpn` profile (already tested in Tutellus CI)
- **D-03:** Rewrite README for `pau-vega/nordvpn-actions` repo context (update all repo references from `Tutellus/tutellus-frontend-utils`)
- **D-04:** Single port commit: `feat(nordvpn-es): port action from Tutellus PR #159`
- **D-05:** Keep `$GITHUB_ACTION_PATH` usage as-is in all scripts (GitHub composite actions set this automatically)
- **D-06:** Verify Tutellus PR #159 accessibility before starting (confirmed accessible via `gh pr view 159 --repo Tutellus/tutellus-frontend-utils`)

### Script Organization
- **D-07:** Keep 4 separate scripts (connect.sh, disconnect.sh, install.sh, verify-country.sh) matching source PR structure
- **D-08:** Keep chaos injection vars (`SMOKE_PASSWORD_OVERRIDE`, `SMOKE_EXPECT_COUNTRY`, `SMOKE_SKIP_OPENVPN_START`) for testability in CI self-test
- **D-09:** Keep `#!/usr/bin/env bash` shebang + `: "${VAR:?msg}"` idiom for env-var validation
- **D-10:** Keep `set -euo pipefail` for install/connect/verify; disconnect.sh uses `set -u` only (best-effort, must not fail job)
- **D-11:** Keep sudo usage as-is in scripts (Ubuntu runner has sudo)
- **D-12:** Keep relative path `../scripts/disconnect.sh` in disconnect/action.yml (sibling to scripts/ directory)
- **D-13:** Keep dynamic NordVPN API lookup for server selection (country_id=202, openvpn_udp, limit=1)

### Diagnostics Table
- **D-14:** Markdown table format for `$GITHUB_STEP_SUMMARY` with all 6 outputs: `exit-ip`, `country`, `asn`, `tun0-state`, `default-route`, `connect-duration-ms`

### Error Messages
- **D-15:** Keep all source PR error messages as-is:
  - Ubuntu guard: `::error::Ubuntu runner required (detected $RUNNER_OS)`
  - tun0 timeout: `::error::tun0 did not come up within 30s`
  - Country mismatch: `::error::country mismatch: expected=ES got={v}`
  - DNS-egress check: emits `[verify] DNS query did NOT go through tun0` then fails
  - NordVPN API failure: `::error::api.nordvpn.com returned empty hostname for ES openvpn_udp`
  - Missing tools: `::error::openvpn missing`, `::error::jq missing`, `::error::curl missing`
- **D-16:** No explicit AUTH_FAILED check — openvpn.log tail shows it on failure (source PR pattern)

### Retry Loop Pattern
- **D-17:** Keep retry loop in `action.yml` (not in scripts) — visible in workflow UI, matches composite action constraints
- **D-18:** 2 attempts maximum, `sleep 5` between attempts, run `disconnect.sh` cleanup between attempts
- **D-19:** Final failure emits `::error::connect failed after 2 attempts`

### The Agent's Discretion
- DNS-egress check implementation details (dig/nslookup approach) — follow source PR pattern
- `$GITHUB_OUTPUT` formatting for the 6 outputs — follow source PR pattern
- Log grouping for openvpn daemon log tail — follow source PR pattern

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Source Implementation
- `https://github.com/Tutellus/tutellus-frontend-utils/pull/159` — Source PR with working `nordvpn-es` implementation (MERGED, accessible). Contains all 8 files to port.

### Project Requirements
- `.planning/ROADMAP.md` § Phase2: Port nordvpn-es — Goal, requirements (NVES-01..13), success criteria
- `.planning/REQUIREMENTS.md` § NordVPN Spain Action (NVES-01..13) — Detailed requirements for the port
- `.planning/PROJECT.md` § Key Decisions — Monorepo layout, contract freezing, Ubuntu-only constraint

### Constraints
- `.planning/AGENTS.md` — Conventional Commits scopes (`feat(nordvpn-es):`), fork-safety posture, composite `post:` unavailability + sibling `disconnect/` contract, Ubuntu-only runner constraint, service-credentials-only auth requirement

### Out of Scope (from PROJECT.md)
- Marketplace publication (v2)
- Docker/JavaScript actions (v1 is composite-only)
- Dynamic `.ovpn` fetching at runtime (bundled per-region)
- Runners other than `ubuntu-latest`
- Fork PR end-to-end runs (intentional fork-safety)
- Countries other than ES/US/FR in v1
- IPv6 verification
- Account email/password as inputs

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- None yet — Phase 1 (Scaffolding & Lint) has not shipped. This is the first code in the repo.

### Established Patterns
- Source PR patterns to replicate:
  - `action.yml` composite with `runs.using: "composite"`
  - Scripts in `scripts/` directory with `set -euo pipefail` (except disconnect)
  - Auth file at `$RUNNER_TEMP/nordvpn-auth.txt` mode 0600 via `install -m 0600`
  - Two-provider geo check (ipinfo.io + ifconfig.co)
  - `$GITHUB_ACTION_PATH` for script paths
  - `::error::` and `::notice::` GitHub workflow commands for user-facing messages

### Integration Points
- None yet — this phase creates the first action that subsequent phases (3: US/FR mirror) will copy
- Future self-test CI (Phase 4) will reference `./actions/nordvpn-es` as local path

</code_context>

<specifics>
## Specific Ideas

- Consumer reference form: `pau-vega/nordvpn-actions/actions/nordvpn-es@<sha>` + sibling `disconnect/` with `if: always()`
- Inputs: `username` (required), `password` (required) — NordVPN service credentials only
- Outputs: 6 pre-declared in `action.yml` and populated by `verify-country.sh` via `$GITHUB_OUTPUT`
- Verify step: expects country `ES`, both geo providers must agree or step fails
- Disconnect: best-effort cleanup, never fails the job, invoked as separate step with `if: always()`

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within Phase 2 scope (porting `nordvpn-es` with contract frozen).

</deferred>

---
*Phase: 2-Port nordvpn-es*
*Context gathered: 2026-05-06*
