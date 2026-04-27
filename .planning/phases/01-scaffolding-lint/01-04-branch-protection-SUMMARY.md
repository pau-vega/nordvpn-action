---
phase: "01-scaffolding-lint"
plan: "04"
subsystem: "branch-protection"
status: "partial — stopped at human-action checkpoint"
tags: ["branch-protection", "gh-cli", "github-api", "scaffold"]
dependency_graph:
  requires:
    - "01-01-foundation-docs"
    - "01-02-github-config"
    - "01-03-lint-workflow"
  provides:
    - "scripts/setup-branch-protection.sh"
    - "github.com/pau-vega/nordvpn-actions (pending Task 2)"
    - "main branch protection (pending Task 3)"
  affects:
    - "all future PRs (gated by branch protection once Task 3 completes)"
tech_stack:
  added: []
  patterns:
    - "gh api PUT /repos/{owner}/{repo}/branches/{branch}/protection (idempotent full-replace)"
    - "Pre-flight checks: gh CLI presence + auth status + repo existence"
key_files:
  created:
    - "scripts/setup-branch-protection.sh"
  modified: []
decisions:
  - "Used `checks: [{context, app_id: -1}]` (modern API shape) over deprecated flat `contexts` string array — ensures GitHub Actions check runs are matched by any GitHub App (app_id: -1)"
  - "script uses PUT (full replace) — idempotent by definition; running twice produces same end state"
  - "restrictions: null (not {}) — empty object would lock maintainer out of pushing"
metrics:
  duration: "~5 minutes (Task 1 only)"
  completed_date: "2026-04-27"
  tasks_completed: 1
  tasks_total: 3
  files_created: 1
  files_modified: 0
---

# Phase 01 Plan 04: Branch Protection SUMMARY (partial)

**One-liner:** Idempotent `gh api` PUT script enabling `main` branch protection with three `actions-lint` required checks (`actionlint`, `shellcheck`, `block-pull-request-target`), `enforce_admins: true`, 0 required reviews.

**Status:** STOPPED at human-action checkpoint. Task 1 completed and committed. Tasks 2 and 3 require human action (directory rename, GitHub repo creation, push, branch-protection script run).

## Completed Tasks

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Write scripts/setup-branch-protection.sh | `785180a` | scripts/setup-branch-protection.sh |

## Pending Tasks (Human-Action Checkpoint)

| Task | Name | Type | Blocked By |
|------|------|------|-----------|
| 2 | Rename local dir, create GitHub repo, push scaffold | `checkpoint:human-action` | Human must rename dir, run `gh repo create`, push |
| 3 | Run setup-branch-protection.sh, verify branch protection | `checkpoint:human-verify` | Depends on Task 2 |

## Checkpoint A: Pre-Push Verification (PASSED)

All 5 local-state checks passed before stopping at the human-action checkpoint:

1. **All 7 artifacts present** — LICENSE, README.md, AGENTS.md, .github/CODEOWNERS, .github/dependabot.yml, .github/workflows/actions-lint.yml, scripts/setup-branch-protection.sh (executable -rwxr-xr-x).
2. **Working tree clean** — `git status --porcelain` returns empty (untracked `.claude/` worktree dir is GSD runtime, not a concern).
3. **Commit count** — 10+ commits in history; the 4 Phase 1 plan commits are: `785180a` (Plan 04), `146f115` (Plan 03), `fb187be`+`ecc07d3`+`ab16775` (Plan 02), `88d1732`+`6340b5b`+`22ec297` (Plan 01) — all Conventional-Commit prefixed.
4. **No remote** — `git remote -v` returns empty (correct: `gh repo create` has not run yet).
5. **Working dir still singular** — `basename $(pwd)` = `nordvpn-action` (rename happens in Task 2).

## File Details

### scripts/setup-branch-protection.sh (4002 bytes, -rwxr-xr-x)

Created at `scripts/setup-branch-protection.sh`. Key properties:

- `#!/usr/bin/env bash` shebang on line 1
- `set -euo pipefail` strict mode
- No `set -x` (secrets not leaked via shell trace — T-01-04-03 mitigation)
- `OWNER="pau-vega"` / `REPO="nordvpn-actions"` constants
- `REQUIRED_CHECKS_JSON` array with 3 entries: `actionlint`, `shellcheck`, `block-pull-request-target`
- Pre-flight: `command -v gh` + `gh auth status` + `gh api repos/${OWNER}/${REPO}` existence check
- `gh api --method PUT` (full replace, idempotent) to `repos/${OWNER}/${REPO}/branches/${BRANCH}/protection`
- Settings: `enforce_admins: true` (D-16), `required_approving_review_count: 0` (D-15), `strict: true`, `restrictions: null`
- Shellcheck: clean (verified locally)

## Deviations from Plan

None — plan executed exactly as written for Task 1.

## Known Stubs

None — Task 1 produces a fully functional script. Remote-side artifacts (GitHub repo, branch protection settings) are pending human action in Tasks 2 and 3.

## Threat Flags

None — script adds no new network endpoints or trust boundaries beyond what the plan's threat model documents (T-01-04-01 through T-01-04-06 all addressed).

## Notes for Future Plans

- **Phase 4 (TEST-09):** Amend `REQUIRED_CHECKS_JSON` in this script to add 3 more entries for self-test matrix job names. The JSON array structure is designed for trivial amendment.
- **Phase 2 CODEOWNERS:** Consider adding `/scripts/** @pau-vega` to `.github/CODEOWNERS` so future modifications of this script auto-request review (currently only branch protection's PR-required gate covers it, not a reviewer-required gate — T-01-04-02 residual risk).

## Self-Check

**Task 1:**
- `scripts/setup-branch-protection.sh` exists: FOUND
- Commit `785180a` exists: FOUND

## Self-Check: PASSED

Task 1 artifacts verified. Tasks 2 and 3 pending human action.
