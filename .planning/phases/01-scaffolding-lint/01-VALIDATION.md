---
phase: 01
slug: 01-scaffolding-lint
status: draft
nyquist_compliant: false
wave_0_complete: true
created: 2026-05-10
---

# Phase 01 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | Bash 5.x (POSIX-like verification scripts) |
| **Config file** | none — pure Bash with `set -euo pipefail` |
| **Quick run command** | `bash scripts/verify-phase-1.sh` |
| **Full suite command** | `bash scripts/verify.sh` |
| **Estimated runtime** | ~5 seconds |

---

## Sampling Rate

- **After every task commit:** Run `bash scripts/verify.sh phase-1`
- **After every plan wave:** Run `bash scripts/verify.sh`
- **Before `/gsd-verify-work`:** Full suite must be green
- **Max feedback latency:** 5 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command |
|---------|------|------|-------------|-----------|-------------------|
| 01-01-01 | 01 | 1 | SCAF-01 | file-check | `test -f LICENSE && grep -qE '^MIT License$' LICENSE` |
| 01-01-02 | 01 | 1 | SCAF-02 | grep-content | `grep -qE '^## Available actions$' README.md` |
| 01-01-02 | 01 | 1 | SCAF-03 | grep-content | `grep -qE '^## Pin forms$' README.md` |
| 01-01-03 | 01 | 1 | SCAF-06 | grep-content | `grep -qE '^## For AI Agents$' AGENTS.md` |
| 01-02-01 | 02 | 1 | SCAF-04 | file-check | `grep -qE '/actions/\*\* @pau-vega' .github/CODEOWNERS` |
| 01-02-02 | 02 | 1 | SCAF-05 | file-check | `grep -qE 'directories:' .github/dependabot.yml` |
| 01-03-01 | 03 | 1 | LINT-01 | grep-content | `grep -qE 'pull_request' .github/workflows/actions-lint.yml` |
| 01-03-01 | 03 | 1 | LINT-02 | grep-content | `grep -qE 'reviewdog/action-actionlint' .github/workflows/actions-lint.yml` |
| 01-03-01 | 03 | 1 | LINT-03 | grep-content | `grep -qE 'ludeeus/action-shellcheck' .github/workflows/actions-lint.yml` |
| 01-03-01 | 03 | 1 | LINT-04 | grep-content | `grep -qE 'permissions:' .github/workflows/actions-lint.yml` |
| 01-03-01 | 03 | 1 | LINT-05 | grep-content | `grep -qE 'block-pull-request-target' .github/workflows/actions-lint.yml` |
| 01-04-01 | 04 | 2 | SCAF-07 | file-check | `test -f scripts/setup-branch-protection.sh && test -x scripts/setup-branch-protection.sh` |
| — | — | — | actionlint | lint-tool | `actionlint .github/workflows/actions-lint.yml` |
| — | — | — | shellcheck | lint-tool | `shellcheck scripts/setup-branch-protection.sh` |

---

## Wave 0 Requirements

- [x] `scripts/verify-phase-1.sh` — centralized automated checks for all Phase 1 requirements (81 checks across SCAF-01..SCAF-07, LINT-01..LINT-05, actionlint, shellcheck)
- [x] `scripts/verify.sh` — generic dispatcher that routes to phase-specific verify scripts
- [x] `scripts/setup-branch-protection.sh` — idempotent branch protection script (Plan 04)
- [x] No additional framework required — pure Bash verification scripts are sufficient

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Branch protection enforced on `main` | SCAF-07 (remote) | Requires `gh auth login` + `gh api` write access to `pau-vega/nordvpn-actions`. The local verify script confirms script existence/content; remote enforcement is a human-action checkpoint. | Run `bash scripts/setup-branch-protection.sh` after `gh repo create` and `git push`. Verify with: `gh api repos/pau-vega/nordvpn-actions/branches/main/protection \| jq '{required_status_checks: .required_status_checks.checks \| map(.context), enforce_admins: .enforce_admins.enabled}'` |
| `/gsd-verify-work` full UAT pass | All | Runs the UAT checklist from `01-UAT.md` interactively | See UAT.md for 18-test checklist. After verify-phase-1.sh passes, run through UAT tests 1-18 manually or via `/gsd-verify-work`. |

---

## Validation Sign-Off

- [x] All tasks have `<automated>` verify or Wave 0 dependencies
- [x] Sampling continuity: no 3 consecutive tasks without automated verify
- [x] Wave 0 covers all MISSING references
- [x] No watch-mode flags
- [x] Feedback latency < 5s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
