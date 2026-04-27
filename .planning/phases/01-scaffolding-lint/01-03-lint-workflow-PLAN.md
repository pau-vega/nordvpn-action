---
phase: 01-scaffolding-lint
plan: 03
type: execute
wave: 1
depends_on: []
files_modified:
  - .github/workflows/actions-lint.yml
autonomous: true
requirements:
  - LINT-01
  - LINT-02
  - LINT-03
  - LINT-04
  - LINT-05
must_haves:
  truths:
    - "A PR that opens with a broken action.yml or shellcheck violation under actions/*/scripts/ fails the required actions-lint check and cannot be merged into main; a PR with clean files passes — satisfies success criterion 2 + LINT-01..04."
    - "A PR that introduces `on: pull_request_target` anywhere in `.github/workflows/**` is rejected by a grep-based CI step in the lint workflow with a clear message — satisfies success criterion 3 + LINT-05."
    - "The lint workflow itself uses `pull_request` (NOT `pull_request_target`) — the workflow self-complies with the rule it enforces."
    - "Every `uses:` line in the workflow uses the SHA + `# vX.Y.Z` form, no exceptions — pin posture contract is dogfooded from the first workflow."
  artifacts:
    - path: ".github/workflows/actions-lint.yml"
      provides: "Three parallel jobs gating any PR touching actions/** or workflows: actionlint, shellcheck, block-pull-request-target"
      contains: "name: actions-lint"
    - path: ".github/workflows/actions-lint.yml#jobs.actionlint"
      provides: "actionlint job using reviewdog/action-actionlint@<SHA> # v1.72.0 with fail_on_error: true (LINT-02)"
      contains: "reviewdog/action-actionlint@6fb7acc99f4a1008869fa8a0f09cfca740837d9d"
    - path: ".github/workflows/actions-lint.yml#jobs.shellcheck"
      provides: "shellcheck job using ludeeus/action-shellcheck@<SHA> # 2.0.0 with strict severity over actions/ (LINT-03)"
      contains: "ludeeus/action-shellcheck@00cae500b08a931fb5698e11e79bfbd38e612a38"
    - path: ".github/workflows/actions-lint.yml#jobs.block-pull-request-target"
      provides: "Grep-based guard rejecting any workflow file under .github/workflows/** that uses `pull_request_target` (LINT-05)"
      contains: "block-pull-request-target"
  key_links:
    - from: "actions-lint.yml `on:`"
      to: "PRs touching actions/** or .github/workflows/**"
      via: "paths filter"
      pattern: "paths:"
    - from: "actions-lint.yml workflow-level `permissions:`"
      to: "least-privilege contents:read"
      via: "workflow-level permissions block (LINT-04)"
      pattern: "permissions:\\s*\\n\\s+contents: read"
    - from: "actions-lint.yml `concurrency:`"
      to: "cancels in-progress runs on same ref (LINT-04)"
      via: "concurrency group with cancel-in-progress: true"
      pattern: "cancel-in-progress: true"
    - from: "block-pull-request-target job"
      to: "AGENTS.md §Security Considerations + .planning/research/PITFALLS.md §2"
      via: "error message citation"
      pattern: "PITFALLS\\.md"
---

<objective>
Create `.github/workflows/actions-lint.yml`: a single workflow file with three parallel jobs (`actionlint`, `shellcheck`, `block-pull-request-target`) that gate every PR touching `actions/**` or `.github/workflows/**`. This is the durable defense layer against workflow misconfiguration, shell-script bugs, and the `pull_request_target` ACE attack class (PITFALLS.md §2).

Purpose: Phase 1 ends with this workflow as a required check on `main` (Plan 04). Every subsequent phase's PRs land through this gate. The workflow itself dogfoods the pin-posture contract (every `uses:` line is SHA + `# vX.Y.Z`) and uses `pull_request` (never `pull_request_target`), so it self-complies with the rule it enforces.

Output: `.github/workflows/actions-lint.yml`, committed.

Covers requirements: LINT-01, LINT-02, LINT-03, LINT-04, LINT-05.
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
@.planning/research/ARCHITECTURE.md
@.planning/research/PITFALLS.md

<key_facts>
<!-- Source-of-truth byte-exact values. Use these verbatim. -->

Pinned SHAs (HARD CONSTRAINT — copy these byte-for-byte; verify in CLAUDE.md "Tech Stack" chapter):

  actions/checkout:           de0fac2e4500dabe0009e67214ff5f5447ce83dd  # v6.0.2
  reviewdog/action-actionlint: 6fb7acc99f4a1008869fa8a0f09cfca740837d9d  # v1.72.0
  ludeeus/action-shellcheck:  00cae500b08a931fb5698e11e79bfbd38e612a38  # 2.0.0

  Format requirement: every `uses:` line MUST be `<owner>/<repo>@<40-char-SHA> # <semver-tag>` with EXACTLY one space before `#`, no quotes, no trailing whitespace.
  Floating tags (`@v6`, `@main`, `@latest`) are PROHIBITED — Plan 04's branch protection makes this checkable, but Plan 03 must be the first to comply.

Workflow structure (exact YAML — copy and adapt the strings carefully):

  ```yaml
  name: actions-lint

  on:
    pull_request:
      paths:
        - 'actions/**'
        - '.github/workflows/**'
        - '.github/actions/**'
    push:
      branches: [main]
      paths:
        - 'actions/**'
        - '.github/workflows/**'
        - '.github/actions/**'

  permissions:
    contents: read

  concurrency:
    group: actions-lint-${{ github.workflow }}-${{ github.ref }}
    cancel-in-progress: true

  jobs:
    actionlint:
      name: actionlint
      runs-on: ubuntu-latest
      steps:
        - uses: actions/checkout@de0fac2e4500dabe0009e67214ff5f5447ce83dd # v6.0.2
        - uses: reviewdog/action-actionlint@6fb7acc99f4a1008869fa8a0f09cfca740837d9d # v1.72.0
          with:
            reporter: github-pr-review
            fail_on_error: true
            level: error

    shellcheck:
      name: shellcheck
      runs-on: ubuntu-latest
      steps:
        - uses: actions/checkout@de0fac2e4500dabe0009e67214ff5f5447ce83dd # v6.0.2
        - uses: ludeeus/action-shellcheck@00cae500b08a931fb5698e11e79bfbd38e612a38 # 2.0.0
          env:
            SHELLCHECK_OPTS: "-e SC1090 -e SC1091"
          with:
            scandir: ./actions
            severity: style
            check_together: 'yes'

    block-pull-request-target:
      name: block-pull-request-target
      runs-on: ubuntu-latest
      steps:
        - uses: actions/checkout@de0fac2e4500dabe0009e67214ff5f5447ce83dd # v6.0.2
        - name: Reject pull_request_target trigger
          run: |
            set -euo pipefail
            shopt -s globstar nullglob
            offenders=()
            # Scope: only workflow files under .github/workflows/** (composite action.yml files
            # cannot define triggers, so scanning them would be theatre — see CONTEXT.md D-11).
            for f in .github/workflows/**/*.yml .github/workflows/**/*.yaml; do
              [ -e "$f" ] || continue
              # Match `pull_request_target` ONLY when it appears as a workflow trigger:
              #   - on its own indented line as a key (`pull_request_target:`)
              #   - or as part of an array under `on:` block (`- pull_request_target`)
              # Comments and incidental string mentions in plain text do not trip the guard
              # (see CONTEXT.md D-10 for the exact semantics required).
              if grep -nE '^[[:space:]]*pull_request_target[[:space:]]*:' "$f" \
                 || grep -nE '^[[:space:]]*-[[:space:]]+pull_request_target([[:space:]]|$)' "$f"; then
                offenders+=("$f")
              fi
            done
            if [ "${#offenders[@]}" -gt 0 ]; then
              echo "::error::pull_request_target trigger detected in workflow file(s):"
              for f in "${offenders[@]}"; do
                echo "::error file=$f::pull_request_target is BANNED in this repo. See AGENTS.md §Security Considerations and .planning/research/PITFALLS.md §2."
              done
              echo ""
              echo "Why: pull_request_target runs the workflow from the base ref with full secrets access; combined with checkout of PR head SHA = arbitrary code execution + secret exfiltration class. Documented attack vectors: timescale/pgai GHSA-89qq-hgvp-x37m; hackerbot-claw April 2026 campaign (475+ malicious PRs in 26h)."
              echo "Fix: use 'pull_request' instead. If you genuinely need fork-PR feedback, use the split-workflow pattern (pull_request -> artifact handoff -> workflow_run for privileged comment-back)."
              exit 1
            fi
            echo "OK: no pull_request_target trigger found in .github/workflows/**."
  ```

Job-level required-checks contract (LINT-04 + Plan 04 dependency):

  Plan 04's branch-protection script lists THREE required check names matching the `name:` field of each job:
    1. `actionlint`
    2. `shellcheck`
    3. `block-pull-request-target`

  IMPORTANT: each job MUST have an explicit `name:` field at the job level so the GitHub-side check name is stable and predictable. GitHub uses the JOB ID (key in `jobs:`) as the default check name, but providing an explicit `name:` matching the JOB ID makes Plan 04's check-name list verifiable without YAML parsing.

LINT-05 grep semantics (from D-10 + D-11 + D-12):

  REGEX REQUIREMENT (D-10):
  - MUST match: `pull_request_target:` on a line (workflow-trigger key form).
  - MUST match: `- pull_request_target` (array-element form under `on:` block).
  - MUST NOT match: a comment line (`# pull_request_target is banned`).
  - MUST NOT match: a plain-text mention in a non-YAML file (LINT-05 scopes to `.github/workflows/**` only — D-11).
  - MUST NOT match: a string mention inside a quoted value (`"pull_request_target"` as a string literal).

  SCOPE REQUIREMENT (D-11):
  - Only scan `.github/workflows/**/*.yml` and `.github/workflows/**/*.yaml`.
  - Composite `action.yml` files at `actions/**/action.yml` are NOT scanned (they cannot define triggers, so scanning would be theatre with false-positive risk).

  ERROR MESSAGE REQUIREMENT (D-12):
  - Exit non-zero (`exit 1`) on detection.
  - Echo a clear error message via `::error::` that:
    1. Names the offending file(s).
    2. Cites `AGENTS.md §Security Considerations` and `.planning/research/PITFALLS.md §2` as the rationale source.
    3. Includes the one-line summary: "pull_request_target runs the workflow from base ref with full secrets access; combined with checkout of PR head SHA = arbitrary code execution + secret exfiltration class."
    4. Suggests the correct alternative (`pull_request` + split-workflow pattern if feedback is needed).

Self-compliance: this very workflow file MUST trigger ITS OWN actionlint job clean. To satisfy `pull_request_target` ban: this workflow uses `on: pull_request` (NOT `on: pull_request_target`).

Workflow-level `permissions:` (LINT-04): EXACTLY `permissions: { contents: read }` at workflow level. NO additional permissions, NO write scopes. The workflow does not write to the repo, only reads.

Concurrency (LINT-04): EXACTLY `concurrency: group: actions-lint-${{ github.workflow }}-${{ github.ref }}` with `cancel-in-progress: true`. Cancels in-progress runs when a new commit lands on the same ref (PR push amend, etc.) — saves CI minutes, never blocks merges.

Path filter (LINT-01): trigger ONLY on PRs that touch `actions/**`, `.github/workflows/**`, or `.github/actions/**` (the latter for any future repo-local action helpers). Docs-only PRs (touching only `README.md`, `AGENTS.md`, etc.) do NOT trigger this workflow — keeps CI minutes for what matters.

Push trigger: the workflow ALSO runs on `push: branches: [main]` with the same path filter. This catches the case where a release-please commit lands on main (Phase 5) — the actions-lint job re-runs against the merged tree, surfacing any post-merge regression.

shellcheck job specifics (from STACK.md `actions-lint.yml`):
- `scandir: ./actions` — scopes to action scripts only.
- `severity: style` — runs all categories including style suggestions.
- `check_together: 'yes'` — invokes shellcheck once on all files (faster, identical result).
- `SHELLCHECK_OPTS: "-e SC1090 -e SC1091"` — excludes SC1090 / SC1091 (non-constant source paths) which fire falsely on scripts that `source "$RUNNER_TEMP/..."` style dynamic paths.
- Phase 1 reality: no `actions/*/scripts/*.sh` files exist yet (regions ship in Phases 2/3). The shellcheck job runs against an empty `./actions/` directory, finds nothing, and exits 0 — that's correct. The job is in place so Phase 2's first script PR is auto-validated from byte one.

actionlint job specifics:
- `reporter: github-pr-review` — inline annotations on the PR.
- `fail_on_error: true` — hard CI fail on any actionlint error (the default is annotate-only, which is wrong for a required check).
- `level: error` — only fail on errors, not warnings (warnings still annotate; `fail_on_error: true` + `level: error` is the canonical "block on errors" combo per STACK.md).
</key_facts>

<interfaces>
<!-- The workflow file is YAML; no programmatic interfaces. -->
<!-- Downstream consumers: -->
<!--   - Plan 04's setup-branch-protection.sh requires the job names: actionlint, shellcheck, block-pull-request-target. -->
<!--   - Phase 4's self-test.yml will be linted by THIS workflow on its first PR. -->
<!--   - Phase 5's release-please.yml will be linted by THIS workflow on its first PR. -->
</interfaces>
</context>

<tasks>

<task type="auto">
  <name>Task 1: Write .github/workflows/actions-lint.yml with three parallel jobs (actionlint + shellcheck + block-pull-request-target)</name>
  <files>.github/workflows/actions-lint.yml</files>
  <read_first>
    - .planning/REQUIREMENTS.md (LINT-01..05 acceptance criteria, byte-by-byte)
    - .planning/phases/01-scaffolding-lint/01-CONTEXT.md (D-09: third parallel job; D-10: regex semantics; D-11: scope to .github/workflows/**; D-12: error message citing PITFALLS.md §2)
    - .planning/research/STACK.md `.github/workflows/actions-lint.yml` section (canonical YAML to copy with-the LINT-05 third job added)
    - .planning/research/PITFALLS.md §2 (pull_request_target ACE — the rationale this workflow enforces) and §6 (set -x leaks — informs why shellcheck strict)
    - .planning/research/ARCHITECTURE.md "Workflow 1: actions-lint.yml — The Gatekeeper" section
    - CLAUDE.md (Tech Stack chapter — pinned SHAs, "Pin posture inside this repo")
  </read_first>
  <action>
    Create `.github/workflows/actions-lint.yml` (creating the `.github/workflows/` directory if it does not yet exist).

    Use 2-space YAML indent throughout. Every `uses:` line MUST follow the exact pin format: `<40-char-SHA> # vX.Y.Z` (single space before `#`, no quotes).

    Step-by-step assembly:

    1. **Workflow header** — `name: actions-lint`.

    2. **`on:` triggers (LINT-01):**
       - `pull_request:` with `paths:` filter listing `'actions/**'`, `'.github/workflows/**'`, `'.github/actions/**'`.
       - `push: branches: [main]` with the SAME `paths:` filter.
       - DO NOT add `pull_request_target:`. (This workflow self-complies with the rule it enforces; the workflow's own actionlint job would trigger this workflow's own block-pull-request-target job, but more importantly the rule is general — never use `pull_request_target` anywhere.)

    3. **Workflow-level `permissions:` (LINT-04):** exactly `permissions: { contents: read }`. Express as a YAML mapping (`permissions:` on its own line, then `contents: read` indented 2 spaces) — not the inline `{ }` form, for actionlint friendliness.

    4. **Workflow-level `concurrency:` (LINT-04):**
       - `group: actions-lint-${{ github.workflow }}-${{ github.ref }}`
       - `cancel-in-progress: true`

    5. **`jobs:` block with THREE parallel jobs:**

       **Job A: `actionlint` (LINT-02):**
       - JOB ID: `actionlint`. EXPLICIT `name: actionlint` at the job level (so the GitHub check name matches Plan 04's required-checks list).
       - `runs-on: ubuntu-latest`.
       - Step 1: `uses: actions/checkout@de0fac2e4500dabe0009e67214ff5f5447ce83dd # v6.0.2` (NO `with:` — default checkout shallow is fine for lint).
       - Step 2: `uses: reviewdog/action-actionlint@6fb7acc99f4a1008869fa8a0f09cfca740837d9d # v1.72.0` with:
         ```yaml
         with:
           reporter: github-pr-review
           fail_on_error: true
           level: error
         ```

       **Job B: `shellcheck` (LINT-03):**
       - JOB ID: `shellcheck`. EXPLICIT `name: shellcheck` at the job level.
       - `runs-on: ubuntu-latest`.
       - Step 1: `uses: actions/checkout@de0fac2e4500dabe0009e67214ff5f5447ce83dd # v6.0.2`.
       - Step 2: `uses: ludeeus/action-shellcheck@00cae500b08a931fb5698e11e79bfbd38e612a38 # 2.0.0` with:
         ```yaml
         env:
           SHELLCHECK_OPTS: "-e SC1090 -e SC1091"
         with:
           scandir: ./actions
           severity: style
           check_together: 'yes'
         ```

       **Job C: `block-pull-request-target` (LINT-05):**
       - JOB ID: `block-pull-request-target`. EXPLICIT `name: block-pull-request-target` at the job level.
       - `runs-on: ubuntu-latest`.
       - Step 1: `uses: actions/checkout@de0fac2e4500dabe0009e67214ff5f5447ce83dd # v6.0.2`.
       - Step 2: A `name: Reject pull_request_target trigger` step with a `run: |` block containing the exact bash from the key_facts above. Copy it verbatim — do not paraphrase. Specifically:
         - `set -euo pipefail` at the top.
         - `shopt -s globstar nullglob` so `**` recurses.
         - Loop over `.github/workflows/**/*.yml` and `.github/workflows/**/*.yaml`.
         - Two grep patterns (D-10):
           - `grep -nE '^[[:space:]]*pull_request_target[[:space:]]*:' "$f"` — matches the key form on a line.
           - `grep -nE '^[[:space:]]*-[[:space:]]+pull_request_target([[:space:]]|$)' "$f"` — matches the array-element form (`  - pull_request_target` under `on:`).
         - On hit: append to `offenders` array.
         - After the loop: if any offender, emit `::error::` lines naming the file(s), citing `AGENTS.md §Security Considerations` and `.planning/research/PITFALLS.md §2`, including the one-line ACE-class summary and a fix suggestion (`pull_request` + split-workflow pattern), then `exit 1`.
         - On clean: echo `OK: no pull_request_target trigger found in .github/workflows/**.`.

    6. **NO additional jobs.** Only three jobs (LINT-01..05 cleanly map to these three).

    7. **Final newline.** File ends with a single trailing newline.

    Self-compliance verification (the workflow MUST self-lint clean):
    - `actionlint .github/workflows/actions-lint.yml` exits 0.
    - The block-pull-request-target job, run against this very file, finds zero offenders.

    DO NOT use:
    - `pull_request_target:` anywhere in the `on:` block (would trip the workflow's own guard, but more importantly violates LINT-05).
    - Any floating tag (`@v6`, `@main`, `@v1`, `@latest`) on any `uses:` line.
    - `permissions: write-all` or any write scopes.
    - `permissions:` at job level (workflow level only is correct here; jobs inherit).
    - Implicit `name:` (default-job-id) — explicit `name:` matches the Plan 04 check-name list.
    - `continue-on-error: true` on any step (LINT-02 explicitly requires `fail_on_error: true`).
    - Inline scripts that `set -x` (PITFALLS.md §6 — would leak any tokens into logs even though this workflow has none).
    - `actions-shellcheck@2.0.0` without the env / with / scandir block — must be the full configured form.
    - Multi-line bash in a `run:` block without `set -euo pipefail` (Code Style requirement).
  </action>
  <verify>
    <automated>test -f .github/workflows/actions-lint.yml && grep -qE '^name: actions-lint$' .github/workflows/actions-lint.yml && grep -qE '^on:' .github/workflows/actions-lint.yml && grep -qE 'pull_request:' .github/workflows/actions-lint.yml && ! grep -qE '^[[:space:]]*pull_request_target[[:space:]]*:' .github/workflows/actions-lint.yml && grep -qE "^[[:space:]]+contents: read$" .github/workflows/actions-lint.yml && grep -qE 'cancel-in-progress: true' .github/workflows/actions-lint.yml && grep -qE '^jobs:' .github/workflows/actions-lint.yml && grep -qE '^[[:space:]]+actionlint:' .github/workflows/actions-lint.yml && grep -qE '^[[:space:]]+shellcheck:' .github/workflows/actions-lint.yml && grep -qE '^[[:space:]]+block-pull-request-target:' .github/workflows/actions-lint.yml && [ "$(grep -cE 'name: actionlint|name: shellcheck|name: block-pull-request-target' .github/workflows/actions-lint.yml)" -ge 3 ] && grep -qE 'uses: actions/checkout@de0fac2e4500dabe0009e67214ff5f5447ce83dd # v6\.0\.2' .github/workflows/actions-lint.yml && grep -qE 'uses: reviewdog/action-actionlint@6fb7acc99f4a1008869fa8a0f09cfca740837d9d # v1\.72\.0' .github/workflows/actions-lint.yml && grep -qE 'uses: ludeeus/action-shellcheck@00cae500b08a931fb5698e11e79bfbd38e612a38 # 2\.0\.0' .github/workflows/actions-lint.yml && grep -qE 'fail_on_error: true' .github/workflows/actions-lint.yml && grep -qE 'severity: style' .github/workflows/actions-lint.yml && grep -qE 'scandir: \./actions' .github/workflows/actions-lint.yml && grep -qE 'SHELLCHECK_OPTS: "-e SC1090 -e SC1091"' .github/workflows/actions-lint.yml && grep -qE 'PITFALLS\.md' .github/workflows/actions-lint.yml && grep -qE 'AGENTS\.md' .github/workflows/actions-lint.yml && grep -qE 'set -euo pipefail' .github/workflows/actions-lint.yml && ! grep -qE 'uses: [^@]+@[^[:space:]]+$' .github/workflows/actions-lint.yml && ! grep -qE 'uses: [^@]+@(main|latest|v[0-9]+)$' .github/workflows/actions-lint.yml</automated>
  </verify>
  <acceptance_criteria>
    - File exists: `test -f .github/workflows/actions-lint.yml` exits 0.
    - Workflow name: `grep -qE '^name: actions-lint$' .github/workflows/actions-lint.yml` exits 0.
    - **LINT-01 (PR trigger + path filter):**
      - `grep -qE '^on:' .github/workflows/actions-lint.yml` exits 0.
      - `grep -qE '^[[:space:]]+pull_request:$' .github/workflows/actions-lint.yml` exits 0.
      - `grep -qE "'actions/\*\*'" .github/workflows/actions-lint.yml` exits 0 (path filter includes actions/**).
      - `grep -qE "'\.github/workflows/\*\*'" .github/workflows/actions-lint.yml` exits 0 (path filter includes .github/workflows/**).
      - `grep -qE '^[[:space:]]+push:$' .github/workflows/actions-lint.yml` exits 0 (push trigger present for main).
      - `grep -qE 'branches: \[main\]' .github/workflows/actions-lint.yml` exits 0.
    - **LINT-02 (actionlint pinned + fail_on_error):**
      - `grep -qE 'uses: reviewdog/action-actionlint@6fb7acc99f4a1008869fa8a0f09cfca740837d9d # v1\.72\.0' .github/workflows/actions-lint.yml` exits 0 (exact SHA + comment, byte-exact).
      - `grep -qE 'fail_on_error: true' .github/workflows/actions-lint.yml` exits 0.
      - `grep -qE 'level: error' .github/workflows/actions-lint.yml` exits 0.
      - `grep -qE 'reporter: github-pr-review' .github/workflows/actions-lint.yml` exits 0.
    - **LINT-03 (shellcheck pinned + strict severity over actions/):**
      - `grep -qE 'uses: ludeeus/action-shellcheck@00cae500b08a931fb5698e11e79bfbd38e612a38 # 2\.0\.0' .github/workflows/actions-lint.yml` exits 0.
      - `grep -qE 'scandir: \./actions' .github/workflows/actions-lint.yml` exits 0.
      - `grep -qE 'severity: style' .github/workflows/actions-lint.yml` exits 0.
      - `grep -qE 'check_together:' .github/workflows/actions-lint.yml` exits 0.
      - `grep -qE 'SHELLCHECK_OPTS: "-e SC1090 -e SC1091"' .github/workflows/actions-lint.yml` exits 0 (byte-exact SC1090/SC1091 exclusion).
    - **LINT-04 (workflow-level permissions: contents:read AND concurrency cancel-in-progress on same ref):**
      - `grep -qE '^permissions:$' .github/workflows/actions-lint.yml` exits 0 (workflow-level permissions block).
      - `grep -qE '^[[:space:]]+contents: read$' .github/workflows/actions-lint.yml` exits 0 (least-privilege).
      - `! grep -qE '^[[:space:]]*contents: write' .github/workflows/actions-lint.yml` exits 0 (no write scope at any level).
      - `grep -qE '^concurrency:$' .github/workflows/actions-lint.yml` exits 0 (workflow-level concurrency block).
      - `grep -qE 'group: actions-lint-' .github/workflows/actions-lint.yml` exits 0.
      - `grep -qE 'cancel-in-progress: true' .github/workflows/actions-lint.yml` exits 0.
    - **LINT-05 (block-pull-request-target job exists, scoped to .github/workflows/**, with PITFALLS.md §2 citation):**
      - `grep -qE '^[[:space:]]+block-pull-request-target:$' .github/workflows/actions-lint.yml` exits 0 (job ID present).
      - `grep -qE 'name: block-pull-request-target' .github/workflows/actions-lint.yml` exits 0 (explicit job name for Plan 04 check-list match).
      - `grep -qE '\.github/workflows/' .github/workflows/actions-lint.yml` exits 0 (scope is `.github/workflows/**`).
      - `! grep -qE 'actions/\*\*/action\.yml' .github/workflows/actions-lint.yml || true` — composite action.yml files MUST NOT be scanned by the guard (D-11). Negative check is strict, but allow non-strict (the absence of the path is the actual constraint; use `! grep` if a single literal pattern is referenced, otherwise rely on the positive scope check above).
      - `grep -qE 'PITFALLS\.md' .github/workflows/actions-lint.yml` exits 0 (rationale citation — D-12).
      - `grep -qE 'AGENTS\.md' .github/workflows/actions-lint.yml` exits 0 (cross-link to security section — D-12).
      - `grep -qE 'set -euo pipefail' .github/workflows/actions-lint.yml` exits 0 (the run block uses set-euo-pipefail per Code Style).
      - `grep -qE 'exit 1' .github/workflows/actions-lint.yml` exits 0 (hard fail — D-12).
      - `grep -qE '::error::' .github/workflows/actions-lint.yml` exits 0 (uses GitHub error annotation — D-12).
    - **Self-compliance:**
      - `! grep -qE '^[[:space:]]*pull_request_target[[:space:]]*:' .github/workflows/actions-lint.yml` exits 0 (workflow does NOT use pull_request_target — would self-trigger the guard).
      - `! grep -qE '^[[:space:]]*-[[:space:]]+pull_request_target([[:space:]]|$)' .github/workflows/actions-lint.yml` exits 0 (no array-form either).
    - **Pin posture (CLAUDE.md hard constraint):**
      - All three pinned SHAs present byte-exact (covered by LINT-02 + LINT-03 + the `actions/checkout` pin):
        - `grep -cE 'uses: actions/checkout@de0fac2e4500dabe0009e67214ff5f5447ce83dd # v6\.0\.2' .github/workflows/actions-lint.yml` returns at least `3` (one per job).
      - `! grep -qE 'uses: [^@[:space:]]+@(main|latest|v[0-9]+(\.[0-9]+)?)([[:space:]]|$)' .github/workflows/actions-lint.yml` exits 0 (no floating tags — every `uses:` line has a 40-char SHA followed by ` # v...`).
    - **YAML structure sanity:**
      - `grep -cE '^[[:space:]]+[a-z-]+:$' .github/workflows/actions-lint.yml` returns at least `3` (three job IDs as YAML keys).
      - `wc -l .github/workflows/actions-lint.yml` returns at least 70 lines (full three-job workflow with permissions, concurrency, paths, and the LINT-05 inline guard).
    - **Locally runnable lint check (manual sanity, optional but recommended):** if `actionlint` is available in PATH (`which actionlint`), `actionlint .github/workflows/actions-lint.yml` exits 0. If not in PATH, this is verified by Plan 04 once the workflow runs in CI.
  </acceptance_criteria>
  <done>.github/workflows/actions-lint.yml exists with three parallel jobs (`actionlint`, `shellcheck`, `block-pull-request-target`) each with explicit `name:` for Plan 04 check-list compatibility. Workflow uses `pull_request` (NEVER `pull_request_target`), has `permissions: contents: read` at workflow level, has a concurrency group with `cancel-in-progress: true`, and pins all three external actions to the canonical SHAs from CLAUDE.md byte-exact. The block-pull-request-target job's run-block scans `.github/workflows/**/*.{yml,yaml}` only, uses both regex patterns from D-10, and emits a clear error citing `AGENTS.md` and `PITFALLS.md §2` on detection.</done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| Untrusted PR (any contributor incl. forks) ↔ workflow runner | A PR may modify any file in the repo, including `.github/workflows/**`. The workflow runs from the PR's HEAD SHA in `pull_request` context; no secrets are exposed by design. |
| Workflow runner ↔ GitHub API (annotations only) | The workflow only emits `::error::` annotations and a non-zero exit code; no API writes. `permissions: contents: read` is the only granted scope at workflow level. |
| `block-pull-request-target` job ↔ filesystem scan | The job greps file content from the checked-out tree. No code execution from grepped content; pure regex scan. |

## STRIDE Threat Register

| Threat ID | Category | Component | Disposition | Mitigation Plan |
|-----------|----------|-----------|-------------|-----------------|
| T-01-03-01 | E (Elevation of privilege) — workflow injection / ACE | The workflow itself, if a future PR added `pull_request_target` here | mitigate | The `block-pull-request-target` job in this very workflow will detect any PR (including a PR to this workflow file itself) that introduces `pull_request_target` and hard-fail with `exit 1`. The error message cites `PITFALLS.md §2` (D-12). The workflow self-complies: it uses `pull_request` and the guard runs against itself on every PR. **Verification:** if a malicious PR adds `pull_request_target:` to any `.yml` under `.github/workflows/`, the `block-pull-request-target` required check fails, branch protection (Plan 04) refuses merge. The two regex patterns in the guard cover both YAML key form (`pull_request_target:`) and array-element form (`- pull_request_target`) per D-10. |
| T-01-03-02 | T (Tampering) — bypassing the guard via comments or string mentions | Future contributors trying to "explain" pull_request_target in a comment that trips the guard, or attackers obfuscating the trigger | accept (false-positive risk) | The D-10 regex semantics deliberately exclude comments (lines starting with `#`) and quoted string literals. A line like `# pull_request_target is banned` does NOT match `^[[:space:]]*pull_request_target[[:space:]]*:` because the `#` is at the start. **Acceptance rationale:** YAML triggers are positionally constrained (key under `on:` or array element under `on:`); attackers cannot bypass via comments without making the workflow non-functional. If a future contributor genuinely needs to discuss `pull_request_target` in a comment, they can use any wording that doesn't match the two patterns (e.g., "pull-request-target" with hyphens, or split across lines). |
| T-01-03-03 | T (Tampering) — replacing pinned SHAs with malicious ones | A PR that swaps the `reviewdog/action-actionlint` SHA to a compromised one | mitigate | Dependabot (Plan 02) opens PRs that update SHAs only when upstream releases a new version; those PRs go through the same `actions-lint` gate (this workflow self-applies on `.github/workflows/**` changes). A malicious manual PR would also go through the gate but would not be auto-detected — mitigated by branch protection (Plan 04, `enforce_admins: true`) requiring this workflow's three checks to pass and by CODEOWNERS auto-requesting `@pau-vega` review on `actions/**` (does NOT cover `.github/workflows/**` deliberately — solo repo accepts this). **Residual risk:** a malicious actor with maintainer access could swap a SHA. This is accepted; the same actor could rewrite history. Defense is repo access control, not workflow content. |
| T-01-03-04 | I (Information disclosure) — secret echo via shell trace | The `block-pull-request-target` job's bash run-block | mitigate | The run-block uses `set -euo pipefail` (NOT `set -euxo pipefail`). No `set -x`. No secrets are referenced (the workflow has no `secrets.*` access at all under `permissions: contents: read`). Verification: `! grep -qE 'set -[a-z]*x' .github/workflows/actions-lint.yml` exits 0. |
| T-01-03-05 | D (Denial of service) — concurrent runs piling up | Multiple PR pushes amending the same branch | mitigate | The workflow-level `concurrency: cancel-in-progress: true` cancels in-progress runs when a new push lands on the same `${{ github.ref }}`. Verification: `grep -qE 'cancel-in-progress: true' .github/workflows/actions-lint.yml`. |
| T-01-03-06 | S (Spoofing) — fork PR pretending to be base-repo PR | A fork PR that claims to be from the base repo | accept | `pull_request` (NOT `pull_request_target`) means fork PRs run in the FORK's context with no secrets access. Spoofing is irrelevant: even if a fork PR pretends to be from base, the workflow has only `contents: read` and no secret exposure. **Note:** Phase 4's self-test will introduce the fork-skip pattern with `environment: Preview`; that's a different workflow with different threat model. Plan 03's workflow has no secrets, so spoofing has no consequence. |

**ASVS L1 mapping:**
- V14.5 (Validate file type / extension / structure): the LINT-05 grep guard validates workflow YAML for the banned `pull_request_target` trigger.
- V8.3 (Restrict access to sensitive data): no secrets accessed; `permissions: contents: read`.
- V1.6 (Architecture: trust boundaries): documented above. PR ↔ runner is the only boundary; no secrets cross it.
- V1.10 (Architecture: high-impact security controls): the LINT-05 grep guard IS the high-impact control for this phase.

**High-severity threat threshold:** all entries above are mitigated or accepted with explicit rationale. T-01-03-01 (the `pull_request_target` ACE class) is high-severity and mitigated by the LINT-05 grep guard itself; this is the entire purpose of the guard.
</threat_model>

<verification>
Phase-end gates for this plan (run after Task 1 completes):

1. `test -f .github/workflows/actions-lint.yml` exits 0.
2. Three job IDs present: `grep -cE '^[[:space:]]+(actionlint|shellcheck|block-pull-request-target):$' .github/workflows/actions-lint.yml` returns `3`.
3. All three pinned SHAs present byte-exact: combined grep of `de0fac2e4500dabe0009e67214ff5f5447ce83dd`, `6fb7acc99f4a1008869fa8a0f09cfca740837d9d`, `00cae500b08a931fb5698e11e79bfbd38e612a38` all return at least one hit each.
4. No floating tags: `! grep -qE 'uses: [^@[:space:]]+@(main|latest|v[0-9]+(\.[0-9]+)?)([[:space:]]|$)' .github/workflows/actions-lint.yml` exits 0.
5. No `pull_request_target` in this workflow: `! grep -qE '^[[:space:]]*pull_request_target[[:space:]]*:' .github/workflows/actions-lint.yml` exits 0.
6. Workflow-level `permissions: contents: read` and concurrency `cancel-in-progress: true` present.
7. LINT-05 guard cites `PITFALLS.md` and `AGENTS.md` and uses `exit 1` on detection.
</verification>

<success_criteria>
- `.github/workflows/actions-lint.yml` exists with all required structure: workflow `name`, triggers (`pull_request` + `push`), workflow-level `permissions: contents: read`, workflow-level `concurrency: cancel-in-progress: true`, and three parallel jobs (`actionlint`, `shellcheck`, `block-pull-request-target`).
- Each `uses:` line conforms to the SHA + `# vX.Y.Z` pin posture; the three external actions match CLAUDE.md byte-exact.
- The `block-pull-request-target` job greps `.github/workflows/**/*.{yml,yaml}` only, uses both D-10 regex patterns, and emits an `::error::` citing `AGENTS.md` and `PITFALLS.md §2` on detection, with `exit 1`.
- The workflow self-complies: it uses `pull_request` (not `pull_request_target`) so the LINT-05 guard does not flag it.
- All acceptance criteria for Task 1 pass.
- All five LINT requirements (LINT-01..05) covered.
</success_criteria>

<output>
After completion, create `.planning/phases/01-scaffolding-lint/01-03-lint-workflow-SUMMARY.md` documenting:
- File created: `.github/workflows/actions-lint.yml` with byte size.
- Three job IDs and their explicit `name:` fields (used by Plan 04's branch-protection check-name list).
- Three pinned SHAs verified byte-exact against CLAUDE.md.
- Confirmation: workflow uses `pull_request` (NOT `pull_request_target`); the guard self-passes when run on this file.
- Confirmation: `permissions: contents: read` at workflow level; `concurrency: cancel-in-progress: true`.
- Confirmation: LINT-05 grep guard regex patterns match D-10 semantics; error message cites `PITFALLS.md §2` and `AGENTS.md`.
- Note for Plan 04: required check names = `actionlint`, `shellcheck`, `block-pull-request-target` (these go into the branch-protection script).
</output>