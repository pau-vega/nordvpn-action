---
phase: 01-scaffolding-lint
plan: 02
type: execute
wave: 1
depends_on: []
files_modified:
  - .github/CODEOWNERS
  - .github/dependabot.yml
autonomous: true
requirements:
  - SCAF-04
  - SCAF-05
must_haves:
  truths:
    - "Dependabot opens PRs for github-actions across the root and each future per-region directory via a single plural `directories:` list — satisfies success criterion 4 + SCAF-05."
    - "CODEOWNERS auto-assigns @pau-vega to any PR touching `actions/**` via a glob (not per-region literals) — satisfies success criterion 4 + SCAF-04."
  artifacts:
    - path: ".github/CODEOWNERS"
      provides: "Glob ownership rule covering all current and future actions/<region>/ directories"
      contains: "/actions/** @pau-vega"
    - path: ".github/dependabot.yml"
      provides: "github-actions ecosystem config with plural `directories:` list enumerating all 7 paths"
      contains: "package-ecosystem: \"github-actions\""
  key_links:
    - from: ".github/dependabot.yml"
      to: ".github/workflows/"
      via: "Dependabot scans / for workflows"
      pattern: '"\/"'
    - from: ".github/dependabot.yml"
      to: "actions/nordvpn-{es,us,fr}/{,disconnect/}action.yml"
      via: "Dependabot scans these directories for action.yml"
      pattern: 'nordvpn-(es|us|fr)'
    - from: ".github/CODEOWNERS"
      to: "actions/nordvpn-<region>/**"
      via: "Glob ownership"
      pattern: "/actions/\\*\\* @pau-vega"
---

<objective>
Create the two `.github/` configuration files that govern repo-wide ownership and dependency updates: `.github/CODEOWNERS` (glob ownership for `/actions/**`) and `.github/dependabot.yml` (single plural-`directories:` block enumerating all 7 paths the future regions and their `disconnect/` sub-actions will live in).

Purpose: Both files use forward-looking patterns so adding a new region in Phase 2/3 requires zero changes to either file (CODEOWNERS) or only an additive `directories:` entry change (Dependabot — though Phase 1 ships the full enumerated list pre-emptively per the SCAF-05 acceptance criterion). This is the "GitHub-side governance" half of the repo skeleton.

Output: `.github/CODEOWNERS` and `.github/dependabot.yml`, both committed.

Covers requirements: SCAF-04, SCAF-05.
</objective>

<execution_context>
@$HOME/.claude/get-shit-done/workflows/execute-plan.md
@$HOME/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@CLAUDE.md
@.planning/PROJECT.md
@.planning/REQUIREMENTS.md
@.planning/phases/01-scaffolding-lint/01-CONTEXT.md
@.planning/research/STACK.md
@.planning/research/PITFALLS.md

<key_facts>
<!-- Source-of-truth byte-exact values copied from CLAUDE.md and STACK.md. Use these verbatim. -->

CODEOWNERS pattern (SCAF-04 — copy verbatim, no variations):

  Path: `.github/CODEOWNERS`
  Content:
  ```
  # Every file under actions/ — current and future — is owned by pau-vega.
  /actions/** @pau-vega
  ```

  Why exactly this:
  - `/actions/*` matches files DIRECTLY in `/actions/` but NOT recursively. That would fail to cover `/actions/nordvpn-es/action.yml`. So `*` alone is wrong.
  - `/actions/**` matches every file at every depth under `/actions/`. A new `/actions/nordvpn-de/` added later is automatically covered without a CODEOWNERS edit.
  - NO trailing `* @pau-vega` global fallback — for a solo-maintainer repo, omitting the catch-all means PRs touching LICENSE, root README.md, or `.github/` don't auto-request review (which would be self-review).
  - SINGLE OWNER `@pau-vega`. No team handles, no other usernames.

Dependabot config (SCAF-05 — copy verbatim from STACK.md and CLAUDE.md):

  Path: `.github/dependabot.yml`
  Content:
  ```yaml
  version: 2
  updates:
    - package-ecosystem: "github-actions"
      directories:
        - "/"
        - "/actions/nordvpn-es"
        - "/actions/nordvpn-es/disconnect"
        - "/actions/nordvpn-us"
        - "/actions/nordvpn-us/disconnect"
        - "/actions/nordvpn-fr"
        - "/actions/nordvpn-fr/disconnect"
      schedule:
        interval: "weekly"
        day: "monday"
      commit-message:
        prefix: "deps"
      groups:
        actions:
          patterns: ["*"]
  ```

  Why exactly this:
  - `directories:` (plural) — GA since 2024-06-25. Collapses what used to be 7 separate `updates:` blocks into one.
  - SEVEN paths enumerated explicitly: `/` (workflows under `.github/workflows/`) + 3 region roots (each containing `action.yml`) + 3 region `disconnect/` sub-actions (each containing `action.yml`).
  - DO NOT use `directory:` (singular) — pre-2024-06 syntax requires 7 separate blocks.
  - DO NOT use a glob like `/actions/*` — explicit enumeration is easier to reason about when a new region is added (CONTEXT.md line 112: "Plan 2's dependabot.yml ships with the FULL list, not just `/`").
  - `schedule.interval: "weekly"` + `day: "monday"` — once-a-week PR batch; weekend pushes get bundled into Monday's PR.
  - `commit-message.prefix: "deps"` — matches the `deps` type in release-please's `changelog-sections` (Phase 5), so Dependabot PRs surface under "Dependencies" in CHANGELOGs.
  - `groups.actions.patterns: ["*"]` — batches all action updates from a single Dependabot run into ONE PR (not 7), avoiding PR-spam when multiple actions update the same week.

Forward-looking note: Phase 2 and Phase 3 land the actual `actions/nordvpn-{es,us,fr}/` directories. Until they do, Dependabot will scan paths that don't exist yet and silently no-op on them. This is acceptable — the alternative (incrementally adding paths as regions ship) would require a Dependabot config edit in every region-adding PR, which the explicit enumeration is designed to avoid.

Phase 1 self-coverage: the root `/` entry covers `.github/workflows/` for `actions/checkout` and other action references inside `actions-lint.yml` (Plan 03) and `release-please.yml` (Phase 5) — Dependabot updates the SHA + the `# vX.Y.Z` comment together because of the trailing-comment convention.
</key_facts>

<interfaces>
<!-- These two files are pure config files; no exported interfaces. -->
<!-- The .github/ directory does not yet exist; Task 1 creates it implicitly via the CODEOWNERS write. -->
</interfaces>
</context>

<tasks>

<task type="auto">
  <name>Task 1: Write .github/CODEOWNERS with glob ownership for /actions/**</name>
  <files>.github/CODEOWNERS</files>
  <read_first>
    - .planning/REQUIREMENTS.md (SCAF-04 acceptance criterion: `/actions/** @pau-vega` glob)
    - .planning/phases/01-scaffolding-lint/01-CONTEXT.md (D-04: solo repo, no second human reviewer)
    - .planning/research/STACK.md (`.github/CODEOWNERS` section: glob semantics rationale)
    - .planning/research/PITFALLS.md §18 (CODEOWNERS literal-path failure mode)
    - CLAUDE.md (CODEOWNERS recommended pattern under "Tech Stack" chapter)
  </read_first>
  <action>
    Create `.github/CODEOWNERS` (creating the `.github/` directory if it does not yet exist).

    File content (exact, byte-for-byte — copy verbatim, no additions, no variations):

    ```
    # Every file under actions/ — current and future — is owned by pau-vega.
    /actions/** @pau-vega
    ```

    Two lines: one comment line, one ownership rule. File ends with a single trailing newline (so 3 lines total in `wc -l` terms — the `\n` after the final character counts as line 2's terminator).

    DO NOT add:
    - A `* @pau-vega` global catch-all (forces self-review on every PR — D-04 explicitly opts out).
    - A `/actions/* @pau-vega` line (would only match direct children, not recursive — STACK.md and PITFALLS.md §18 explicitly warn against this).
    - Per-region literal paths like `/actions/nordvpn-es/ @pau-vega` (defeats the future-proof glob — PITFALLS.md §18).
    - Any other team handles or usernames (single-maintainer repo).
    - Header comments other than the single line shown.

    Create the parent `.github/` directory if needed:
    ```bash
    mkdir -p .github
    ```
  </action>
  <verify>
    <automated>test -f .github/CODEOWNERS && grep -qE '^/actions/\*\* @pau-vega$' .github/CODEOWNERS && [ "$(grep -cE '^/actions/' .github/CODEOWNERS)" = "1" ] && ! grep -qE '^\* @' .github/CODEOWNERS && ! grep -qE '/actions/nordvpn-' .github/CODEOWNERS</automated>
  </verify>
  <acceptance_criteria>
    - `test -f .github/CODEOWNERS` exits 0.
    - `grep -qE '^/actions/\*\* @pau-vega$' .github/CODEOWNERS` exits 0 (the glob ownership rule is present, byte-exact).
    - `grep -cE '^/actions/' .github/CODEOWNERS` returns exactly `1` (no other `/actions/...` lines — single rule, future-proof).
    - `! grep -qE '^\* @' .github/CODEOWNERS` exits 0 (no global catch-all, per D-04 / solo-maintainer rationale).
    - `! grep -qE '/actions/nordvpn-' .github/CODEOWNERS` exits 0 (no per-region literal paths — defeats the glob purpose, PITFALLS.md §18).
    - `wc -l .github/CODEOWNERS` returns exactly `2` (one comment line + one rule line; trailing newline counts as the terminator of line 2).
  </acceptance_criteria>
  <done>.github/CODEOWNERS exists with exactly the comment line and the `/actions/** @pau-vega` rule. No global catch-all, no per-region literals.</done>
</task>

<task type="auto">
  <name>Task 2: Write .github/dependabot.yml with plural `directories:` enumerating all 7 paths</name>
  <files>.github/dependabot.yml</files>
  <read_first>
    - .planning/REQUIREMENTS.md (SCAF-05 acceptance criterion: 7-path plural-directories list)
    - .planning/phases/01-scaffolding-lint/01-CONTEXT.md (Code Context: "Plan 2's dependabot.yml ships with the FULL list, not just `/`")
    - .planning/research/STACK.md (`.github/dependabot.yml` section — exact YAML to copy)
    - .planning/research/PITFALLS.md §19 (Dependabot stale-list failure mode)
    - CLAUDE.md (Dependabot configuration section)
  </read_first>
  <action>
    Create `.github/dependabot.yml`. The `.github/` directory exists from Task 1 (or, if Task 1 hasn't run yet, create it: `mkdir -p .github`).

    File content (exact, byte-for-byte — copy from key_facts above; reproduced here for in-task clarity):

    ```yaml
    version: 2
    updates:
      - package-ecosystem: "github-actions"
        directories:
          - "/"
          - "/actions/nordvpn-es"
          - "/actions/nordvpn-es/disconnect"
          - "/actions/nordvpn-us"
          - "/actions/nordvpn-us/disconnect"
          - "/actions/nordvpn-fr"
          - "/actions/nordvpn-fr/disconnect"
        schedule:
          interval: "weekly"
          day: "monday"
        commit-message:
          prefix: "deps"
        groups:
          actions:
            patterns: ["*"]
    ```

    Indentation: 2-space (per AGENTS.md Code Style — 2-space YAML indent). All quoted strings use DOUBLE quotes.

    DO NOT use:
    - `directory:` (singular) — pre-2024-06 syntax, would require 7 separate `updates:` blocks (PITFALLS.md §19 + STACK.md "What NOT to use" implication).
    - A glob like `"/actions/*"` or `"/actions/**"` — explicit enumeration is required per CONTEXT.md and STACK.md `.github/dependabot.yml` rationale.
    - `commit-message.prefix: "chore(deps)"` — must be just `"deps"` to match release-please's `changelog-sections` `deps` type (Phase 5 dependency).
    - Any extra ecosystems (no `npm`, no `pip` — pure-Bash repo, only `github-actions` is relevant).
    - `target-branch:` field — defaults to default branch (`main`) which is correct.
    - `open-pull-requests-limit:` — default of 5 is fine for a solo repo.
    - `assignees:` / `reviewers:` — CODEOWNERS handles auto-assignment via `/actions/** @pau-vega` glob.

    File ends with a single trailing newline.
  </action>
  <verify>
    <automated>test -f .github/dependabot.yml && grep -qE '^version: 2$' .github/dependabot.yml && grep -qE '^\s+- package-ecosystem: "github-actions"$' .github/dependabot.yml && grep -qE '^\s+directories:$' .github/dependabot.yml && [ "$(grep -cE '^\s+- "/' .github/dependabot.yml)" = "7" ] && grep -qE '^\s+- "/"$' .github/dependabot.yml && grep -qE '^\s+- "/actions/nordvpn-es"$' .github/dependabot.yml && grep -qE '^\s+- "/actions/nordvpn-es/disconnect"$' .github/dependabot.yml && grep -qE '^\s+- "/actions/nordvpn-us"$' .github/dependabot.yml && grep -qE '^\s+- "/actions/nordvpn-us/disconnect"$' .github/dependabot.yml && grep -qE '^\s+- "/actions/nordvpn-fr"$' .github/dependabot.yml && grep -qE '^\s+- "/actions/nordvpn-fr/disconnect"$' .github/dependabot.yml && grep -qE 'interval: "weekly"' .github/dependabot.yml && grep -qE 'prefix: "deps"' .github/dependabot.yml && grep -qE 'patterns: \["\*"\]' .github/dependabot.yml && ! grep -qE '^\s+directory:' .github/dependabot.yml</automated>
  </verify>
  <acceptance_criteria>
    - `test -f .github/dependabot.yml` exits 0.
    - `grep -qE '^version: 2$' .github/dependabot.yml` exits 0 (Dependabot v2 schema).
    - `grep -qE '^\s+- package-ecosystem: "github-actions"$' .github/dependabot.yml` exits 0 (single ecosystem block, github-actions, double-quoted).
    - `grep -qE '^\s+directories:$' .github/dependabot.yml` exits 0 (PLURAL key — required by SCAF-05).
    - `! grep -qE '^\s+directory:' .github/dependabot.yml` exits 0 (singular `directory:` MUST NOT be present — would imply pre-2024-06 syntax error).
    - The `directories:` list contains exactly 7 path entries: `grep -cE '^\s+- "/' .github/dependabot.yml` returns exactly `7`.
    - All 7 expected paths are present, byte-exact:
      - `grep -qE '^\s+- "/"$' .github/dependabot.yml`
      - `grep -qE '^\s+- "/actions/nordvpn-es"$' .github/dependabot.yml`
      - `grep -qE '^\s+- "/actions/nordvpn-es/disconnect"$' .github/dependabot.yml`
      - `grep -qE '^\s+- "/actions/nordvpn-us"$' .github/dependabot.yml`
      - `grep -qE '^\s+- "/actions/nordvpn-us/disconnect"$' .github/dependabot.yml`
      - `grep -qE '^\s+- "/actions/nordvpn-fr"$' .github/dependabot.yml`
      - `grep -qE '^\s+- "/actions/nordvpn-fr/disconnect"$' .github/dependabot.yml`
    - `grep -qE 'interval: "weekly"' .github/dependabot.yml` exits 0 AND `grep -qE 'day: "monday"' .github/dependabot.yml` exits 0 (schedule).
    - `grep -qE 'prefix: "deps"' .github/dependabot.yml` exits 0 (commit-message prefix matches release-please `deps` type — Phase 5 dependency).
    - `grep -qE 'patterns: \["\*"\]' .github/dependabot.yml` exits 0 (single grouped PR per Dependabot run).
    - YAML parse-ability: this is checked indirectly by Plan 03's `actionlint` against any workflow that depends on the dependabot config — a syntactically broken file would surface as a Dependabot configuration warning on GitHub once pushed (Plan 04). For Phase 1 local verification, the grep checks above are sufficient because the schema is shallow and well-known.
  </acceptance_criteria>
  <done>.github/dependabot.yml exists with the single `github-actions` ecosystem block, plural `directories:` key listing exactly 7 paths (root + 3 regions × 2 sub-paths each), weekly schedule on Monday, `deps` commit prefix, and a single `actions: patterns: ["*"]` group.</done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| Dependabot ↔ repo | Dependabot opens PRs against `main` with proposed dependency upgrades. Those PRs run through the same `actions-lint` gate (Plan 03) and the `pull_request_target` grep guard before merge. |
| CODEOWNERS ↔ PR review | CODEOWNERS auto-assigns `@pau-vega` to any PR touching `/actions/**`. For a solo repo this is informational; branch protection (Plan 04) does NOT require a review (`required_approving_review_count: 0`). |

## STRIDE Threat Register

| Threat ID | Category | Component | Disposition | Mitigation Plan |
|-----------|----------|-----------|-------------|-----------------|
| T-01-02-01 | E (Elevation of privilege) — supply-chain | `.github/dependabot.yml` Dependabot PRs | mitigate | Dependabot PRs are gated by the same `actions-lint` workflow and `pull_request_target` grep guard as human PRs (Plan 03). The grep guard rejects any Dependabot PR that introduces `pull_request_target`. The `actions-lint` shellcheck job rejects any PR that would break shell scripts. Verification: after Plan 04 enables branch protection, attempting to merge a Dependabot PR with a deliberately broken `actions/checkout` SHA fails the actionlint required check. The `commit-message.prefix: "deps"` ensures Dependabot PRs are auditable in the changelog. |
| T-01-02-02 | T (Tampering) — silent dependency-confusion | `.github/dependabot.yml` `directories:` list goes stale | accept | A new region added in Phase 2/3 must be added to this list explicitly. Phase 1 ships the FULL future-region list (D-08 / CONTEXT.md line 112), so Phase 2/3 require zero `dependabot.yml` edit. PITFALLS.md §19 captures the failure mode of forgetting to update this list; the explicit-enumeration approach prefers visibility over glob convenience. Verification: `grep -cE '^\s+- "/' .github/dependabot.yml` returns 7; if a future PR adds a region without updating this count, reviewer catches it. |
| T-01-02-03 | I (Information disclosure) — CODEOWNERS leak | `.github/CODEOWNERS` | accept | CODEOWNERS reveals the maintainer's GitHub handle (`@pau-vega`). This is intentional and public (the repo is public, MIT-licensed; the maintainer's GitHub profile is also public). No threat. |
| T-01-02-04 | D (Denial of service) — Dependabot PR flood | `.github/dependabot.yml` `groups: actions: patterns: ["*"]` | mitigate | Without grouping, 7 directories × N actions could open 7N+ PRs per week. The `groups.actions.patterns: ["*"]` block batches all action updates into a single weekly PR. Verification: `grep -qE 'patterns: \["\*"\]' .github/dependabot.yml`. Default Dependabot `open-pull-requests-limit: 5` is also a backstop. |

**ASVS L1 mapping:**
- V14.5 (Validate file type / extension / structure): N/A — these are config files, parsed by GitHub.
- V8.3 (Restrict access to sensitive data): N/A — no secrets in either file.
- V1.6 (Architecture: trust boundaries): the Dependabot ↔ PR boundary is documented; mitigation via Plan 03's lint gate.
</threat_model>

<verification>
Phase-end gates for this plan (run after both tasks complete):

1. `test -f .github/CODEOWNERS && test -f .github/dependabot.yml` exits 0 — both artifacts present.
2. `grep -qE '^/actions/\*\* @pau-vega$' .github/CODEOWNERS` exits 0 — SCAF-04 satisfied.
3. `grep -qE '^\s+directories:$' .github/dependabot.yml` exits 0 — plural directories key present (SCAF-05).
4. `grep -cE '^\s+- "/' .github/dependabot.yml` returns exactly `7` — SCAF-05 path enumeration count satisfied.
5. `! grep -qE '^\s+directory:' .github/dependabot.yml` exits 0 — singular `directory:` not present.
6. `! grep -qE '^\* @' .github/CODEOWNERS` exits 0 — no global catch-all.
</verification>

<success_criteria>
- `.github/CODEOWNERS` and `.github/dependabot.yml` exist.
- CODEOWNERS uses single `/actions/** @pau-vega` glob; no per-region literals; no global catch-all.
- Dependabot config uses plural `directories:` with EXACTLY 7 enumerated paths (root + 3 regions × {action, disconnect}); weekly schedule on Monday; `deps` commit prefix; single `actions: patterns: ["*"]` group.
- Both files parse as valid YAML (CODEOWNERS is plain text — N/A).
- All acceptance criteria for Tasks 1 and 2 pass.
</success_criteria>

<output>
After completion, create `.planning/phases/01-scaffolding-lint/01-02-github-config-SUMMARY.md` documenting:
- Files created (`.github/CODEOWNERS`, `.github/dependabot.yml`) with byte sizes.
- Confirmation: CODEOWNERS contains exactly `/actions/** @pau-vega` (1 rule line, 1 comment line).
- Confirmation: Dependabot `directories:` list contains EXACTLY 7 paths with the byte-exact strings.
- Confirmation: `directory:` (singular) does NOT appear.
- Note for Phase 2/3 planners: when adding a new region, the CODEOWNERS file requires zero changes (glob covers it); the dependabot.yml file requires an additive entry in the `directories:` list (forward-loaded for ES/US/FR but a 4th region requires 2 new entries — root + disconnect).
</output>