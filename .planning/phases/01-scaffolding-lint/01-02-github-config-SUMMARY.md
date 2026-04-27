---
phase: 01-scaffolding-lint
plan: 02
subsystem: infra
tags: [github-actions, dependabot, codeowners, governance]

# Dependency graph
requires: []
provides:
  - .github/CODEOWNERS with glob ownership rule /actions/** @pau-vega covering all current and future regions
  - .github/dependabot.yml with plural directories: block enumerating all 7 paths for github-actions ecosystem
affects:
  - 01-scaffolding-lint (actions-lint workflow in plan 03 benefits from dependabot monitoring)
  - All future region-adding phases (CODEOWNERS is zero-touch; dependabot.yml needs additive entries only for a 4th region)

# Tech tracking
tech-stack:
  added: []
  patterns:
    - CODEOWNERS glob pattern /actions/** covers all recursive subdirectories without per-region maintenance
    - Dependabot plural directories: key (GA 2024-06-25) collapses 7 separate update blocks into one
    - commit-message.prefix deps matches release-please changelog-sections for automatic changelog surfacing

key-files:
  created:
    - .github/CODEOWNERS
    - .github/dependabot.yml
  modified: []

key-decisions:
  - "Used /actions/** glob in CODEOWNERS — /actions/* only matches direct children and would miss action.yml files nested in region subdirectories"
  - "Plural directories: key in dependabot.yml (not singular directory:) — GA since 2024-06-25, collapses all 7 paths into one update block"
  - "Shipped full 7-path list pre-emptively (root + 3 regions + 3 disconnects) — Phase 2/3 region additions require zero CODEOWNERS changes and zero dependabot.yml changes for ES/US/FR"
  - "No global catch-all in CODEOWNERS — solo-maintainer repo avoids forced self-review on LICENSE/README PRs"

patterns-established:
  - "GitHub governance files in .github/: CODEOWNERS uses glob ownership, dependabot.yml uses plural directories"
  - "commit-message prefix deps in dependabot.yml aligns with release-please changelog-sections deps type"

requirements-completed: [SCAF-04, SCAF-05]

# Metrics
duration: 2min
completed: 2026-04-27
---

# Phase 1 Plan 02: GitHub Config (CODEOWNERS + Dependabot) Summary

**Glob-based CODEOWNERS for /actions/** and a single-block Dependabot config with 7 pre-enumerated paths covering all ES/US/FR regions and their disconnect sub-actions**

## Performance

- **Duration:** ~2 min
- **Started:** 2026-04-27T06:26:00Z
- **Completed:** 2026-04-27T06:28:15Z
- **Tasks:** 2
- **Files modified:** 2

## Accomplishments

- Created `.github/CODEOWNERS` with single `/actions/** @pau-vega` rule — covers all current and future region subdirectories without per-region maintenance
- Created `.github/dependabot.yml` with plural `directories:` key listing all 7 paths — prevents missing-region blindspot at the cost of a one-time enumeration
- All 6 phase-end verification gates pass; SCAF-04 and SCAF-05 requirements fully satisfied

## Task Commits

Each task was committed atomically:

1. **Task 1: Write .github/CODEOWNERS** - `ab16775` (chore)
2. **Task 2: Write .github/dependabot.yml** - `ecc07d3` (chore)

## Files Created/Modified

- `.github/CODEOWNERS` (99 bytes) — Single glob ownership rule `/actions/** @pau-vega`; no global catch-all; no per-region literals
- `.github/dependabot.yml` (453 bytes) — Single `github-actions` ecosystem block; plural `directories:` listing 7 paths; weekly Monday schedule; `deps` commit prefix; `actions: patterns: ["*"]` group

## Decisions Made

- `/actions/**` glob chosen over `/actions/*` (non-recursive) and per-region literals (require file updates per region addition). The `**` glob is future-proof by design.
- Plural `directories:` key used (not `directory:` singular) — pre-2024-06 syntax would require 7 separate `updates:` blocks; plural collapses to one.
- Full 7-path enumeration shipped now (not incrementally with each region) — eliminates a class of "forgot to add dependabot entry" human errors in Phases 2/3.
- `commit-message.prefix: "deps"` (not `"chore(deps)"`) — matches the `deps` key in release-please `changelog-sections` config so Dependabot PRs surface under "Dependencies" in per-action CHANGELOGs.
- No `assignees:`/`reviewers:` in dependabot.yml — CODEOWNERS auto-assigns `@pau-vega` to any PR touching `/actions/**`, making explicit assignment redundant.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None.

## User Setup Required

None - no external service configuration required.

## Note for Phase 2/3 Planners

**CODEOWNERS:** Requires zero changes when adding a new region. `/actions/**` covers any new `actions/nordvpn-<region>/` tree automatically.

**dependabot.yml:** Requires zero changes for ES, US, and FR (already in the list). Adding a 4th region (e.g., `nordvpn-de`) requires 2 additive entries: `"/actions/nordvpn-de"` and `"/actions/nordvpn-de/disconnect"`. That edit should be part of the PR that creates the region directory.

## Known Stubs

None.

## Threat Flags

None — `.github/CODEOWNERS` and `.github/dependabot.yml` introduce no new network endpoints, auth paths, or trust boundaries beyond what is documented in the plan's threat model (T-01-02-01 through T-01-02-04).

## Self-Check: PASSED

- `.github/CODEOWNERS` exists: FOUND
- `.github/dependabot.yml` exists: FOUND
- Task 1 commit ab16775: FOUND
- Task 2 commit ecc07d3: FOUND

## Next Phase Readiness

- Plan 03 (actions-lint workflow) can now reference `.github/dependabot.yml` as a path that Dependabot will monitor for SHA + `# vX.Y.Z` comment updates.
- Plan 04 (branch protection) can reference CODEOWNERS as the review-assignment mechanism for PRs touching `/actions/**`.
- Both files are forward-looking: no changes needed for ES/US/FR region additions in Phases 2/3.

---
*Phase: 01-scaffolding-lint*
*Completed: 2026-04-27*
