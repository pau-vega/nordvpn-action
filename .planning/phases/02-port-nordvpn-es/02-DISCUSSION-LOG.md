# Phase 2: Port nordvpn-es - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-05-06
**Phase:** 2-Port nordvpn-es
**Areas discussed:** Porting approach, Script organization, Diagnostics table, Error messages, Retry loop pattern

---

## Porting Approach

| Option | Description | Selected |
|--------|-------------|----------|
| Straight copy (Recommended) | Copy all files from source PR unchanged, then verify contract matches ROADMAP. Zero behavioral-change risk. | ✓ |
| Copy + cleanup | Copy then remove dead code, rename unclear vars, reorder files. Risk: subtle behavior changes. | |
| Rewrite from scratch | New implementation using source PR as reference only. High risk for v1 contract. | |

**User's choice:** Straight copy (Recommended)
**Notes:** Tutellus PR #159 verified accessible (MERGED). All 8 files available for port.

| Option | Description | Selected |
|--------|-------------|----------|
| Source PR's .ovpn (Recommended) | Already tested in Tutellus CI. Risk: server may be decommissioned (drift). | ✓ |
| Fresh download | Get current NordVPN recommended server. Risk: untested profile, potential incompatibility. | |
| Both — test then decide | Download fresh, compare with source PR, use whichever passes self-test. | |

**User's choice:** Source PR's .ovpn (Recommended)

| Option | Description | Selected |
|--------|-------------|----------|
| Rewrite for new repo (Recommended) | Update repo URLs, add pau-vega/nordvpn-actions references, keep structure from source PR. | ✓ |
| Port as-is first | Copy from source PR, update later. Risk: broken links to old repo. | |
| Merge both | Port structure from source PR + add new repo context immediately. | |

**User's choice:** Rewrite for new repo (Recommended)

| Option | Description | Selected |
|--------|-------------|----------|
| Yes, verify first (Recommended) | Confirm PR accessible, files viewable. If not, need alternative source. | ✓ |
| Skip check | Assume PR is accessible. Risk: port blocked if PR was closed/deleted. | |
| You decide | Agent will check accessibility as part of port preparation. | |

**User's choice:** Yes, verify first (Recommended) — PR confirmed accessible via `gh pr view 159 --repo Tutellus/tutellus-frontend-utils`

| Option | Description | Selected |
|--------|-------------|----------|
| Yes, update all refs (Recommended) | Clean port. No broken links/references to old repo. | ✓ |
| Port as-is | Keep Tutellus references. Risk: confused users clicking old repo links. | |
| Only update actionable refs | Update uses: examples, keep attribution comments to source PR. | |

**User's choice:** Yes, update all refs (Recommended)

| Option | Description | Selected |
|--------|-------------|----------|
| Single port commit (Recommended) | One clean commit: 'feat(nordvpn-es): port action from Tutellus PR #159'. Simple history. | ✓ |
| Preserve commit structure | Cherry-pick or replicate source PR commits. Complex, adds noise to this repo's history. | |
| You decide | Agent will use single clean commit with proper attribution. | |

**User's choice:** Single port commit (Recommended)

| Option | Description | Selected |
|--------|-------------|----------|
| Yes, keep as-is (Recommended) | GitHub composite actions set this automatically. Port unchanged. | ✓ |
| Double-check in source PR | Read source PR scripts to confirm correct usage before porting. | |
| You decide | Agent will verify during port execution. | |

**User's choice:** Yes, keep as-is (Recommended)

---

## Script Organization

| Option | Description | Selected |
|--------|-------------|----------|
| Keep 4 scripts (Recommended) | Source PR pattern. One script per composite step. Matches action.yml step calls. | ✓ |
| Consolidate into 2 | Merge install+connect, verify+disconnect. Fewer files but breaks source PR parity. | |
| You decide | Agent will keep source PR structure for v1. | |

**User's choice:** Keep 4 scripts (Recommended)

| Option | Description | Selected |
|--------|-------------|----------|
| Keep for testing (Recommended) | Source PR has them. Useful for CI self-test smoke runs. No impact on production. | ✓ |
| Remove from v1 | Cleaner scripts. Can add back when self-test CI (Phase 4) needs them. | |
| You decide | Agent will keep them for testability with clear comments. | |

**User's choice:** Keep for testing (Recommended)

| Option | Description | Selected |
|--------|-------------|----------|
| Keep as-is (Recommended) | Source PR pattern. Portable, clear error messages on missing inputs. | ✓ |
| Switch to #!/bin/bash | Explicit bash path. Less portable across systems. | |
| You decide | Agent will keep source PR style. | |

**User's choice:** Keep as-is (Recommended)

| Option | Description | Selected |
|--------|-------------|----------|
| Keep as-is (Recommended) | Source PR pattern. Checks server liveness before connecting. | ✓ |
| Bundle static IP | Set remote to a specific IP. Breaks if NordVPN rotates server. | |
| You decide | Agent will keep source PR pattern for v1. | |

**User's choice:** Keep as-is (Recommended)

| Option | Description | Selected |
|--------|-------------|----------|
| Keep as-is (Recommended) | disconnect.sh is best-effort (must not fail job). Source PR pattern is intentional. | ✓ |
| Standardize to -euo pipefail | All scripts same style. But disconnect.sh failures would fail the job via if: always(). | |
| You decide | Agent will keep source PR pattern for v1. | |

**User's choice:** Keep as-is (Recommended)

| Option | Description | Selected |
|--------|-------------|----------|
| Keep as-is (Recommended) | Source PR runs scripts under Ubuntu runner which has sudo. Simple, works. | ✓ |
| Add sudo guard | Check [[ $EUID -eq 0 ]] || sudo. More portable but adds complexity. | |
| You decide | Agent will keep source PR pattern for v1. | |

**User's choice:** Keep as-is (Recommended)

| Option | Description | Selected |
|--------|-------------|----------|
| Keep relative path (Recommended) | Source PR pattern. Works because disconnect/ is sibling to scripts/. | ✓ |
| Copy disconnect.sh into disconnect/ | Self-contained sub-action. Duplicates file, breaks source PR parity. | |
| You decide | Agent will keep source PR relative path. | |

**User's choice:** Keep relative path (Recommended)

---

## Diagnostics Table

| Option | Description | Selected |
|--------|-------------|----------|
| Markdown table (Recommended) | Clean GitHub rendering. Source PR uses key=value pairs — table is nicer for humans. | ✓ |
| Pipe-delimited | Simple parseable format. Less human-friendly in GitHub UI. | |
| Source PR style | Keep key=value pairs as-is from source PR. Minimal change. | |

**User's choice:** Markdown table (Recommended)

---

## Error Messages

| Option | Description | Selected |
|--------|-------------|----------|
| Keep exact wording (Recommended) | Source PR pattern. Clear, actionable error with runner OS context. | ✓ |
| Customize wording | Different phrasing, maybe add docs link or more context. | |
| You decide | Agent will keep source PR wording for v1. | |

**User's choice:** Keep exact wording (Recommended) — `::error::Ubuntu runner required`

| Option | Description | Selected |
|--------|-------------|----------|
| Keep as-is (Recommended) | Source PR pattern. Clear, informative for debugging. | ✓ |
| Customize | Different wording, maybe add troubleshooting hint. | |
| You decide | Agent will keep source PR style. | |

**User's choice:** Keep as-is (Recommended) — DNS-egress check message

| Option | Description | Selected |
|--------|-------------|----------|
| Keep as-is (Recommended) | Source PR pattern. Clear expected vs actual. | ✓ |
| Add troubleshooting hint | e.g., 'check .ovpn server or NordVPN account' — more helpful but changes behavior. | |
| You decide | Agent will keep source PR pattern. | |

**User's choice:** Keep as-is (Recommended) — country mismatch error

| Option | Description | Selected |
|--------|-------------|----------|
| Keep as-is (Recommended) | Source PR pattern. Clear timeout value in message. | ✓ |
| Customize | Different wording or add troubleshooting hint. | |
| You decide | Agent will keep source PR pattern. | |

**User's choice:** Keep as-is (Recommended) — connect timeout error

| Option | Description | Selected |
|--------|-------------|----------|
| Keep as-is (Recommended) | Source PR pattern. Clear which API and which country failed. | ✓ |
| Customize | Different wording or add hint to check network. | |
| You decide | Agent will keep source PR pattern. | |

**User's choice:** Keep as-is (Recommended) — NordVPN API failure error

| Option | Description | Selected |
|--------|-------------|----------|
| Keep as-is (Recommended) | Source PR pattern. Clear which tool is missing. | ✓ |
| Customize | Different wording or add install hint. | |
| You decide | Agent will keep source PR pattern. | |

**User's choice:** Keep as-is (Recommended) — missing tools error messages

| Option | Description | Selected |
|--------|-------------|----------|
| No, keep as-is (Recommended) | Source PR pattern. openvpn.log tail shows AUTH_FAILED. Less code, same debugability. | ✓ |
| Add AUTH_FAILED check | Grep openvpn.log for AUTH_FAILED before timeout. More specific error for users. | |
| You decide | Agent will keep source PR pattern for v1. | |

**User's choice:** No, keep as-is (Recommended) — no explicit AUTH_FAILED check

---

## Retry Loop Pattern

| Option | Description | Selected |
|--------|-------------|----------|
| Keep in action.yml (Recommended) | Source PR pattern. Retry logic visible in workflow UI. Matches composite action constraints. | ✓ |
| Move into connect.sh | Encapsulate retry in script. Less visible in workflow UI, breaks source PR parity. | |
| You decide | Agent will keep source PR pattern. | |

**User's choice:** Keep in action.yml (Recommended)

| Option | Description | Selected |
|--------|-------------|----------|
| Keep 2 attempts, 5s sleep (Recommended) | Source PR pattern. Reasonable for VPN connection. | ✓ |
| Change to 3 attempts | More robust. May slow down CI on persistent failures. | |
| You decide | Agent will keep source PR values. | |

**User's choice:** Keep 2 attempts, 5s sleep (Recommended)

| Option | Description | Selected |
|--------|-------------|----------|
| Keep as-is (Recommended) | Source PR pattern. Gives openvpn time to fully terminate. | ✓ |
| Add explicit tun0 wait | Wait for tun0 to disappear before retry. More robust but adds complexity. | |
| You decide | Agent will keep source PR pattern. | |

**User's choice:** Keep as-is (Recommended) — cleanup between retries

---

## The Agent's Discretion

- DNS-egress check implementation details (dig/nslookup approach) — follow source PR pattern
- `$GITHUB_OUTPUT` formatting for the 6 outputs — follow source PR pattern
- Log grouping for openvpn daemon log tail — follow source PR pattern

---

## Deferred Ideas

None — discussion stayed within Phase 2 scope (porting `nordvpn-es` with contract frozen).
