---
phase: 01-scaffolding-lint
plan: 03
subsystem: ci
tags: [lint, actionlint, shellcheck, security, workflow, pull_request_target]
dependency_graph:
  requires: []
  provides:
    - .github/workflows/actions-lint.yml
  affects:
    - Plan 04 branch-protection setup (uses job names: actionlint, shellcheck, block-pull-request-target)
    - Phase 2+ PR gate (all action code PRs pass through this workflow)
tech_stack:
  added:
    - reviewdog/action-actionlint@6fb7acc99f4a1008869fa8a0f09cfca740837d9d # v1.72.0
    - ludeeus/action-shellcheck@00cae500b08a931fb5698e11e79bfbd38e612a38 # 2.0.0
    - actions/checkout@de0fac2e4500dabe0009e67214ff5f5447ce83dd # v6.0.2
  patterns:
    - Three parallel jobs in a single workflow file
    - Grep-based CI guard for banned workflow trigger patterns
    - SHA + comment pin posture on all external actions
key_files:
  created:
    - .github/workflows/actions-lint.yml
  modified: []
decisions:
  - Three jobs (actionlint + shellcheck + block-pull-request-target) in one workflow for cohesion and single required-check registration surface
  - LINT-05 guard uses two regex patterns (key form + array-element form) to match all YAML trigger forms without matching comments
  - Guard scoped to .github/workflows/** only (not actions/**/action.yml) per D-11; composite action.yml cannot define triggers
  - shopt -s globstar + nullglob in the run block ensures ** recurses correctly on Ubuntu without missing empty directories
metrics:
  duration: ~5 minutes
  completed: "2026-04-27"
  tasks_completed: 1
  files_created: 1
---

# Phase 01 Plan 03: Lint Workflow Summary

**One-liner:** Three-job actions-lint workflow enforcing actionlint + shellcheck + pull_request_target ban via SHA-pinned composite actions with least-privilege permissions.

## What Was Built

Created `.github/workflows/actions-lint.yml` (3465 bytes, 82 lines) with three parallel jobs gating every PR or main-branch push touching `actions/**`, `.github/workflows/**`, or `.github/actions/**`.

### File Created

| File | Size | Lines |
|------|------|-------|
| `.github/workflows/actions-lint.yml` | 3465 bytes | 82 |

### Three Job IDs and Explicit Names (for Plan 04 required-checks list)

| Job ID | Explicit `name:` | Purpose |
|--------|-----------------|---------|
| `actionlint` | `actionlint` | Lint all workflow YAML + inline shell via reviewdog/action-actionlint |
| `shellcheck` | `shellcheck` | Lint standalone .sh scripts under ./actions via ludeeus/action-shellcheck |
| `block-pull-request-target` | `block-pull-request-target` | Grep guard rejecting pull_request_target triggers in .github/workflows/** |

### Pinned SHAs Verified Byte-Exact Against CLAUDE.md

| Action | SHA | Tag |
|--------|-----|-----|
| `actions/checkout` | `de0fac2e4500dabe0009e67214ff5f5447ce83dd` | # v6.0.2 |
| `reviewdog/action-actionlint` | `6fb7acc99f4a1008869fa8a0f09cfca740837d9d` | # v1.72.0 |
| `ludeeus/action-shellcheck` | `00cae500b08a931fb5698e11e79bfbd38e612a38` | # 2.0.0 |

`actions/checkout` appears 3 times (once per job), all with the same SHA.

### LINT-01..05 Coverage

| Requirement | Satisfied By |
|-------------|-------------|
| LINT-01 | `on: pull_request:` + `push: branches: [main]` with `paths:` filter covering `actions/**`, `.github/workflows/**`, `.github/actions/**` |
| LINT-02 | `reviewdog/action-actionlint@<SHA>` with `fail_on_error: true`, `level: error`, `reporter: github-pr-review` |
| LINT-03 | `ludeeus/action-shellcheck@<SHA>` with `scandir: ./actions`, `severity: style`, `check_together: 'yes'`, `SHELLCHECK_OPTS: "-e SC1090 -e SC1091"` |
| LINT-04 | Workflow-level `permissions: contents: read`; `concurrency: group: actions-lint-${{ github.workflow }}-${{ github.ref }}` with `cancel-in-progress: true` |
| LINT-05 | `block-pull-request-target` job with two D-10 regex patterns, `::error::` annotations, `PITFALLS.md §2` + `AGENTS.md §Security Considerations` citations, `exit 1` on detection |

### Workflow Trigger (Self-Compliance)

- Uses `on: pull_request` and `on: push: branches: [main]`
- Does NOT use `pull_request_target` anywhere
- The workflow self-passes the LINT-05 guard when run on its own file

### Permissions and Concurrency

- `permissions: contents: read` at workflow level (not job level) — jobs inherit, no write scope anywhere
- `concurrency: group: actions-lint-${{ github.workflow }}-${{ github.ref }}` with `cancel-in-progress: true` — cancels in-progress runs on same ref, saves CI minutes

### LINT-05 Grep Guard Regex Semantics (D-10)

Two patterns cover all YAML trigger forms:
1. `'^[[:space:]]*pull_request_target[[:space:]]*:'` — matches key form (`pull_request_target:` indented under `on:`)
2. `'^[[:space:]]*-[[:space:]]+pull_request_target([[:space:]]|$)'` — matches array-element form (`  - pull_request_target` under `on:`)

Comments (`# pull_request_target is banned`) and quoted string literals do NOT match either pattern. Scope is `.github/workflows/**/*.yml` and `.github/workflows/**/*.yaml` only (D-11).

### Error Message Structure (D-12)

On detection, the guard:
1. Emits `::error::` annotation naming each offending file
2. Cites `AGENTS.md §Security Considerations` and `.planning/research/PITFALLS.md §2`
3. Includes one-line ACE-class summary
4. Suggests the `pull_request` + split-workflow-pattern alternative
5. Exits with `exit 1`

### Note for Plan 04 (Branch Protection)

Required check names to register: `actionlint`, `shellcheck`, `block-pull-request-target`

These match the `name:` field of each job (which also matches the job ID key), ensuring the GitHub status check name is stable and predictable regardless of GitHub's default behavior.

## Deviations from Plan

None — plan executed exactly as written.

## Known Stubs

None. This plan creates a workflow file only; no data flows to UI rendering.

## Threat Flags

No new threat surface beyond what was modeled in the plan's threat model. The workflow creates no new network endpoints or auth paths; it is a pure lint gate with `permissions: contents: read`.

## Self-Check: PASSED

- `.github/workflows/actions-lint.yml` exists: FOUND
- Commit `f1788b3` exists: FOUND
- All 7 phase-end verification gates: PASS
- `actionlint .github/workflows/actions-lint.yml` exits 0: PASS
