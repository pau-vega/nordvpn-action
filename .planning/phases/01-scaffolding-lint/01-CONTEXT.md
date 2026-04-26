# Phase 1: Scaffolding & Lint - Context

**Gathered:** 2026-04-26
**Status:** Ready for planning

<domain>
## Phase Boundary

Public repo skeleton + enforced lint gate on `main`. Specifically:

1. Repo-front-door artifacts: `LICENSE` (MIT), root `README.md` (with three-pin-form chapter), `.github/CODEOWNERS`, `.github/dependabot.yml`, `AGENTS.md`.
2. `.github/workflows/actions-lint.yml`: parallel jobs for `actionlint`, `shellcheck`, and a `pull_request_target` grep guard.
3. Branch protection on `main` requiring all three lint jobs, enabled via a committed `gh` CLI script.

Phase delivers SCAF-01..07 and LINT-01..05 (12 requirements). No regional action code. No release tooling. No self-test.

</domain>

<decisions>
## Implementation Decisions

### Repo Bootstrap & Sequencing

- **D-01:** Local working directory rename — rename `nordvpn-action` (singular) → `nordvpn-actions` (plural) before first push to GitHub. Rename is the LAST execution step of Phase 1 (just before remote create + push), so it does not invalidate the active session's working directory mid-execution.
- **D-02:** GitHub remote creation deferred until end of Phase 1. All Phase 1 artifacts land locally first; then create `pau-vega/nordvpn-actions` (public, MIT) and push. Single push event seeds the public repo with the full Phase 1 scaffold.
- **D-03:** Commit shape: one commit per plan, ~4 commits total. Maps to STATE-suggested decomposition: (a) `LICENSE` + root `README.md` + `AGENTS.md`, (b) `.github/CODEOWNERS` + `.github/dependabot.yml`, (c) `.github/workflows/actions-lint.yml` + `pull_request_target` grep guard, (d) branch-protection setup script + enablement. Conventional Commits required from commit #1 (release-please scoping in Phase 5 depends on clean history).
- **D-04:** Phase 1 commits go directly to `main` (solo repo, no actions-lint gate exists yet during Phase 1 itself). The branch-protection commit is the last direct push of Phase 1; from Phase 2 onward, all changes route through PRs gated by `actions-lint`.

### Documentation Depth

- **D-05:** Root `README.md` ships rich content from start: full three-pin-form chapter (SHA / exact tag / floating major) with when-to-use guidance, mutability warning on floating-major tags, copy-paste workflow examples, and an "Available actions" table with placeholder rows (e.g., "`nordvpn-es` — ships in v1.0.0 (Phase 2)"). Satisfies SCAF-02 + SCAF-03 in full this phase, no later "polish" pass needed.
- **D-06:** No CI / OpenSSF / Used-by badges in root README during Phase 1. License badge OK (static). CI status badges ship in Phase 4 (when self-test exists). Release/version badges ship in Phase 5. Avoids "broken-badge" UX while workflows / releases don't yet exist.
- **D-07:** `AGENTS.md` is forward-loaded — covers the full canonical section list from CLAUDE.md tech stack chapter (Project Overview, Development Environment, Build/Test Commands, Code Style, Testing Instructions, Release Process, Security Considerations, PR Guidelines, For AI Agents, Installation, Alternatives Considered). Build/test command sections stub the Phase 1 commands (`actionlint .`, `shellcheck actions/**/scripts/*.sh`); Phase 2/3 amend with real script commands as scripts ship.
- **D-08:** `AGENTS.md` prose style: terse instruction list (short imperative bullets, code blocks for commands, minimal narrative). Optimized for AI-agent skim; matches the agents.md convention used by 60k+ repos. No "why" paragraphs in v1.

### `pull_request_target` Grep Guard (LINT-05)

- **D-09:** Guard implemented as a third parallel job in `.github/workflows/actions-lint.yml` (alongside `actionlint` and `shellcheck`). Job name: `block-pull-request-target` (or similar — planner finalizes). One workflow file, three jobs, three required checks.
- **D-10:** Regex is YAML-aware, not literal substring. Match `pull_request_target` only when it appears as a workflow trigger (e.g., on its own indented line under `on:`, or as a key like `pull_request_target:`). Comments and incidental string mentions in fixtures or future docs do not trip the guard. Suggested pattern (planner refines): `^\s*pull_request_target\s*:` plus `^on:.*pull_request_target` multiline match — both expressed via `grep -E` or a small awk/python helper as the planner prefers.
- **D-11:** Guard scans `.github/workflows/**` only. Composite `action.yml` files cannot legally define triggers, so scanning them would be theatre. Tight signal/noise.
- **D-12:** Failure mode: hard `exit 1` with explicit error message pointing the contributor to `AGENTS.md §Security Considerations` and the rationale in `.planning/research/PITFALLS.md §2`. Required check on `main` — PR cannot merge while the guard fails.

### Branch Protection on `main` (SCAF-07)

- **D-13:** Enablement method: a committed `gh api` script (path TBD by planner — likely `scripts/setup-branch-protection.sh` or `.github/setup/branch-protection.sh`). Script is idempotent, documented in `AGENTS.md §Release Process`, and re-runnable if the repo is recreated or settings drift. Maintainer runs it once after the first push.
- **D-14:** Required status checks: the three job names produced by `actions-lint.yml` (the `actionlint` job, the `shellcheck` job, the `block-pull-request-target` job). Job-level required checks, not workflow-level (GitHub deprecated the workflow-level form in favor of granular job-level entries). Phase 4 amends the script to add the three `self-test` matrix jobs (TEST-09).
- **D-15:** Additional protections enabled alongside required checks: "Require a pull request before merging" with 0 required approvals (solo repo), "Require status checks to pass before merging", and "Require branches to be up to date before merging". NOT enabled: required reviewers (no second human), linear history (release-please squash merges may not always be linear), required signed commits (extra ceremony with no proportional return for SHA-pinned action repo's threat model), restrict-who-can-push (would lock the maintainer out).
- **D-16:** Admins do NOT bypass branch protection — `enforce_admins: true` (or the GitHub Rulesets equivalent). Maintainer goes through the same PR gate from Phase 2 onward. Matches OpenSSF Scorecard `branch-protection` check expectations and dogfoods the contract.

### Plan Decomposition (carry-forward to /gsd-plan-phase 1)

- **D-17:** Expect ~4 plans matching D-03's commit shape:
  - **Plan 1 (Foundation Docs):** `LICENSE`, root `README.md`, `AGENTS.md` — covers SCAF-01, SCAF-02, SCAF-03, SCAF-06.
  - **Plan 2 (GitHub Config):** `.github/CODEOWNERS`, `.github/dependabot.yml` — covers SCAF-04, SCAF-05.
  - **Plan 3 (Lint Workflow):** `.github/workflows/actions-lint.yml` (3 parallel jobs incl. grep guard) — covers LINT-01..05.
  - **Plan 4 (Branch Protection):** committed `gh` CLI script + dir rename + first push + manual `gh repo create` + script execution — covers SCAF-07.
- **D-18:** Plan 4 is also the phase-end choreography step (rename, push, create remote). Planner sequences the rename to occur AFTER all artifacts are committed locally and BEFORE the `gh repo create` + `git push -u origin main` so the directory name on first GitHub fetch matches the final repo name.

### Claude's Discretion

- Exact regex/awk syntax for the `pull_request_target` grep guard (planner picks based on portability + readability — must satisfy D-10 semantics).
- Path for the branch-protection script (`scripts/`, `.github/setup/`, or other) — planner picks based on which is most discoverable from `AGENTS.md`.
- Wording/structure of the README "Available actions" placeholder table — must satisfy SCAF-02 (links to per-action READMEs even before they exist, or notes "coming in vX.Y.Z").
- Concrete copy in each `AGENTS.md` section — must cover the canonical section list (D-07) and the 5 SCAF-06 mandatory topics, but exact phrasing is Claude's discretion.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Project & requirements
- `.planning/PROJECT.md` — Core value, constraints, key decisions, out-of-scope rationale.
- `.planning/REQUIREMENTS.md` — SCAF-01..07 + LINT-01..05 acceptance criteria for Phase 1.
- `.planning/ROADMAP.md` §"Phase 1: Scaffolding & Lint" — Goal + 5 success criteria (goal-backward gate).

### Tech stack chapter (in repo-root CLAUDE.md)
- `CLAUDE.md` §"Technology Stack" — Pinned SHAs (release-please v5.0.0, actionlint v1.72.0, shellcheck 2.0.0, checkout v6.0.2), `release-please-config.json` shape, dependabot `directories:` list, lint workflow shape (parallel jobs + SHELLCHECK_OPTS exclusions), CODEOWNERS pattern, fork-safety contract, AGENTS.md section list, "What NOT to use" anti-patterns.

### Research dossier
- `.planning/research/SUMMARY.md` — Cross-cutting research summary.
- `.planning/research/STACK.md` — Tooling rationale + version choices.
- `.planning/research/ARCHITECTURE.md` — Repo layout + workflow shape.
- `.planning/research/PITFALLS.md` §2 (`pull_request_target` ACE) — Backs LINT-05 grep guard rationale; cite from D-12 error message.
- `.planning/research/PITFALLS.md` (entries on monorepo release plumbing, fork-safety) — Phase 4/5/6 prep but informs AGENTS.md security section now.

### External docs (informational)
- `https://agents.md` — AGENTS.md format steward; section conventions.
- `https://github.com/googleapis/release-please-action` — Phase 5 reference (read in Phase 5; not required for Phase 1 implementation).
- `https://github.com/rhysd/actionlint/blob/main/docs/checks.md` — Confirms actionlint does NOT lint composite `action.yml` metadata (gap accepted; informs Plan 3 scoping).
- `https://docs.github.com/en/code-security/reference/supply-chain-security/dependabot-options-reference` — `directories:` (plural) syntax for SCAF-05.
- `https://docs.github.com/en/repositories/managing-your-repositorys-settings-and-features/customizing-your-repository/about-code-owners` — Glob semantics for SCAF-04.
- `https://docs.github.com/en/rest/branches/branch-protection` — `gh api` shape for D-13 script.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- None. Repo is empty (only `.git/`, `.planning/`, `.claude/`, `CLAUDE.md`). Phase 1 lays the foundation; subsequent phases reuse the artifacts created here.

### Established Patterns
- **Pin posture** (CLAUDE.md): Every action reference inside this repo's own workflows MUST use `<40-char-SHA> # vX.Y.Z` form. Phase 1's `actions-lint.yml` is the first place this contract is exercised.
- **Conventional Commits** (CLAUDE.md + STATE.md): Per-region scope (`feat(nordvpn-es):`, `fix(nordvpn-us):`, etc.) enforced socially. Phase 1 commits use scope `scaf` / `lint` / `chore` / `docs` (no per-region scope yet — no regions exist).
- **`AGENTS.md`-as-canonical-contributor-doc** (PROJECT.md): Single root file, no schema, sections per the agents.md convention. CLAUDE.md remains the AI-orientation file; AGENTS.md is the human + agent contributor guide.

### Integration Points
- `.github/workflows/actions-lint.yml` is the entry point for every subsequent phase's PR gate. Phase 4 adds a sibling `self-test.yml`; Phase 5 adds `release-please.yml`. All three workflows must coexist with `permissions: contents: read` at workflow level (escalated per-job where needed).
- `.github/CODEOWNERS` glob `/actions/** @pau-vega` auto-covers every future region directory without per-region edits — Phases 2 and 3 add region trees with zero CODEOWNERS change required.
- `.github/dependabot.yml` `directories:` plural list enumerates all current and Phase 2/3-future paths (`/`, `/actions/nordvpn-{es,us,fr}`, each `/disconnect`). Plan 2's dependabot.yml ships with the FULL list, not just `/` — preempts the SCAF-05 acceptance check before the regions exist.
- Branch-protection script (Plan 4) lists three required checks now; Phase 4 amends the same script to add three `self-test` matrix jobs (TEST-09). Script idempotency matters.

</code_context>

<specifics>
## Specific Ideas

- The `pull_request_target` grep-guard error message should explicitly cite `PITFALLS.md §2` as the rationale source, plus a one-line summary ("`pull_request_target` runs the workflow from base ref with full secrets access; combined with checkout of PR head SHA = arbitrary code execution"). This educates future contributors on WHY without making them grep the research dossier.
- AGENTS.md `§For AI Agents` section should call out that this repo bans `pull_request_target` everywhere, not just in workflows. Pre-emptive guidance saves a future Claude/Codex session from suggesting it as "the simple fix" for a fork-PR self-test gap.
- Root README "Available actions" placeholder table should list all three regions with status column ("`nordvpn-es` — ships in Phase 2 / v1.0.0", etc.) so the table structure is set; Phase 2/3 just flips the status entries to "Available" + adds the `uses:` example column. Saves a structural rewrite later.

</specifics>

<deferred>
## Deferred Ideas

- **Conventional-commits CI grep check** — REQUIREMENTS.md AUTO-01, v2 milestone. Social enforcement during v1; CI grep adds a Bash regex check post-v1.
- **OpenSSF Scorecard badge + workflow** — Could be added in a polish phase before v1.0.0 release. Phase 1 ships the artifacts (SHA pinning, branch protection, fork-safety) that earn a high Scorecard score; the badge itself is cosmetic and depends on a separate workflow not currently scoped.
- **`commitlint` / husky hooks** — Out of scope for v1 (PROJECT.md Out of Scope row). Pure-Bash repo doesn't justify a Node toolchain.
- **PR templates** (`.github/PULL_REQUEST_TEMPLATE.md`) — Not required by any SCAF requirement; could land in Plan 2 alongside CODEOWNERS but adds writing surface. Skipping for v1; revisit if PR quality drifts.
- **Issue templates** (`.github/ISSUE_TEMPLATE/*.yml`) — Same rationale as PR template; defer until first external user files an issue.
- **Auto-generated `action.yml` → README inputs/outputs sections** — REQUIREMENTS.md AUTO-03, v2.

</deferred>

---

*Phase: 01-scaffolding-lint*
*Context gathered: 2026-04-26*
