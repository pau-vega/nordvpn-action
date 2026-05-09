# Phase 4: Self-test CI - Context

**Gathered:** 2026-05-08
**Status:** Ready for planning

<domain>
## Phase Boundary

Phase 4 delivers `.github/workflows/self-test.yml` — a fork-safe matrix E2E workflow that runs all three regional actions (`nordvpn-es`, `nordvpn-us`, `nordvpn-fr`) on push/PR using local `./actions/...` references, a weekly scheduled cron as drift sentinel, and upgrades `main` branch protection to require self-test checks alongside the existing `actions-lint` checks (TEST-09).

Phase delivers TEST-01..09 (9 requirements). No action code changes. No release tooling.

</domain>

<decisions>
## Implementation Decisions

### Branch Protection Check Naming

- **D-01:** Use standard GitHub matrix naming — required checks are `self-test (nordvpn-es)`, `self-test (nordvpn-us)`, `self-test (nordvpn-fr)`.
- **D-02:** Inline the 3 new check names into the existing `REQUIRED_CHECKS_JSON` array in `scripts/setup-branch-protection.sh`, alongside the 3 existing `actions-lint` checks (6 total). Remove the Phase 4 amendment hint comment.

### Workflow Trigger Scope

- **D-03:** `push: branches: [main]` with path filter `actions/**, .github/workflows/**`.
- **D-04:** `pull_request` with same path filter (`actions/**, .github/workflows/**`). Matches `actions-lint.yml` filter shape.
- **D-05:** `schedule: cron: 0 8 * * 1` — Monday 08:00 UTC. Start of work week catch.
- **D-06:** `workflow_dispatch` with a `region` choice input (`es` / `us` / `fr` / `all`, default `all`). Matrix filters by this input when set.
- **D-07:** No suppression of push runs when a PR triggered — push-to-main is post-merge verification, not redundant with the PR run. Concurrency group prevents session conflict.
- **D-08:** Push path-filtered same as PR. README-only pushes to main skip self-test (no VPN connect waste).

### Drift Issue Behavior

- **D-09:** One issue per schedule run listing all failed regions. Title: `region-drift: nordvpn-es, nordvpn-fr`. Label: `region-drift`.
- **D-10:** Upsert pattern — `gh issue list --label region-drift --state open` to find existing. If found, `gh issue comment` with new failure details. If none, `gh issue create` new. Prevents weekly issue spam.
- **D-11:** Auto-close when next schedule run passes all regions: `gh issue close` with comment "All regions passed on [date]. Closing."
- **D-12:** Issue body content: run URL + list of failed regions. Minimal — maintainer clicks through to run logs for details.
- **D-13:** Use `gh` CLI for all GitHub API operations. Pure Bash, matches repo philosophy, GITHUB_TOKEN auth native.

### Post-Connect Defense-in-Depth

- **D-14:** After the action step succeeds, run a workflow-level `curl -s ipinfo.io/country` asserting the ISO-2 code matches the expected region. One provider only (ipinfo.io) — this is a plumbing test, not a re-validation of the action's two-provider check.
- **D-15:** Assert all 6 action outputs are non-empty and `country` output matches expected ISO-2 code. Tests the full consumer contract: action declares outputs → consumer can read them.

### the agent's Discretion

- Exact workflow YAML structure (job ordering, step grouping, `needs:` wiring)
- Fork-skip guard implementation — separate gate job with `if: github.event.pull_request.head.repo.full_name == github.repository` per research pattern
- Concurrency group composition (`nordvpn-selftest-${{ matrix.region }}-${{ github.ref }}`, `cancel-in-progress: false`)
- Secret propagation from `environment: Preview` to action `inputs.username` / `inputs.password`
- Exact `gh` CLI command invocations for drift issue management
- Matrix region configuration mapping (region → country code, country_id, hostname for geo-assertion)
- Post-connect verification step wording and error messages
- Workflow-level permissions scoping (read-only except drift issue job)

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Project & Requirements
- `.planning/ROADMAP.md` §"Phase 4: Self-test CI" — Goal + 5 success criteria (goal-backward gate)
- `.planning/REQUIREMENTS.md` §"Self-Test CI (TEST-01..09)" — 9 requirements with acceptance criteria
- `.planning/PROJECT.md` — Core value, constraints, key decisions, out-of-scope rationale

### Research Dossier
- `.planning/research/SUMMARY.md` §2 (Stack) — Self-test trigger posture, fork-skip pattern, concurrency group
- `.planning/research/PITFALLS.md` §2 (`pull_request_target` ACE) — Rationale for fork-safety posture
- `.planning/research/STACK.md` — SHA-pinned action references for workflow `uses:` lines

### Prior Phase Context
- `.planning/phases/01-scaffolding-lint/01-CONTEXT.md` §"Branch Protection on `main`" (D-13..D-16) — setup-branch-protection.sh design, required-checks JSON structure, idempotency contract
- `.planning/phases/02-port-nordvpn-es/02-CONTEXT.md` — Action input/output contract (username/password inputs, 6 outputs)
- `.planning/phases/03-mirror-us-fr/03-CONTEXT.md` — Region configuration (country codes, country IDs, hostnames)

### Existing Workflow (pattern reference)
- `.github/workflows/actions-lint.yml` — Established workflow pattern (permissions, concurrency, job naming, path filters, SHA-pinned `uses:`). Self-test.yml should mirror this file's structure and conventions.

### Existing Scripts
- `scripts/setup-branch-protection.sh` — REQUIRED_CHECKS_JSON array to amend with 3 self-test check names (D-02). Script is idempotent and must remain re-runnable.

### External Docs
- `https://docs.github.com/en/actions/using-workflows/events-that-trigger-workflows` — Trigger semantics for `push`, `pull_request`, `schedule`, `workflow_dispatch`
- `https://docs.github.com/en/actions/using-jobs/using-a-matrix-for-your-jobs` — Matrix job name resolution for branch protection naming (D-01)

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `.github/workflows/actions-lint.yml` — Full workflow structure to mirror: `permissions: contents: read`, `concurrency:` block, path-filtered triggers, `runs-on: ubuntu-latest` jobs, SHA-pinned `uses:` with `# vX.Y.Z` comments.
- `scripts/setup-branch-protection.sh` — Branch protection script to amend with 3 new check names. Existing `REQUIRED_CHECKS_JSON` array supports direct extension. Script is idempotent and `gh`-CLI-based.
- `actions/nordvpn-es/action.yml` — Reference for how self-test invokes each action: 2 inputs (`username`, `password`), 6 outputs (`exit-ip`, `country`, `asn`, `tun0-state`, `default-route`, `connect-duration-ms`). Self-test passes `${{ secrets.NORDVPN_SERVICE_USERNAME }}` / `${{ secrets.NORDVPN_SERVICE_PASSWORD }}`.

### Established Patterns
- **SHA-pinning:** All `uses:` lines = 40-char SHA + `# vX.Y.Z` comment. Self-test.yml uses `actions/checkout@de0fac2e4500dabe0009e67214ff5f5447ce83dd # v6.0.2`.
- **Path filtering:** Both `push` and `pull_request` use `paths: ['actions/**', '.github/workflows/**']` — matches actions-lint.yml filter.
- **Concurrency:** `group: <workflow-name>-${{ github.workflow }}-${{ github.ref }}` pattern in actions-lint.yml. Self-test adds `${{ matrix.region }}` dimension.
- **Permissions:** Workflow-level `contents: read` default; escalate per-job where needed (drift issue job needs `issues: write`).
- **Action contract:** `uses: ./actions/nordvpn-${{ matrix.region }}` — local path, not tagged ref. Consumer disconnect pattern: separate step with `if: always()`.

### Integration Points
- `.github/workflows/self-test.yml` is the **second** workflow in the repo alongside `.github/workflows/actions-lint.yml`. Both coexist in `.github/workflows/`.
- Branch protection on `main` currently requires 3 `actions-lint` checks. Phase 4 upgrades to 6 checks (adds 3 self-test matrix checks). The `setup-branch-protection.sh` re-run is the enablement mechanism.
- Phase 5 (`release-please.yml`) will be the third workflow — self-test.yml's structure sets the convention for all future workflows in this repo.
- The drift issue job creates/updates issues on `pau-vega/nordvpn-actions` using `gh` CLI with GITHUB_TOKEN. Needs `permissions: issues: write` on that job only.

</code_context>

<specifics>
## Specific Ideas

- Fork-skip gate job name: `fork-check` (or `fork-guard` — planner decides). Emits `::notice::` on fork skip with explanation of Preview-environment fork-safety posture.
- Matrix key: `region` with values `[es, us, fr]`. Job name auto-resolves to `self-test (nordvpn-es)` etc. via `name: nordvpn-${{ matrix.region }}` or matrix `include:`.
- Workflow dispatch `region` input filters the matrix: `if: inputs.region == 'all' || inputs.region == matrix.region` on each job or filter at matrix level.
- Post-connect verification step reads `steps.<id>.outputs.exit-ip` etc. and asserts `steps.<id>.outputs.country == 'ES'` (or US/FR per region).
- Drift issue job runs after matrix completes (`needs: self-test`, `if: failure() && github.event_name == 'schedule'`). Checks pass status from matrix; creates/updates/closes accordingly.
- `concurrency: group: nordvpn-selftest-${{ matrix.region }}-${{ github.ref }}`, `cancel-in-progress: false` — per the research pattern, prevents session conflicts without interrupting live VPN sessions.

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within Phase 4 scope (self-test CI workflow).

</deferred>

---

*Phase: 04-self-test-ci*
*Context gathered: 2026-05-08*
