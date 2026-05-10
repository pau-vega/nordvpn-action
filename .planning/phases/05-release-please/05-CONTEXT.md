# Phase 5: release-please wiring - Context

**Gathered:** 2026-05-10
**Status:** Ready for planning

<domain>
## Phase Boundary

Phase 5 delivers release-please configuration for a 3-region monorepo — `.github/release-please-manifest.json`, `.github/release-please-config.json`, and `.github/workflows/release-please.yml` — so that a Conventional Commit push to `main` scoped to a single region produces a release PR bumping that region only, independent of other regions.

Covers REL-01..06 (6 requirements). REL-07..08 (floating major tags) are Phase 6. No action code changes. No tag-pushing in this phase.
</domain>

<decisions>
## Implementation Decisions

### Changelog Section Composition

- **D-01:** Changelog section ordering follows Angular convention: `feat` → `fix` → `perf` → `refactor` → `docs` → `deps` (all visible). Hidden sections: `revert` → `chore` → `test` → `ci` → `style`.
- **D-02:** `deps` is visible — Dependabot PRs use `deps:` prefix and deserve a consumer-facing "Dependencies" section.
- **D-03:** `revert` is hidden — revert PRs are infrequent maintenance noise for consumers.

### Bootstrap Strategy

- **D-04:** Use `release-as` field in `.release-please-config.json` to force initial versions per region, preventing auto-bootstrap from commit history.
- **D-05:** After the first release PR for each region merges and creates a tag, the `release-as` field for that region must be removed (follow-up `chore(release): remove release-as bootstrap for nordvpn-<region>`). Planner: implement this as a documented manual step or a CI self-removal check.
- **D-06:** Initial `release-as` versions: planner to propose reasonable starting version per region based on existing commit history scope (e.g., ES has more commits than US/FR). Recommendation: `0.1.0` for nordvpn-es, `0.0.0` for nordvpn-us/nordvpn-fr (no `release-as` needed for 0.0.0 seeds).

### Changelog Output Path

- **D-07:** Single root-level `CHANGELOG.md` (not per-region `actions/nordvpn-{region}/CHANGELOG.md`).
- **D-08:** Each package in `release-please-config.json` needs `"changelog-path": "CHANGELOG.md"` pointing to the root.
- **D-09:** Planner MUST verify that 3 packages writing to the same root `CHANGELOG.md` works correctly with `separate-pull-requests: true`. Each release PR will attempt to modify the same file — release-please's per-package changelog appending should handle section separation, but this needs explicit verification during planning. If conflicting, fall back to per-region changelogs.

### Workflow Structure

- **D-10:** Single job in `release-please.yml` — calls `googleapis/release-please-action`. Minimal Phase 5 deliverable. Phase 6 adds a second job (`update-major-tags`) with `needs: [release-please]`.
- **D-11:** No placeholder job for Phase 6 — keep the workflow clean and let Phase 6 add the second job independently.

### the agent's Discretion

- Exact `.release-please-config.json` JSON structure (schema URL, field ordering, `packages` map keys)
- Exact pinned SHAs from CLAUDE.md Stack chapter (`googleapis/release-please-action@45996ed1...`, `actions/checkout@de0fac2e...`)
- Workflow-level `permissions:` block (escalated to `contents: write, pull-requests: write` for the release job — this is a REL-04 requirement)
- Whether to use `paths:` filter on workflow triggers (recommendation: no path filter — run on every push to main and let Conventional Commit scopes route per-package; matches standard release-please monorepo pattern)
- Exact `release-as` values per region
- Step naming and job naming (`release-please` job, per output contract)
- Whether the Phase 5 PR itself uses a non-region-scoped Conventional Commit to avoid triggering unintended release PRs on first merge (e.g., `ci(release): configure release-please`)
</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Project & Requirements
- `.planning/ROADMAP.md` §"Phase 5: release-please wiring" — Goal + 4 success criteria (goal-backward gate)
- `.planning/REQUIREMENTS.md` §REL-01..06 — 6 requirements with acceptance criteria
- `.planning/PROJECT.md` — Core value, constraints, release contract

### Research Dossier
- `CLAUDE.md` §"Technology Stack" — Pinned SHAs (release-please v5.0.0: `45996ed1f6d02564a971a2fa1b5860e934307cf7`, checkout v6.0.2: `de0fac2e4500dabe0009e67214ff5f5447ce83dd`), `.release-please-config.json` shape, `.release-please-manifest.json` shape, `.github/workflows/release-please.yml` structure, changelog-sections convention, "What NOT to use" anti-patterns
- `.planning/research/PITFALLS.md` §7 (archived release-please URL), §8 (wrong `release-type`), §9 (missing path filters → tag namespace collision), §10 (tag namespace), §26 (conventional commit scope mismatch), §27 (shallow clone breaks changelog)
- `.planning/research/STACK.md` — `release-please-config.json` template shape, `release-type: simple` rationale, `tag-separator` contract, `paths_released` usage (Phase 6 reference)

### Prior Phase Context
- `.planning/phases/01-scaffolding-lint/01-CONTEXT.md` — SHA-pinning contract, Conventional Commits policy, branch protection `main`
- `.planning/phases/03-mirror-us-fr/03-CONTEXT.md` — Three regions exist at `actions/nordvpn-{es,us,fr}/`, each with `action.yml`
- `.planning/phases/04-self-test-ci/04-CONTEXT.md` — Workflow conventions (permissions, concurrency, SHA-pinned `uses:`)

### Existing Workflows (pattern reference)
- `.github/workflows/self-test.yml` — Established workflow pattern to mirror: triggers, `permissions:`, SHA-pinned `uses:`, job naming
- `.github/workflows/actions-lint.yml` — Second workflow pattern reference

### External Docs
- `https://github.com/googleapis/release-please` — `manifest-releaser.md` for monorepo config, config.json schema with defaults
- `https://github.com/googleapis/release-please-action` — Outputs contract (`paths_released`, per-path `--release_created`/`--tag_name`), v5.0.0 API
- `https://raw.githubusercontent.com/googleapis/release-please/main/schemas/config.json` — Authoritative field defaults
- `AGENTS.md` §Release Process — Per-region Conventional Commit scopes, tag format contract
</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `.github/workflows/self-test.yml` — Full workflow structure to mirror: `on: push: branches: [main]`, `permissions: contents: read` (Phase 5 escalates for release job), SHA-pinned `uses:` with `# vX.Y.Z` comments.
- `CLAUDE.md` Stack chapter — Pre-written `.release-please-config.json` shape with 3 package entries, `changelog-sections` array, `release-type: simple` at top level. Planner should extract directly rather than redesigning.

### Established Patterns
- **SHA-pinning:** All `uses:` = 40-char SHA + `# vX.Y.Z`. Release-please workflow uses `googleapis/release-please-action@45996ed1f6d02564a971a2fa1b5860e934307cf7 # v5.0.0` and `actions/checkout@de0fac2e4500dabe0009e67214ff5f5447ce83dd # v6.0.2`.
- **Conventional Commits:** Per-region scopes (`feat(nordvpn-es):`, `fix(nordvpn-us):`, `feat(nordvpn-fr):`). Phase 5 PR itself uses a non-region scope (`ci` or `chore`) to avoid triggering unintended release PRs on merge.
- **Workflow permissions:** Default `contents: read` at workflow level; escalate per-job. Release job needs `contents: write, pull-requests: write` (REL-04).
- **No `pull_request_target`:** Banned everywhere — `release-please.yml` uses `push` trigger only.

### Integration Points
- `release-please.yml` is the **third** workflow in `.github/workflows/` alongside `actions-lint.yml` and `self-test.yml`. All three coexist with consistent conventions.
- `release-please-config.json` and `.release-please-manifest.json` live at repo root (`.github/` prefix). release-please-action looks for them at these paths by default.
- Branch protection on `main`: Phase 1 currently requires `actions-lint` checks; Phase 4 added `self-test` checks. Phase 5 does NOT add release-please as a required check (release-please runs on push to main, not on PR).
- The existing Conventional Commit history on `main` uses per-region scopes — release-please will correctly route commits to the right package via scope matching. No path-based filtering needed.
</code_context>

<specifics>
## Specific Ideas

- Root `CHANGELOG.md` with 3 packages writing to the same file: planner must test this with `separate-pull-requests: true` — each release PR appends to the same file. Verify release-please handles concurrent section ownership correctly (e.g., each region's entries in separate `### nordvpn-{region}` subsections).
- `release-as` bootstrap: the initial config includes `"release-as": "0.1.0"` for `actions/nordvpn-es` (most commits) and omits it for US/FR (already at `0.0.0` seed). After first ES release merges, a follow-up `chore(release): remove release-as bootstrap for nordvpn-es` PR removes the field.
- The Phase 5 commit should use `ci(release): configure release-please` scope — `ci` is hidden in changelog sections, so this infrastructure commit won't generate a release PR for any region.
- No `paths:` filter on workflow trigger — standard release-please monorepo pattern is to run on every push to `main` and let Conventional Commit scopes handle package routing.
</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within Phase 5 scope (release-please wiring).
</deferred>

---

<post_planning>
## Post-Implementation Procedures

### Bootstrap Verification Checklist

After the Phase 5 PR merges to `main`:

1. **Verify release-please runs:** Push any commit to `main` — check Actions tab for `release-please` workflow run. Should complete without error (no release PR expected yet — first qualifying commit triggers first release PR).

2. **Test first release:** Push a `feat(nordvpn-es): bootstrap first release` commit. release-please should open ONE release PR for `nordvpn-es` only (not US or FR). Merge it.

3. **Verify tag:** `git tag -l 'nordvpn-*'` should show `nordvpn-es-v0.1.0` (first release with `release-as: "0.1.0"`).

4. **Verify manifest update:** `jq '.["actions/nordvpn-es"]' .release-please-manifest.json` should show `"0.1.0"` (not `"0.0.0"`).

5. **Remove release-as bootstrap (per D-05):** After first ES release merges, submit a follow-up PR:
   - Commit: `chore(release): remove release-as bootstrap for nordvpn-es`
   - Change: Delete the `"release-as": "0.1.0"` line from `.github/release-please-config.json` (and the trailing comma on the previous line — `"changelog-path": "CHANGELOG.md"` → no comma after it, and add comma after `}`)
   - After merge, ES uses standard release-please bumping from commit history

6. **Verify per-region isolation:** Push a `fix(nordvpn-fr): test isolation` commit. release-please should open a release PR ONLY for `nordvpn-fr`. ES and US versions should not change.

### D-09 Verification: Shared Root CHANGELOG.md

**Risk acknowledged:** Three packages writing to the same root `CHANGELOG.md` with `separate-pull-requests: true`. Each release PR appends entries under `## nordvpn-{region}` sections — these are non-overlapping, so git merges should succeed without conflicts.

**If conflicts occur during bootstrap:**
- Merge the first release PR, then rebase the second onto the updated main
- release-please will regenerate the second PR's changelog on rebase
- This is a one-time bootstrap friction; once all three regions have released at least once, the sections are established and future release PRs only append to known sections

**Alternative (rejected per D-07/D-08):** Per-region changelogs (`actions/nordvpn-es/CHANGELOG.md`) would avoid any merge conflict risk but would scatter changelog entries across three files. User chose root CHANGELOG.md for consumer visibility.

### CI Considerations

- `release-please.yml` is NOT added as a required check on branch protection (Phase 1/4). It runs on push to main, not on PR — it validates the release process, not PR code quality.
- The release-please workflow does not interact with `actions-lint.yml` or `self-test.yml` — all three coexist independently.
- After Phase 6 adds the `update-major-tags` job, the `needs: release-please` dependency ensures floating tags only move after a successful release.

</post_planning>

---

*Phase: 05-release-please*
*Context gathered: 2026-05-10*
