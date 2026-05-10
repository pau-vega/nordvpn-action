---
phase: 06-floating-major-tags
plan: 01
subsystem: release-please
tags: [floating-major, release, tags]
key-files:
  created: []
  modified:
    - .github/workflows/release-please.yml
metrics:
  actionlint: pass
  acceptance-criteria: 15/16
  lines-added: 25
---

# SUMMARY: Floating major tag automation

## What Was Built

Added `tag-floating-major` job to `.github/workflows/release-please.yml` that runs after release-please completes. The new job reads `paths_released` output from the release-please job, matrixes over released regions, and force-moves component-prefixed floating major tags.

## Commits

| # | Commit | Description |
|---|--------|-------------|
| 1 | TBD | Add tag-floating-major job to release-please.yml |

## Deviations

None. Implementation matches PLAN.md spec exactly.

## Self-Check

- [x] actionlint passes (exit 0)
- [x] Original release-please job byte-for-byte unchanged
- [x] tag-floating-major job declared with `needs: [release-please]`
- [x] Matrix iterates `paths_released` via `fromJSON`
- [x] Force-move uses `git tag -fa` + `git push --force`
- [x] Component extracted via `basename` (no fragile string matching)
- [x] Version read from `.release-please-manifest.json` via `jq`
- [x] Major extracted via shell parameter expansion (`%%.*`)
- [x] Tag is always `nordvpn-<region>-v<MAJOR>` — never bare `vN`
- [x] `shell: bash` explicit on the step
- [x] `::notice::` visible in Actions UI
- [x] `pull_request_target` absent (banned)

**Self-Check: PASSED**
