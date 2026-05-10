# Phase 5: release-please wiring - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-05-10
**Phase:** 05-release-please
**Areas discussed:** Changelog section composition, Bootstrap strategy, Changelog output path, Workflow structure / Phase 6 compatibility

---

## Changelog Section Composition

| Option | Description | Selected |
|--------|-------------|----------|
| Angular order + deps visible, revert hidden | Standard: feat→fix→perf→refactor→docs→deps (visible); revert→chore→test→ci→style (hidden). Dependabot PRs get a visible 'Dependencies' section. | ✓ |
| Minimal: stick to REL-03 only | feat→fix→perf→docs→refactor (visible); deps→chore→test→ci→style→revert (hidden). deps PRs lump into hidden 'chore'. | |
| Full Angular: deps + revert visible | feat→fix→perf→revert→refactor→docs→deps (visible); chore→test→ci→style (hidden). Most informative for consumers. | |

**User's choice:** Angular order + deps visible, revert hidden
**Notes:** REL-03 specified visible={feat,fix,docs,refactor,perf} and hidden={chore,test,ci,style} but omitted `deps` and `revert`. User chose to make `deps` visible (Dependabot PRs merit a consumer-facing section) and `revert` hidden (maintenance noise).

---

## Bootstrap Strategy

| Option | Description | Selected |
|--------|-------------|----------|
| Auto-bootstrap from history | Let release-please compute bumps from all existing Conventional Commits on main. First release PRs will bump each region based on the full commit history. | |
| Seed manifest to skip history | Set manifest versions to match what we consider the current version (e.g. 0.1.0 for ES, 0.0.0 for US/FR) so release-please only looks at commits after the bootstrap. | |
| Use release-as to force initial | Add 'release-as' field in config for first run (e.g. '0.1.0' for nordvpn-es) to force the initial version regardless of history. Clean, explicit, but requires a second commit to remove the field after. | ✓ |

**User's choice:** Use release-as to force initial
**Notes:** Config will include `release-as` field for nordvpn-es (most commit history) to start at a controlled version. US/FR stay at `0.0.0` seed. After first release PR merges, the `release-as` field must be removed via follow-up commit.

---

## Changelog Output Path

| Option | Description | Selected |
|--------|-------------|----------|
| Per-region: actions/nordvpn-{region}/CHANGELOG.md | One changelog per region alongside its action code. Consumers can read region-specific release notes without navigating the full repo. Default release-please behavior for 'simple' release-type. | |
| Root-level: CHANGELOG.md at repo root | Single changelog at repo root with sections per region. release-please would need 'changelog-path' overrides. Simpler overview, but mixes unrelated region changes. | ✓ |

**User's choice:** Root-level CHANGELOG.md
**Notes:** Each package in config needs `"changelog-path": "CHANGELOG.md"`. Planner must verify this works with `separate-pull-requests: true` — 3 packages writing to the same root file may cause merge conflicts. If conflicting, fall back to per-region changelogs.

---

## Workflow Structure / Phase 6 Compatibility

| Option | Description | Selected |
|--------|-------------|----------|
| Minimal — single release job | One job in release-please.yml that calls release-please-action. Phase 6 adds a second job with 'needs:' dependency. Clean, minimal Phase 5 deliverable. | ✓ |
| Forward-compatible — job separation | Structure with two jobs now (release-please + a no-op placeholder for floating tags). Phase 6 fills in the placeholder. More upfront work, trivial Phase 6 addition. | |

**User's choice:** Minimal — single release job
**Notes:** Single job calling release-please-action. Phase 6 independently adds `update-major-tags` job with `needs: [release-please]`. No placeholder needed — clean separation.

---

## the agent's Discretion

- Exact `.release-please-config.json` JSON structure (schema URL, field ordering, `packages` map keys)
- Exact pinned SHAs from CLAUDE.md Stack chapter
- Workflow-level `permissions:` block structure
- Whether to use `paths:` filter on workflow triggers (recommended: no)
- Exact `release-as` values per region
- Step naming and job naming

## Deferred Ideas

None — discussion stayed within Phase 5 scope.
