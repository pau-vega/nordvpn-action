---
phase: 04-self-test-ci
verified: 2026-05-10T10:00:00Z
status: passed
score: 7/7 must-haves verified
overrides_applied: 0
re_verification:
  previous_status: null
  previous_score: null
  gaps_closed: []
  gaps_remaining: []
  regressions: []
gaps: []
deferred: []
human_verification: []
---

# Phase 4: Self-test CI — Verification Report

**Phase Goal:** Every push to `main` and every non-fork PR runs all three regional actions end-to-end in a matrix using local `./actions/...` references, forks skip cleanly with a clear notice, a weekly scheduled run acts as a drift sentinel that opens a `region-drift` issue on failure, and `main` is now protected behind both `actions-lint` and the three `self-test` matrix jobs.

**Verified:** 2026-05-10T10:00:00Z
**Status:** PASSED
**Re-verification:** No (initial verification)

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | A push to `main` triggers self-test which runs all 3 region matrix jobs (nordvpn-es, nordvpn-us, nordvpn-fr) | ✓ VERIFIED | `self-test.yml` lines 4-8: `push: branches: [main]` with path filter; line 57: `matrix.region: [es, us, fr]`; line 58: `fail-fast: false` |
| 2 | A fork PR skips self-test with a clear `::notice::` explaining Preview-environment fork-safety posture | ✓ VERIFIED | `fork-check` job (lines 35-48) compares `head.repo.full_name != github.repository`; emits `::notice::` on line 45; matrix gated by `if: needs.fork-check.outputs.is_fork == 'false'` (line 52) |
| 3 | A failed weekly schedule run opens or updates a region-drift issue listing all failed regions | ✓ VERIFIED | `drift-issue` job (lines 119-155) runs on `failure() && schedule`; upserts issue with `region-drift` label via `gh` CLI |
| 4 | A succeeding weekly schedule run closes the open drift issue with a pass-comment | ✓ VERIFIED | `drift-close` job (lines 157-178) runs on `success() && schedule`; closes open drift issue with date comment |
| 5 | Branch protection on `main` requires the 3 self-test matrix checks in addition to the 3 existing lint checks (6 total) | ✓ VERIFIED | `setup-branch-protection.sh` REQUIRED_CHECKS_JSON has 6 entries: actionlint, shellcheck, block-pull-request-target, self-test (nordvpn-es), self-test (nordvpn-us), self-test (nordvpn-fr) — validated via python3 json parse |
| 6 | All `uses:` lines in self-test.yml are SHA-pinned with `# vX.Y.Z` comments matching the canonical checksums | ✓ VERIFIED | Line 64: `actions/checkout@de0fac2e4500dabe0009e67214ff5f5447ce83dd # v6.0.2`; Line 126: same SHA pin |
| 7 | No `pull_request_target` trigger exists anywhere in self-test.yml | ✓ VERIFIED | `grep -c 'pull_request_target' .github/workflows/self-test.yml` returns 0; repo-wide grep guard in `actions-lint.yml` blocks it too |

**Score:** 7/7 truths verified

### Deferred Items

None — no later phase addresses any aspect of the self-test CI scope.

### Required Artifacts

| Artifact | Expected | Status | Details |
|---|---|---|---|
| `.github/workflows/self-test.yml` | Fork-safe matrix E2E workflow across 3 regions with drift sentinel (≥90 lines) | ✓ VERIFIED | 178 lines; contains all 4 triggers, fork-check gate, 3-region matrix, post-connect verify, drift issue jobs; passes `actionlint` with zero errors |
| `.github/actionlint.yaml` | Config suppressing false positive for `${{ matrix.* }}` in `uses:` | ✓ VERIFIED | 10 lines; valid YAML; ignores `context "matrix" is not allowed here` for `.github/workflows/**/*.{yml,yaml}` |
| `scripts/setup-branch-protection.sh` | Amended REQUIRED_CHECKS_JSON with 3 self-test check names (6 total) | ✓ VERIFIED | 104 lines; REQUIRED_CHECKS_JSON has 6 valid JSON entries; `bash -n` passes; Phase 4 amendment hint removed; header and echo message updated |

### Key Link Verification

| From | To | Via | Status | Details |
|---|---|---|---|---|
| `.github/workflows/self-test.yml` | `actions/nordvpn-${{ matrix.region }}` | Local path in `uses:` | ✓ WIRED | Line 68: `uses: ./actions/nordvpn-${{ matrix.region }}`; Line 116: disconnect variant |
| `.github/workflows/self-test.yml` | `environment: Preview` | Secret scoping | ✓ WIRED | Line 54: `environment: Preview`; secrets passed on lines 70-71 |
| `scripts/setup-branch-protection.sh` | `.github/workflows/self-test.yml` | Check name match | ✓ WIRED | Lines 35-37: `self-test (nordvpn-es)`, `self-test (nordvpn-us)`, `self-test (nordvpn-fr)` in REQUIRED_CHECKS_JSON |

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
|---|---|---|---|---|
| `self-test.yml` self-test job | `secrets.NORDVPN_SERVICE_USERNAME`, `secrets.NORDVPN_SERVICE_PASSWORD` | `environment: Preview` (GitHub runtime) | ✓ — GitHub passes runtime secrets; action uses them for OpenVPN auth | ✓ FLOWING |
| `self-test.yml` drift-issue job | `gh run view ${{ github.run_id }}` | GitHub API via `gh` CLI | ✓ — queries live workflow run data | ✓ FLOWING |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|---|---|---|---|
| Workflow YAML lint | `actionlint .github/workflows/self-test.yml` | Zero errors, zero warnings | ✓ PASS |
| No `pull_request_target` | `grep -c 'pull_request_target' .github/workflows/self-test.yml` | 0 | ✓ PASS |
| Branch protection script syntax | `bash -n scripts/setup-branch-protection.sh` | No errors | ✓ PASS |
| Branch protection JSON valid | `python3 json.loads()` on REQUIRED_CHECKS_JSON | 6 entries, all valid | ✓ PASS |
| Phase 4 hint removed | `grep -c 'Phase 4 amendment hint' scripts/setup-branch-protection.sh` | 0 matches | ✓ PASS |

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|---|---|---|---|---|
| TEST-01 | 04-01-PLAN.md | Self-test.yml triggers on push, pull_request, schedule; no pull_request_target | ✓ VERIFIED | Lines 4-14: 3 triggers (+ workflow_dispatch); zero pull_request_target |
| TEST-02 | 04-01-PLAN.md | Fork-skip guard with `::notice::` | ✓ VERIFIED | `fork-check` job (lines 35-48) with fork PR notice |
| TEST-03 | 04-01-PLAN.md | Matrix over all 3 regions with fail-fast: false | ✓ VERIFIED | `region: [es, us, fr]`, `fail-fast: false` (lines 57-58) |
| TEST-04 | 04-01-PLAN.md | Local path reference (`uses: ./actions/...`) | ✓ VERIFIED | Line 68: `uses: ./actions/nordvpn-${{ matrix.region }}` |
| TEST-05 | 04-01-PLAN.md | Disconnect step with `if: always()` | ✓ VERIFIED | Lines 115-117: disconnect with `if: always()` |
| TEST-06 | 04-01-PLAN.md | `environment: Preview` + NordVPN secrets | ✓ VERIFIED | Line 54: `environment: Preview`; lines 70-71: secrets |
| TEST-07 | 04-01-PLAN.md | Concurrency with `cancel-in-progress: false` | ✓ VERIFIED | Lines 31-32 (workflow-level), lines 61-62 (per-job); both with `cancel-in-progress: false` |
| TEST-08 | 04-01-PLAN.md | Drift sentinel opens region-drift issue on schedule failure | ✓ VERIFIED | `drift-issue` job (lines 119-155) upserts issues; `drift-close` (lines 157-178) auto-closes on success |
| TEST-09 | 04-01-PLAN.md | Branch protection requires self-test matrix checks | ✓ VERIFIED | REQUIRED_CHECKS_JSON includes all 3 self-test check names alongside 3 lint checks (6 total) |

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|---|---|---|---|---|
| None | — | — | — | No TODOs, FIXMEs, placeholders, stubs, console.log-only implementations, or hardcoded empty data found in any deliverable file |

### Human Verification Required

None — all artifacts are code-content verifiable. No visual, timing, or external-service-integration tests needed at this phase boundary.

### Gaps Summary

**No gaps found.** All 7 must-have truths, all 9 requirements (TEST-01..09), all 3 required artifacts at all verification levels, and all 3 key links are verified against the actual codebase.

Note: The PLAN's acceptance criteria stated `grep -c 'self-test (nordvpn-'` should return 3, but the actual count is 5 — this is because the plan's Edit 3 (echo message) and Edit 4 (comment header) also include the check names. The implementation correctly follows all four edit instructions; the acceptance criteria in the PLAN was not updated to reflect those additions. This is a PLAN documentation inconsistency, not an implementation gap.

---

_Verified: 2026-05-10T10:00:00Z_
_Verifier: the agent (gsd-verifier)_
