# Roadmap: nordvpn-actions

**Created:** 2026-04-24
**Granularity:** standard
**Phases:** 6
**Coverage:** 52/52 v1 requirements mapped
**Source of truth:** `.planning/REQUIREMENTS.md`

## Core Value

A caller can add one `uses:` line and be certain the next steps run from the declared country, or the job fails fast — no hand-written OpenVPN plumbing, no unverified exit IPs.

## Phases

- [ ] **Phase 1: Scaffolding & Lint** — Public repo skeleton with MIT license, CODEOWNERS, Dependabot, AGENTS.md, and an enforced `actions-lint` gate on `main`.
- [ ] **Phase 2: Port nordvpn-es** — Re-home the working Tutellus `nordvpn-es` composite + sibling `disconnect/` on this repo with input/output contract frozen for v1.
- [ ] **Phase 3: Mirror nordvpn-us + nordvpn-fr** — Duplicate the ES tree for US and FR with region-specific `.ovpn` + hardcoded ISO-2 country guard; no `_shared/` refactor.
- [ ] **Phase 4: Self-test CI** — Matrix E2E workflow across all three regions with fork-safety guard, Preview-environment secret scoping, weekly drift sentinel, and branch protection upgraded to require self-test.
- [ ] **Phase 5: release-please wiring** — Per-region monorepo release automation producing `nordvpn-<region>-vX.Y.Z` tags driven by Conventional Commits.
- [ ] **Phase 6: Floating major tag automation** — Post-release job that force-moves `nordvpn-<region>-v<MAJOR>` to the new SHA for each released region.

## Phase Details

### Phase 1: Scaffolding & Lint

**Goal**: A first-time visitor lands on a public MIT-licensed repo with a clear front door, new PRs touching actions or workflows are automatically validated by `actionlint` + `shellcheck`, and `main` is protected from merges that fail lint.

**Depends on**: Nothing (first phase)

**Requirements**: SCAF-01, SCAF-02, SCAF-03, SCAF-04, SCAF-05, SCAF-06, SCAF-07, LINT-01, LINT-02, LINT-03, LINT-04, LINT-05

**Success Criteria** (what must be TRUE):
  1. A GitHub visitor at the repo root sees a `LICENSE` (MIT), a root `README.md` that lists every shipped action (empty list OK in this phase), and a `README.md` section explaining the three pin forms (SHA, exact tag `nordvpn-<region>-vX.Y.Z`, floating major `nordvpn-<region>-v<MAJOR>`) with when-to-use-each guidance.
  2. A PR that opens with a broken `action.yml` or a shellcheck violation under `actions/*/scripts/` fails the required `actions-lint` check and cannot be merged into `main`; a PR with clean files passes and becomes mergeable.
  3. A PR that introduces `on: pull_request_target` anywhere in `.github/workflows/**` is rejected by a grep-based CI step in the lint workflow (fails with a clear message), blocking the ACE class of attacks on day one.
  4. Dependabot opens PRs for GitHub Actions updates across the root and each future per-region directory (`/`, `/actions/nordvpn-{es,us,fr}`, `/actions/nordvpn-{es,us,fr}/disconnect`) via a single `directories:` list; CODEOWNERS auto-assigns `@pau-vega` to any PR touching `actions/**` via a glob, not per-region literals.
  5. A contributor (human or AI agent) reading `AGENTS.md` can find, without guessing, the rules for Conventional-Commit scopes, the fork-safety posture, the composite `post:`-is-unavailable + sibling `disconnect/` contract, the Ubuntu-only runner constraint, and the service-credentials-only auth requirement.

**Plans:** 4 plans
- [ ] 01-01-foundation-docs-PLAN.md — LICENSE + root README + AGENTS.md (SCAF-01, SCAF-02, SCAF-03, SCAF-06)
- [ ] 01-02-github-config-PLAN.md — .github/CODEOWNERS + .github/dependabot.yml (SCAF-04, SCAF-05)
- [ ] 01-03-lint-workflow-PLAN.md — .github/workflows/actions-lint.yml (3 parallel jobs, incl. pull_request_target grep guard) (LINT-01..05)
- [ ] 01-04-branch-protection-PLAN.md — scripts/setup-branch-protection.sh + dir rename + gh repo create + push + run script (SCAF-07)

### Phase 2: Port nordvpn-es

**Goal**: A caller pinning `pau-vega/nordvpn-actions/actions/nordvpn-es@<sha>` followed by the sibling `/disconnect` step under `if: always()` connects through a NordVPN ES exit node, passes a two-provider geo check on country `ES`, emits six structured outputs + a `$GITHUB_STEP_SUMMARY` diagnostics table, and tears down cleanly with no secret residue on the runner.

**Depends on**: Phase 1

**Requirements**: NVES-01, NVES-02, NVES-03, NVES-04, NVES-05, NVES-06, NVES-07, NVES-08, NVES-09, NVES-10, NVES-11, NVES-12, NVES-13

**Success Criteria** (what must be TRUE):
  1. A consumer workflow on `ubuntu-latest` that calls `uses: pau-vega/nordvpn-actions/actions/nordvpn-es@<sha>` with `NORDVPN_SERVICE_USERNAME` / `NORDVPN_SERVICE_PASSWORD` from a `Preview` environment connects and a subsequent `curl ipinfo.io/country` returns `ES`; both `ipinfo.io` and `ifconfig.co` must agree or the step fails non-zero with a clear error (no silent success on single-provider).
  2. The same workflow can read `steps.<id>.outputs.exit-ip`, `country`, `asn`, `tun0-state`, `default-route`, and `connect-duration-ms` — all six outputs are pre-declared in `action.yml` and populated by the verify step (no dynamic post-release output additions, per GitHub #10529).
  3. A caller that adds the sibling `pau-vega/nordvpn-actions/actions/nordvpn-es/disconnect@<sha>` step with `if: always()` sees openvpn killed, `$RUNNER_TEMP/nordvpn-auth.txt` removed, and no auth file or credential echo left in logs, even when the connect step itself failed mid-run.
  4. A caller running on `macos-latest` or `windows-latest` sees the action fail fast with a clear "Ubuntu runner required" message (not a cryptic `apt-get: command not found`); a caller whose connection drops DNS through the host resolver instead of the VPN tunnel sees the DNS-egress check fail the verify step (no green badge on DNS leak).
  5. The `actions/nordvpn-es/README.md` documents Inputs, Outputs, Usage (including the mandatory `if: always()` disconnect step), Versioning (three pin forms with SHA-first recommendation and an explicit warning that floating-major tags are mutable), Credential Rotation under the `Preview` environment, and Troubleshooting with real error strings (AUTH_FAILED → service credentials, country mismatch, fork PR skip); `@main` is never recommended.

**Plans**: TBD

### Phase 3: Mirror nordvpn-us + nordvpn-fr

**Goal**: Two new regional actions ship with identical input/output contracts to `nordvpn-es`, each routing through the correct exit country and verified by the same two-provider check; the three region trees are byte-for-byte diffable in CI so drift is flagged at PR time.

**Depends on**: Phase 2 (contract is frozen by `nordvpn-es`; US/FR are mirrors)

**Requirements**: NVUS-01, NVUS-02, NVUS-03, NVUS-04, NVUS-05, NVFR-01, NVFR-02, NVFR-03, NVFR-04, NVFR-05

**Success Criteria** (what must be TRUE):
  1. A caller pinning `pau-vega/nordvpn-actions/actions/nordvpn-us@<sha>` + the paired `/disconnect` connects and both geo providers return country `US`; a caller pinning `pau-vega/nordvpn-actions/actions/nordvpn-fr@<sha>` + the paired `/disconnect` connects and both geo providers return country `FR` — neither action will ever succeed with a country code other than its hardcoded target.
  2. `actions/nordvpn-us/` and `actions/nordvpn-fr/` mirror the `nordvpn-es/` tree shape exactly: `action.yml`, `scripts/*.sh`, `vpn/nordvpn-<region>.ovpn`, `README.md`, `disconnect/action.yml`; input names and the six output names match ES byte-for-byte, so a caller can swap `nordvpn-es` for `nordvpn-us` with no other workflow change.
  3. A CI drift-check step diffs `scripts/*.sh` across the three region directories (ignoring the hardcoded country code) and fails a PR that introduces script divergence without also updating the other regions — catching the copy-paste rot that the deliberate no-`_shared/` stance accepts at N=3.
  4. Each region's `README.md` mirrors `nordvpn-es/README.md` structure with correct regional substitutions (action path, country code, example `uses:` line); no per-region README recommends `@main`, and each documents the mutable floating-major tag explicitly.

**Plans**: TBD

### Phase 4: Self-test CI

**Goal**: Every push to `main` and every non-fork PR runs all three regional actions end-to-end in a matrix using local `./actions/...` references, forks skip cleanly with a clear notice, a weekly scheduled run acts as a drift sentinel that opens a `region-drift` issue on failure, and `main` is now protected behind both `actions-lint` and the three `self-test` matrix jobs.

**Depends on**: Phase 3 (matrix needs all three regions present; running self-test with a partial matrix would defer half the requirements)

**Requirements**: TEST-01, TEST-02, TEST-03, TEST-04, TEST-05, TEST-06, TEST-07, TEST-08, TEST-09

**Success Criteria** (what must be TRUE):
  1. A push to `main` triggers `self-test.yml` which runs three matrix jobs (`nordvpn-es`, `nordvpn-us`, `nordvpn-fr`) in parallel with `fail-fast: false`; each job uses `uses: ./actions/nordvpn-${{ matrix.region }}` (local path, not tag), reads `NORDVPN_SERVICE_USERNAME` / `NORDVPN_SERVICE_PASSWORD` from `environment: Preview`, and runs the paired disconnect step with `if: always()`.
  2. A PR opened from a fork sees the matrix jobs skipped by the fork-skip guard with a `::notice::` explaining the Preview-environment fork-safety posture; no Preview-scoped secret is ever exposed to fork-contributor code, and `pull_request_target` is absent from this workflow (and blocked repo-wide by the Phase 1 CI grep).
  3. Two concurrent runs on the same region + ref do not fight for the same NordVPN session: the `concurrency:` group is keyed by `region + ref` with `cancel-in-progress: false`, so overlapping pushes queue rather than interrupt a live VPN session mid-verify.
  4. The weekly scheduled cron run surfaces silent drift: if any region fails (for example, because NordVPN decommissioned a server pinned in a `.ovpn`), the workflow opens a GitHub issue labeled `region-drift` so the maintainer is alerted before a consumer files the bug.
  5. After this phase ships, branch protection on `main` requires both `actions-lint` and the three `self-test` matrix jobs before merge; a PR that breaks VPN egress on any one region cannot be merged even if the other two pass.

**Plans**: TBD

### Phase 5: release-please wiring

**Goal**: A Conventional-Commit push to `main` scoped to a single region produces a single release-please PR bumping that region only; merging it publishes a `nordvpn-<region>-vX.Y.Z` git tag and a region-scoped `CHANGELOG.md` entry, leaving the other two regions' versions untouched.

**Depends on**: Phase 3 (all three regions must exist for per-region path scoping to be validated end-to-end)

**Requirements**: REL-01, REL-02, REL-03, REL-04, REL-05, REL-06

**Success Criteria** (what must be TRUE):
  1. A `feat(nordvpn-fr): add ca2 server` commit merged to `main` results in release-please opening a PR that bumps `actions/nordvpn-fr` only; `actions/nordvpn-es` and `actions/nordvpn-us` versions, changelogs, and tags are unchanged (per-region path scoping + `separate-pull-requests: true`).
  2. Merging the release-please PR for `nordvpn-fr` produces a git tag of the form `nordvpn-fr-v0.1.0` (or the correct pre-major bump); no bare `v0.1.0` tag is created, and the tag separator is `-` (never `@`).
  3. The resulting `actions/nordvpn-fr/CHANGELOG.md` entry lists `feat`, `fix`, `docs`, `refactor`, `perf` commits visibly and hides `chore`, `test`, `ci`, `style` — matching the `changelog-sections` contract so consumers see only meaningful changes.
  4. The `release-please.yml` workflow uses the canonical `googleapis/release-please-action@<pinned-sha>` (v5.0.0, not the archived `google-github-actions/` predecessor), runs on push to `main` with `permissions: contents: write, pull-requests: write`, and checks out with `fetch-depth: 0` so the full commit history is visible.

**Plans**: TBD

### Phase 6: Floating major tag automation

**Goal**: After any regional release publishes, the matching `nordvpn-<region>-v<MAJOR>` tag is force-moved to the new release SHA, so consumers pinning the floating major get the latest patch/minor for that region on their next workflow run — without bare `v<MAJOR>` tags ever being produced.

**Depends on**: Phase 5 (needs a proven release-please run whose per-component outputs this job reads; must run strictly after release-please, never concurrently)

**Requirements**: REL-07, REL-08

**Success Criteria** (what must be TRUE):
  1. After release-please merges a release for `nordvpn-es` (tag `nordvpn-es-v1.2.0`), the `tag-floating-major` job reads the per-component output `outputs['actions/nordvpn-es--major']` (never substring-matches `paths_released`), matrixes over released regions, and force-moves the `nordvpn-es-v1` git tag to the same SHA via `git tag -fa` + `git push --force`; a caller pinning `@nordvpn-es-v1` gets the new code on their next workflow run.
  2. When release-please produces no release for a region (no qualifying commits since last release), the `tag-floating-major` job for that region is skipped cleanly — no stale tag is moved, and no bare `v1` tag is ever created for any region (component-prefixed tags only, because bare major tags collide across three regions in a monorepo).

**Plans**: TBD

## Progress

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. Scaffolding & Lint | 0/? | Not started | - |
| 2. Port nordvpn-es | 0/? | Not started | - |
| 3. Mirror nordvpn-us + nordvpn-fr | 0/? | Not started | - |
| 4. Self-test CI | 0/? | Not started | - |
| 5. release-please wiring | 0/? | Not started | - |
| 6. Floating major tag automation | 0/? | Not started | - |

## Coverage Validation

All 52 v1 requirements are mapped to exactly one phase (the REQUIREMENTS.md header still read "49 total" from an early draft — corrected below; the authoritative count is the traceability table in REQUIREMENTS.md).

| Category | Count | Phase | Requirements |
|----------|-------|-------|--------------|
| Repository Scaffolding (SCAF) | 7 | 1 | SCAF-01..07 |
| Linting CI (LINT) | 5 | 1 | LINT-01..05 |
| NordVPN Spain Action (NVES) | 13 | 2 | NVES-01..13 |
| NordVPN US Action (NVUS) | 5 | 3 | NVUS-01..05 |
| NordVPN France Action (NVFR) | 5 | 3 | NVFR-01..05 |
| Release & Versioning (REL) | 8 | 5 (REL-01..06) + 6 (REL-07..08) | REL-01..08 |
| Self-Test CI (TEST) | 9 | 4 | TEST-01..09 |
| **Total** | **52** | | |

Coverage: **52 / 52 (100%)** — no orphans, no duplicates.

## Design Notes

### Why six phases (not fewer, not more)

- **Phase 1 bundles SCAF + LINT** because SCAF-07 (branch protection requiring `actions-lint`) is a direct consumer of LINT-01..05 — they ship together or not at all. Splitting them would produce a phase that's "scaffolding without a way to enforce it" and a second phase that's "lint that protects nothing yet."
- **Phase 2 is a whole phase for one region** because the input/output contract is frozen for v1 by this phase. Every drift-prevention pitfall (DNS leak, `$GITHUB_ACTION_PATH`, auth-file mode, `--daemon` race, two-provider geo, DNS-egress check, sibling-`disconnect/` contract) lands here and gets mirrored mechanically in Phase 3. A shallower Phase 2 produces contract rot in Phases 3 and 4.
- **Phase 3 is copy + diff, not refactor.** The `_shared/scripts/` temptation is explicitly rejected at N=3 — the CI drift-check catches divergence for cheaper than the release-please scoping complications a shared dir introduces. Revisit at N=5+.
- **Phase 4 lands self-test for all three regions at once** rather than splitting it (ES-only first, then expand in Phase 3's tail) — the matrix is one file; landing ES-only then expanding doubles the review surface for no customer benefit. Trade-off accepted: TEST-03 (matrix over all three) couldn't ship until Phase 3 finished; we accept slightly later self-test for a cleaner phase boundary.
- **Phases 5 and 6 are separate** because REL-07..08 (floating major) can only be designed and tested once REL-01..06 (release-please) is proven green. Attempting both in one phase risks the tag-automation job reading outputs that don't yet exist in the real world, producing a workflow that "looks right" but has never executed end-to-end.

### What's deferred (for the Plan-Phase agent's awareness)

- `AUTO-01` (Conventional-commits CI grep): explicitly v2 per REQUIREMENTS.md. Social enforcement via PR review in v1.
- `_shared/scripts/` abstraction: explicitly out-of-scope until N=5+ regions. CI drift-check in Phase 3 is the accepted cost at N=3.
- Marketplace listing: v2 (DIST-01..03).
- Additional regions (DE/UK/IT/generic): v2 (REG-01..04).

### Position on research-synthesizer open questions

Baked into the requirements and this phase structure (per `<positions_on_research_open_questions>` in the planning brief):

1. Self-test is **P1** → Phase 4.
2. Branch protection is **staged**: Phase 1 requires `actions-lint` only (SCAF-07); Phase 4 upgrades it to also require `self-test` (TEST-09).
3. Conventional commits: **social enforcement** for v1; no CI grep, no commitlint (AGENTS.md documents the scope rules in Phase 1).
4. Structured diagnostics outputs land in **Phase 2** (NVES-02, NVES-08). All six outputs pre-declared day one — no v1.1 coordinated minor bump across three regions.
5. Weekly scheduled self-test (drift sentinel) is **P1** → Phase 4 (TEST-01 includes `schedule`, TEST-08 defines the `region-drift` issue behavior).
