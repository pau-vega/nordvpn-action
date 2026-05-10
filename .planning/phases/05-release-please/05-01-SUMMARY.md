---
phase: 05-release-please
plan: 01
subsystem: infra
tags: [release-please, github-actions, conventional-commits, monorepo, semver]

# Dependency graph
requires:
  - phase: 01-scaffolding-lint
    provides: SHA-pinning contract, Conventional Commits policy, branch protection on main
  - phase: 02-nordvpn-es
    provides: actions/nordvpn-es/ directory with committed code
  - phase: 03-mirror-us-fr
    provides: actions/nordvpn-us/ and actions/nordvpn-fr/ directories
provides:
  - release-please config wiring files
affects:
  - 06-floating-major-tags

# Tech tracking
tech-stack:
  added:
    - googleapis/release-please-action@v5.0.0 (SHA: 45996ed1f6d02564a971a2fa1b5860e934307cf7)
  patterns:
    - Monorepo release-please with separate-pull-requests per region
    - Single root CHANGELOG.md shared across 3 packages
    - release-as bootstrap for initial version forcing
    - Angular changelog section ordering with selective visibility

key-files:
  created:
    - .github/release-please-config.json
    - .release-please-manifest.json
    - .github/workflows/release-please.yml
    - CHANGELOG.md
  modified:
    - .planning/phases/05-release-please/05-CONTEXT.md

key-decisions:
  - "Changelog sections: feat/fix/perf/refactor/docs/deps visible; revert/chore/test/ci/style/build hidden (D-01/D-02/D-03)"
  - "Bootstrap: release-as: 0.1.0 on ES only, US/FR at 0.0.0 seed (D-04/D-05/D-06)"
  - "Root CHANGELOG.md with all 3 packages pointing to it (D-07/D-08/D-09)"
  - "Single workflow job with outputs (releases_created, paths_released) for Phase 6 consumption"
  - "No paths: filter on push trigger — Conventional Commit scopes route per-package"
  - "Workflow permissions: contents: write + pull-requests: write (REL-04)"
  - "Checkout with fetch-depth: 0 for full git history (REL-05)"

patterns-established:
  - "SHA-pinned uses: lines with # vX.Y.Z comment (googleapis/release-please-action, actions/checkout)"
  - "default '-' tag-separator (no tag-separator field) producing nordvpn-<region>-vX.Y.Z"
  - "Conventional Commit scope ci(release): for infrastructure PRs to avoid unintended release bumps"

requirements-completed: [REL-01, REL-02, REL-03, REL-04, REL-05, REL-06]

# Metrics
duration: ~10min
completed: 2026-05-10
---

# Phase 5 Plan 01: Release-Please Configuration & Workflow Summary

**Per-region release-please wiring: 3-package monorepo config with separate PRs, Angular changelog sections, ES bootstrapped at 0.1.0, root CHANGELOG.md with documented merge risk**

## Performance

- **Duration:** ~10 min
- **Started:** 2026-05-10
- **Completed:** 2026-05-10
- **Tasks:** 3
- **Files created:** 4 (3 config/workflow + 1 CHANGELOG)
- **Files modified:** 1 (CONTEXT.md)

## Accomplishments
- `.github/release-please-config.json` — 3-package monorepo config: `release-type: simple`, `separate-pull-requests: true`, 12 changelog sections (6 visible via Angular order, 6 hidden), ES bootstrapped at 0.1.0 via `release-as`, US/FR seeded at 0.0.0, root `CHANGELOG.md` shared across all 3 packages
- `.release-please-manifest.json` — version tracking seeded at 0.0.0 for all three regions
- `.github/workflows/release-please.yml` — push-to-main trigger, elevated permissions (`contents: write, pull-requests: write`), checkout with `fetch-depth: 0`, canonical v5.0.0 SHA, outputs declared for Phase 6 consumption
- `CHANGELOG.md` — root changelog seeded with three empty `## nordvpn-{region}` section headers
- `05-CONTEXT.md` — 6-step bootstrap verification checklist, D-09 shared changelog merge risk acknowledged with mitigation steps

## Task Commits

Each task was committed atomically:

1. **Task 1: Create release-please configuration files** - `439ea13` (ci)
2. **Task 2: Create release-please workflow** - `4635629` (ci)
3. **Task 3: Seed root CHANGELOG.md and document bootstrap/post-release procedures** - `066e78b` (docs)

## Files Created/Modified
- `.github/release-please-config.json` — Release-please configuration: 3 packages, simple release-type, separate PRs, changelog sections, ES bootstrap
- `.release-please-manifest.json` — Per-region version tracking seeded at 0.0.0
- `.github/workflows/release-please.yml` — Workflow triggering release-please on push to main with elevated permissions
- `CHANGELOG.md` — Root changelog seeded with three region headers
- `.planning/phases/05-release-please/05-CONTEXT.md` — Appended post-implementation bootstrap procedures

## Decisions Made
All decisions followed the CONTEXT.md locked decisions exactly:
- Changelog sections per D-01/D-02/D-03 (refactor visible, revert hidden, deps visible)
- Bootstrap per D-04/D-05/D-06 (release-as on ES only, US/FR at 0.0.0 seed)
- Root CHANGELOG.md per D-07/D-08 (shared, non-overlapping sections)
- Single job per D-10/D-11 (no Phase 6 placeholder, outputs declared for future wiring)
- No `tag-separator` field (default `-` producing `nordvpn-<region>-vX.Y.Z`)
- `ci(release):` scope for Phase 5 PR to avoid unintended release bumps

## Deviations from Plan

None — plan executed exactly as written. All acceptance criteria met on first pass.

## Issues Encountered

None.

## Known Stubs

None. CHANGELOG.md empty section headers are the intentional seed state — release-please will populate them on first release.

## Threat Flags

None. All threat surface captured in the plan's threat model (T-05-01 through T-05-07). No new endpoints, auth paths, or trust boundaries introduced beyond what was planned.

## Next Phase Readiness
- Phase 6 (floating major tags) can add `update-major-tags` job with `needs: release-please` — outputs (`releases_created`, `paths_released`) are already declared
- Bootstrap removal PR (`chore(release): remove release-as bootstrap for nordvpn-es`) documented for manual follow-up after first ES release
- Shared root CHANGELOG.md merge risk documented with mitigation steps — no blocker, just awareness

## User Setup Required

None — no external service configuration required. Bootstrap verification documented in CONTEXT.md for post-merge manual checks.

---

*Phase: 05-release-please*
*Completed: 2026-05-10*
