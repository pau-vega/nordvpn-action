---
gsd_state_version: 1.0
milestone: v0.1.0
milestone_name: milestone
status: Phase 05 Complete
last_updated: "2026-05-10T00:00:00.000Z"
progress:
  total_phases: 6
  completed_phases: 2
  total_plans: 9
  completed_plans: 7
  percent: 33
---

# State: nordvpn-actions

**Initialized:** 2026-04-24
**Session continuity file.** Updated at every phase transition, plan completion, and major checkpoint.

## Project Reference

**Core Value:** A caller can add one `uses:` line and be certain the next steps run from the declared country, or the job fails fast — no hand-written OpenVPN plumbing, no unverified exit IPs.

**Current Focus:** Phase 05 — release-please wiring (complete) → Phase 06 next

## Current Position

Phase: 05 (release-please) — Complete
| Field | Value |
|-------|-------|
| Milestone | v1 |
| Phase | 5 — release-please wiring (Complete) |
| Plan | 05-01 complete — release-please config/workflow/CHANGELOG shipped |
| Status | Complete |
| Progress | `[###       ] 2/6 phases complete` |

## Performance Metrics

| Metric | Value |
|--------|-------|
| Phases total (v1) | 6 |
| Phases complete | 2 |
| v1 requirements total | 52 |
| v1 requirements complete | 6 (REL-01..06) |
| Plans total | 9 (4 Phase1 + 3 Phase2 + 2 Phase3 + 1 Phase4 + 1 Phase5) |
| Plans complete | 7 (3 Phase2 + 2 Phase3 + 1 Phase4 + 1 Phase5) |

## Accumulated Context

### Decisions Made (during initialization)

- **Monorepo layout.** `actions/nordvpn-<region>/` + root-level docs and workflows; single release pipeline; matches the Tutellus source PR shape and the google-github-actions precedent.
- **release-please for versioning.** Per-region components with `release-type: simple`, `include-component-in-tag: true`, `separate-pull-requests: true`. Canonical `googleapis/release-please-action` only — never the archived `google-github-actions/` predecessor.
- **Three pin forms; SHA is default recommendation.** Every action README teaches SHA > exact tag > floating major; `@main` is never recommended.
- **Self-test is P1, not deferred.** Shipping three regions without an E2E check invites the first `.ovpn` drift event to surface as a consumer issue.
- **Conventional-commits enforcement is social for v1.** No commitlint/husky (Node toolchain tax on a pure-Bash repo). CI grep check is v2 (AUTO-01).
- **No `_shared/scripts/` at N=3.** Duplicate + CI drift-check is cheaper than the release-please scoping complications a shared dir introduces. Revisit at N=5+.
- **Phase structure: 6 phases, derived from requirement categories with constraints on ordering.** Lint before code (Phase 1 first), ES establishes contract (Phase 2), US/FR mirror (Phase 3), self-test needs all three regions (Phase 4), release-please needs three real dirs (Phase 5), floating-major runs after release-please proven (Phase 6).

### Decisions Made (Phase 2 context session)

- **Porting approach:** Straight copy from Tutellus PR #159, rewrite README for pau-vega/nordvpn-actions, update all repo references
- **Script organization:** Keep 4 separate scripts, keep chaos injection vars, keep source PR patterns (shebang, set -e, sudo, relative paths)
- **Diagnostics table:** Markdown table format for $GITHUB_STEP_SUMMARY with all 6 outputs
- **Error messages:** Keep all source PR error messages as-is (Ubuntu guard, tun0 timeout, country mismatch, DNS-egress, NordVPN API failure, missing tools)
- **Retry loop:** Keep in action.yml (not scripts), 2 attempts, 5s sleep between retries, cleanup via disconnect.sh

### Decisions Made (Phase 5 context session)

- **Changelog sections:** Angular order (feat→fix→perf→refactor→docs→deps visible; revert→chore→test→ci→style hidden). deps visible for Dependabot PR visibility.
- **Bootstrap strategy:** Use `release-as` field to force initial versions. nordvpn-es starts at 0.1.0; US/FR stay at 0.0.0 seed. Remove `release-as` after first release.
- **Changelog path:** Root-level `CHANGELOG.md` — planner must verify compatibility with `separate-pull-requests: true`.
- **Workflow structure:** Single job (release-please). Phase 6 adds second job independently. No placeholder needed.
- **Commit scope:** Phase 5 PR uses `ci(release):` scope — non-region, won't trigger unintended release PRs.
- **Workflow trigger:** No `paths:` filter — run on every push to main, rely on Conventional Commit scopes for routing.

### Decisions Made (Phase 5 execution session)

- **Changelog sections executed:** feat/fix/perf/refactor/docs/deps visible; revert/chore/test/ci/style/build hidden (D-01/D-02/D-03 implemented exactly)
- **Bootstrap executed:** release-as: 0.1.0 on ES only, US/FR at 0.0.0 seed (D-04/D-05/D-06)
- **Root CHANGELOG.md with all 3 packages pointing to it (D-07/D-08/D-09)**
- **Single workflow job with outputs (releases_created, paths_released) for Phase 6 consumption**
- **Workflow permissions: contents: write + pull-requests: write (REL-04)**
- **Checkout with fetch-depth: 0 for full git history (REL-05)**
- **SHA-pinned uses: lines with # vX.Y.Z comment (googleapis/release-please-action@45996..., actions/checkout@de0fac2e...)**
- **Default '-' tag-separator (no tag-separator field) producing nordvpn-<region>-vX.Y.Z**

### Decisions Made (Phase 4 context session)

- **Branch protection check naming:** Use standard GitHub matrix naming — `self-test (nordvpn-es)`, `self-test (nordvpn-us)`, `self-test (nordvpn-fr)`. Inline into `setup-branch-protection.sh`.
- **Triggers:** push (main) + pull_request + schedule (Mon 08:00 UTC) + workflow_dispatch. All path-filtered `actions/**, .github/workflows/**`. Workflow_dispatch has region selector input.
- **Drift issues:** One issue per schedule run, upsert pattern (update existing or create new), auto-close on recovery, `gh` CLI tooling.
- **Post-connect verification:** Workflow-level curl geo-check (ipinfo.io only) + assert all 6 action outputs non-empty.

### Decisions Made (Phase 4 execution session)

- **Workflow-level concurrency with matrix.region unavailable:** Removed from workflow scope; per-job concurrency in the matrix job handles per-region queuing correctly.
- **actionlint false positive suppression:** Added `.github/actionlint.yaml` to suppress v1.7.12 false positive for `${{ matrix.* }}` in `uses:` lines. Required for CI to pass.
- **Branch protection:** 6 required checks inline in REQUIRED_CHECKS_JSON (3 lint + 3 self-test). Phase 4 amendment hint removed from script.

### Open TODOs (for Plan-Phase agent)

- Phase 1 plan decomposition: expect plans for (a) LICENSE + root README + AGENTS.md, (b) CODEOWNERS + Dependabot, (c) `actions-lint` workflow + the `pull_request_target` grep guard, (d) branch protection enablement requiring `actions-lint`.
- Phase 2 PLAN.md files created: 02-01 (core action files), 02-02 (disconnect sub-action), 02-03 (README documentation). All 13 NVES requirements covered.

### Known Blockers

- None at initialization.

### Not Blocking But Worth Noting

- Directory is named `nordvpn-action` (singular) locally; the GitHub repo will be named `nordvpn-actions` (plural). Local rename deferred; inconsequential for git history.
- REQUIREMENTS.md header read "49 total" in its early draft; the authoritative count from the traceability table is **52**. Corrected in this roadmap's coverage section.

## Session Continuity

### Last Session Summary (2026-04-24, initialization)

- Wrote `.planning/PROJECT.md` (core value, constraints, key decisions, out-of-scope with rationale).
- Ran research phase (STACK.md, FEATURES.md, ARCHITECTURE.md, PITFALLS.md, SUMMARY.md — all HIGH confidence).
- Wrote `.planning/REQUIREMENTS.md` (52 v1 requirements across 7 categories: SCAF, LINT, NVES, NVUS, NVFR, REL, TEST; v2 deferrals for DIST, REG, AUTO; explicit out-of-scope with rationale).
- Wrote this roadmap: 6 phases, 100% requirement coverage, goal-backward success criteria (2–5 observable behaviors per phase).

### Next Session Start

Phase 06 (floating major tag automation) ready for planning. Run `/gsd-plan-phase 6`.

---

*Last updated: 2026-05-10 after Phase 5 execution*
