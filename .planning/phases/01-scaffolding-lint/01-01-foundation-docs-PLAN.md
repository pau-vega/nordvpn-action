---
phase: 01-scaffolding-lint
plan: 01
type: execute
wave: 1
depends_on: []
files_modified:
  - LICENSE
  - README.md
  - AGENTS.md
autonomous: true
requirements:
  - SCAF-01
  - SCAF-02
  - SCAF-03
  - SCAF-06
must_haves:
  truths:
    - "A first-time visitor at the repo root sees a LICENSE (MIT) — satisfies success criterion 1."
    - "A visitor reads root README.md and finds a table indexing every shipped action (placeholder rows for nordvpn-es/us/fr — empty list state allowed) — satisfies success criterion 1 + SCAF-02."
    - "A visitor reads root README.md and finds a section explaining the three pin forms (SHA, exact tag nordvpn-<region>-vX.Y.Z, floating major nordvpn-<region>-v<MAJOR>) with when-to-use guidance — satisfies success criterion 1 + SCAF-03."
    - "A contributor (human or AI agent) reads AGENTS.md and finds, without guessing, the rules for Conventional-Commit scopes, fork-safety posture, composite post:-unavailable + sibling disconnect/ contract, Ubuntu-only runner constraint, and service-credentials-only auth requirement — satisfies success criterion 5 + SCAF-06."
  artifacts:
    - path: "LICENSE"
      provides: "MIT license text at repo root with copyright (c) 2026 Pau Velasco"
      contains: "MIT License"
    - path: "README.md"
      provides: "Root index of shipped actions + three-pin-form chapter"
      contains: "Available actions"
    - path: "AGENTS.md"
      provides: "Contributor guide for humans and AI agents covering all 11 canonical sections (D-07)"
      contains: "## For AI Agents"
  key_links:
    - from: "README.md"
      to: "AGENTS.md"
      via: "markdown link"
      pattern: "\\[AGENTS\\.md\\]\\(\\./AGENTS\\.md\\)"
    - from: "AGENTS.md §Security Considerations"
      to: ".planning/research/PITFALLS.md §2"
      via: "rationale citation"
      pattern: "pull_request_target"
---

<objective>
Create the three repo-front-door documentation artifacts that a first-time visitor or contributor sees: LICENSE (MIT), root README.md (with the action index + three-pin-form chapter), and AGENTS.md (the canonical contributor guide for humans and AI agents).

Purpose: These three files are what a public, MIT-licensed, portfolio-quality repo MUST ship before any code or CI exists. They establish the legal posture (MIT), the consumer mental model (pin forms), and the contributor contract (Conventional Commits, fork safety, composite-action mechanics, Ubuntu-only, service-credentials-only).

Output: `LICENSE`, `README.md`, `AGENTS.md` at repo root, all committed.

Covers requirements: SCAF-01, SCAF-02, SCAF-03, SCAF-06.
</objective>

<execution_context>
@$HOME/.claude/get-shit-done/workflows/execute-plan.md
@$HOME/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@CLAUDE.md
@.planning/PROJECT.md
@.planning/REQUIREMENTS.md
@.planning/ROADMAP.md
@.planning/phases/01-scaffolding-lint/01-CONTEXT.md
@.planning/research/SUMMARY.md
@.planning/research/STACK.md
@.planning/research/ARCHITECTURE.md
@.planning/research/PITFALLS.md

<key_facts>
<!-- Source-of-truth values copied verbatim so executor does not have to re-derive. -->

Repo identity:
- Owner: pau-vega
- Repo name (target on GitHub): nordvpn-actions (plural — current local dir is `nordvpn-action` singular; renamed in Plan 04)
- License: MIT
- Copyright holder: Pau Velasco
- Copyright year: 2026 (pulled from environment date 2026-04-26)

Action index (SCAF-02):
- Three regions ship in v1: nordvpn-es (Phase 2), nordvpn-us (Phase 3), nordvpn-fr (Phase 3).
- Phase 1 ships placeholder rows; Phases 2/3 flip rows to "Available" with real `uses:` examples.
- Each row links (or eventually links) to actions/nordvpn-<region>/README.md (those READMEs do not yet exist; rows can use a "Phase 2 / v1.0.0" status note instead of a broken link, OR a link that 404s pre-Phase-2 — the latter is acceptable for placeholder text).

Three pin forms (SCAF-03 — copy verbatim into the chapter):

  1. **SHA pin** (recommended for release-critical workflows):
     `uses: pau-vega/nordvpn-actions/actions/nordvpn-es@<40-char-SHA> # nordvpn-es-v1.0.0`
     Use when: production CI, security-critical workflows, OpenSSF Scorecard "pinned-dependencies" compliance.
     Tradeoff: bytes-exact reproducibility — caller MUST update the SHA + comment together (Dependabot does this automatically).

  2. **Exact version tag** (recommended for typical workflows):
     `uses: pau-vega/nordvpn-actions/actions/nordvpn-es@nordvpn-es-v1.0.0`
     Use when: you want a specific version and accept that the tag is technically mutable (release-please does not move exact tags after publish, but git permits force-push by a malicious maintainer).
     Tradeoff: less strict than SHA, more readable than SHA.

  3. **Floating major tag** (convenience — auto-patch updates):
     `uses: pau-vega/nordvpn-actions/actions/nordvpn-es@nordvpn-es-v1`
     Use when: you want auto-bump to the latest patch/minor for major v1.
     Tradeoff: MUTABLE BY DESIGN. The tag `nordvpn-es-v1` is force-moved to the SHA of every new v1.x.y release. Reproducibility is sacrificed for convenience. NEVER use `@main` (no such recommendation in this repo).

  IMPORTANT: NEVER use `@main` anywhere in your `uses:` line — see PITFALLS.md §23.

AGENTS.md canonical sections (D-07 — cover ALL of these in this order):
  1. ## Project Overview
  2. ## Development Environment
  3. ## Build and Test Commands
  4. ## Code Style
  5. ## Testing Instructions
  6. ## Release Process
  7. ## Security Considerations
  8. ## PR Guidelines
  9. ## For AI Agents
  10. ## Installation
  11. ## Alternatives Considered

SCAF-06 mandatory topics in AGENTS.md (must each be present somewhere in the doc):
  a. Conventional-Commit scope rules (per-region scope: `feat(nordvpn-es):`, `fix(nordvpn-us):`, `feat(nordvpn-fr):`; for Phase 1 only, scopes `scaf` / `lint` / `chore` / `docs` because no regions exist yet).
  b. Fork-safety posture: self-test workflow uses `pull_request` not `pull_request_target`; fork PRs skip with `::notice::`; rationale = PITFALLS.md §2 ACE class.
  c. Composite `post:` unavailability + sibling `disconnect/` contract: composite actions cannot use `post:`; every region ships a sibling `disconnect/` sub-action that the consumer invokes with `if: always()`.
  d. Ubuntu-only runner constraint: scripts use `apt-get` + systemd-resolved; macOS/Windows runners are not supported.
  e. Service-credentials-only auth: NordVPN account email/password does NOT authenticate against manual OpenVPN; only dashboard-issued service credentials work, stored as `NORDVPN_SERVICE_USERNAME` / `NORDVPN_SERVICE_PASSWORD` in a GitHub `Preview` environment.

Style guidance (D-08): terse instruction list — short imperative bullets, code blocks for commands, minimal narrative. No "why" paragraphs. Optimized for AI-agent skim.

Build/test commands stub (Phase 1 only; expanded in Phases 2/3):
- `actionlint .` (workflow lint — runs once `.github/workflows/actions-lint.yml` exists in Plan 03)
- `shellcheck actions/**/scripts/*.sh` (no-op in Phase 1; will produce real output in Phase 2)

Excluded badges (D-06): NO CI badge, NO OpenSSF Scorecard badge, NO release/version badge. License badge OK (static SVG from shields.io is acceptable but not required). Phase 4 adds CI badge; Phase 5 adds release badge.
</key_facts>

<interfaces>
<!-- Repo is empty; nothing to extract from existing code. Source-of-truth artifacts are referenced above. -->
</interfaces>
</context>

<tasks>

<task type="auto">
  <name>Task 1: Write LICENSE (MIT) at repo root</name>
  <files>LICENSE</files>
  <read_first>
    - .planning/PROJECT.md (constraint: "MIT" + "public" — confirms license choice)
    - .planning/phases/01-scaffolding-lint/01-CONTEXT.md (decision D-02: license file lands locally before remote create)
    - CLAUDE.md (project section: "A public, MIT-licensed monorepo")
  </read_first>
  <action>
    Create `LICENSE` at repo root with the canonical MIT License text. Use the standard SPDX-recognized form (the exact text published at https://opensource.org/licenses/MIT) so GitHub auto-detects it as MIT in the repo sidebar.

    Exact content (copy verbatim, replacing year and holder):

    ```
    MIT License

    Copyright (c) 2026 Pau Velasco

    Permission is hereby granted, free of charge, to any person obtaining a copy
    of this software and associated documentation files (the "Software"), to deal
    in the Software without restriction, including without limitation the rights
    to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
    copies of the Software, and to permit persons to whom the Software is
    furnished to do so, subject to the following conditions:

    The above copyright notice and this permission notice shall be included in all
    copies or substantial portions of the Software.

    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
    IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
    FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
    AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
    LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
    OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
    SOFTWARE.
    ```

    No leading whitespace. File ends with a single trailing newline. No additional sections, no third-party copyright lines (this is a fresh first-party repo).
  </action>
  <verify>
    <automated>test -f LICENSE && grep -qE '^MIT License$' LICENSE && grep -qE '^Copyright \(c\) 2026 Pau Velasco$' LICENSE && grep -qE 'WITHOUT WARRANTY OF ANY KIND' LICENSE</automated>
  </verify>
  <acceptance_criteria>
    - `test -f LICENSE` exits 0 (file exists at repo root, not under any subdirectory).
    - `grep -qE '^MIT License$' LICENSE` exits 0 (first non-blank line is exactly "MIT License").
    - `grep -qE '^Copyright \(c\) 2026 Pau Velasco$' LICENSE` exits 0 (copyright line present, year 2026, holder Pau Velasco).
    - `grep -qE 'WITHOUT WARRANTY OF ANY KIND' LICENSE` exits 0 (warranty disclaimer present — confirms full MIT body, not just the header).
    - `wc -l LICENSE` returns at least 19 (full MIT text is 21 lines including the blank line after "Copyright" and the trailing newline).
    - File contains no leading whitespace on the "MIT License" header line: `head -n 1 LICENSE | grep -qE '^MIT License$'` exits 0.
  </acceptance_criteria>
  <done>LICENSE file exists at repo root with the exact MIT License text, copyright (c) 2026 Pau Velasco. GitHub will auto-detect MIT once pushed.</done>
</task>

<task type="auto">
  <name>Task 2: Write root README.md (action index + three-pin-form chapter)</name>
  <files>README.md</files>
  <read_first>
    - .planning/PROJECT.md (Core value, constraints, three-pin-form convention)
    - .planning/REQUIREMENTS.md (SCAF-02 + SCAF-03 acceptance criteria)
    - .planning/phases/01-scaffolding-lint/01-CONTEXT.md (D-05: rich README from start; D-06: NO CI/Scorecard/release badges)
    - .planning/research/STACK.md (pin-posture rationale)
    - .planning/research/PITFALLS.md (pitfalls 12 and 23: floating-major mutability, no @main)
    - CLAUDE.md (project section + tech stack chapter)
  </read_first>
  <action>
    Create `README.md` at repo root. Required structure (use these exact section headings in this order):

    ```markdown
    # nordvpn-actions

    Composite GitHub Actions that route a runner through a NordVPN exit node in a specific country (ES, US, FR) and verify the geo-IP before downstream steps run.

    > **Status:** Pre-release. The repo skeleton ships with this commit; per-region actions land in subsequent phases. See [ROADMAP](#roadmap).

    ## Why this exists

    A caller can add one `uses:` line and be certain the next steps run from the declared country, or the job fails fast — no hand-written OpenVPN plumbing, no unverified exit IPs.

    ## Available actions

    | Action | Country | Status | `uses:` example |
    |--------|---------|--------|-----------------|
    | [`actions/nordvpn-es`](./actions/nordvpn-es/README.md) | Spain (ES) | Ships in v1.0.0 (Phase 2) | _added when v1.0.0 ships_ |
    | [`actions/nordvpn-us`](./actions/nordvpn-us/README.md) | United States (US) | Ships in v1.0.0 (Phase 3) | _added when v1.0.0 ships_ |
    | [`actions/nordvpn-fr`](./actions/nordvpn-fr/README.md) | France (FR) | Ships in v1.0.0 (Phase 3) | _added when v1.0.0 ships_ |

    Every region ships a paired sibling `disconnect/` sub-action; consumers MUST invoke it with `if: always()` (composite actions cannot use `post:` — see [community discussion #26743](https://github.com/orgs/community/discussions/26743) and [AGENTS.md](./AGENTS.md)).

    ## Pin forms

    Three ways to pin a `uses:` line, strongest to weakest. Choose based on your reproducibility needs.

    ### 1. Commit SHA (recommended for release-critical workflows)

    ```yaml
    - uses: pau-vega/nordvpn-actions/actions/nordvpn-es@<40-char-SHA> # nordvpn-es-v1.0.0
    ```

    **Use when:** production CI, security-critical workflows, OpenSSF Scorecard "pinned-dependencies" compliance.

    **Tradeoff:** byte-exact reproducibility. Update the SHA and the trailing `# vX.Y.Z` comment together — Dependabot does both automatically once `.github/dependabot.yml` is configured.

    ### 2. Exact version tag

    ```yaml
    - uses: pau-vega/nordvpn-actions/actions/nordvpn-es@nordvpn-es-v1.0.0
    ```

    **Use when:** you want a specific version, more readable than a SHA, and you accept that exact tags are technically mutable (release-please does not move them; git permits force-push by a maintainer with write access — this repo does not).

    **Tradeoff:** less strict than SHA, more readable.

    ### 3. Floating major tag (convenience — auto-patch updates)

    ```yaml
    - uses: pau-vega/nordvpn-actions/actions/nordvpn-es@nordvpn-es-v1
    ```

    **Use when:** you want auto-bump to the latest patch/minor for major v1 of a region.

    **Tradeoff:** **MUTABLE BY DESIGN.** The `nordvpn-es-v1` tag is force-moved to the SHA of every new v1.x.y release. Reproducibility is sacrificed for convenience. Use SHA pinning (form 1) if you cannot tolerate this.

    ### Never use `@main`

    `uses: pau-vega/nordvpn-actions/actions/nordvpn-es@main` is **not** a recommended pin form. `main` moves on every merge — your workflow would resolve to whatever code happens to be on `main` at run time, with no version contract. This README does not document `@main` as a supported form. Pinning options are SHA, exact tag, or floating major; nothing else.

    ## Required setup (consumers)

    Every consumer of these actions needs:

    1. A `Preview` environment in their repo (Settings → Environments → New environment).
    2. Two environment-scoped secrets:
       - `NORDVPN_SERVICE_USERNAME` — dashboard-issued NordVPN service credential username (NOT account email).
       - `NORDVPN_SERVICE_PASSWORD` — dashboard-issued NordVPN service credential password (NOT account password).
    3. `runs-on: ubuntu-latest` (Ubuntu 22.04 or 24.04 — macOS and Windows runners are not supported).
    4. A paired `disconnect/` step with `if: always()` after any country-gated work.

    See each per-action README for full Inputs / Outputs / Usage / Versioning / Credential Rotation / Troubleshooting sections (those READMEs ship with their respective region in v1.0.0).

    ## Roadmap

    See [ROADMAP](.planning/ROADMAP.md) for the full v1 plan. Six phases: scaffolding & lint (this repo skeleton), nordvpn-es port, nordvpn-us + nordvpn-fr mirrors, self-test CI, release-please wiring, floating-major tag automation.

    ## Contributing

    See [AGENTS.md](./AGENTS.md) for contributor guidelines (Conventional Commits, fork-safety posture, composite-action mechanics, Ubuntu-only constraint, service-credentials-only auth).

    ## License

    MIT — see [LICENSE](./LICENSE).
    ```

    DO NOT add: CI status badges, OpenSSF Scorecard badge, release/version badges, "build passing" badges (D-06 — those ship in Phase 4 / Phase 5 once the underlying workflows / releases exist; broken-badge UX is unacceptable). License badge from shields.io is permitted but NOT required — omit unless trivially adding doesn't fight the no-broken-badges rule.

    DO NOT recommend `@main` anywhere (PITFALLS.md §23).

    Ensure the file ends with a single trailing newline.
  </action>
  <verify>
    <automated>test -f README.md && grep -qE '^# nordvpn-actions$' README.md && grep -qE '^## Available actions$' README.md && grep -qE '^## Pin forms$' README.md && grep -qE '### 1\. Commit SHA' README.md && grep -qE '### 2\. Exact version tag' README.md && grep -qE '### 3\. Floating major tag' README.md && grep -qE 'nordvpn-es' README.md && grep -qE 'nordvpn-us' README.md && grep -qE 'nordvpn-fr' README.md && grep -qE 'NORDVPN_SERVICE_USERNAME' README.md && grep -qE 'NORDVPN_SERVICE_PASSWORD' README.md && grep -qE 'if: always\(\)' README.md && grep -qE 'AGENTS\.md' README.md && grep -qE 'LICENSE' README.md && ! grep -qE '@main' README.md && ! grep -qE '!\[CI\]' README.md && ! grep -qE '!\[Scorecard\]' README.md</automated>
  </verify>
  <acceptance_criteria>
    - `test -f README.md` exits 0.
    - `grep -qE '^# nordvpn-actions$' README.md` exits 0 (H1 title present).
    - `grep -qE '^## Available actions$' README.md` exits 0 (action index section present — SCAF-02).
    - `grep -qE '^## Pin forms$' README.md` exits 0 (three-pin-form chapter present — SCAF-03).
    - `grep -qE '### 1\. Commit SHA' README.md` exits 0 (pin form 1 documented).
    - `grep -qE '### 2\. Exact version tag' README.md` exits 0 (pin form 2 documented).
    - `grep -qE '### 3\. Floating major tag' README.md` exits 0 (pin form 3 documented).
    - `grep -qE '\bnordvpn-es\b' README.md && grep -qE '\bnordvpn-us\b' README.md && grep -qE '\bnordvpn-fr\b' README.md` all exit 0 (all three regions listed in the action table).
    - `grep -qE 'NORDVPN_SERVICE_USERNAME' README.md && grep -qE 'NORDVPN_SERVICE_PASSWORD' README.md` exit 0 (consumer setup documents service credentials by exact name).
    - `grep -qE 'if: always\(\)' README.md` exits 0 (disconnect contract referenced — D-07 compliance preview).
    - `grep -qE '\bAGENTS\.md\b' README.md` exits 0 (link to contributor guide present).
    - `grep -qE '\bLICENSE\b' README.md` exits 0 (license link present).
    - `! grep -qE '@main' README.md` exits 0 (NEVER recommend `@main` — PITFALLS.md §23).
    - `! grep -E '!\[CI\]|!\[Build\]|!\[Scorecard\]|!\[Release\]' README.md` exits 0 (no CI/build/Scorecard/release badges per D-06).
    - `wc -l README.md` returns at least 60 lines (rich content, not a stub).
  </acceptance_criteria>
  <done>README.md indexes all three regions in v1, documents the three pin forms with when-to-use guidance, references service credentials and `if: always()`, links to AGENTS.md and LICENSE, and contains zero `@main` recommendations or CI/Scorecard/release badges.</done>
</task>

<task type="auto">
  <name>Task 3: Write AGENTS.md (full canonical section list, terse instruction list style)</name>
  <files>AGENTS.md</files>
  <read_first>
    - .planning/REQUIREMENTS.md (SCAF-06 mandatory topics)
    - .planning/phases/01-scaffolding-lint/01-CONTEXT.md (D-07: full canonical section list; D-08: terse style; specifics: for-AI-Agents bans pull_request_target everywhere)
    - .planning/PROJECT.md (constraints: composite-only, Ubuntu-only, service credentials only, no post:)
    - .planning/research/PITFALLS.md (especially §1 sibling-disconnect, §2 pull_request_target, §13 Ubuntu-only, §17 service credentials)
    - CLAUDE.md (tech stack chapter — AGENTS.md section list)
  </read_first>
  <action>
    Create `AGENTS.md` at repo root. Use the EXACT canonical section list from D-07, in this order, each as an H2 heading. Each section uses terse instruction-list style (D-08): short imperative bullets, code blocks for commands, minimal prose, NO "why" paragraphs.

    Required structure (these exact H2 headings, in this order):

    1. `## Project Overview`
    2. `## Development Environment`
    3. `## Build and Test Commands`
    4. `## Code Style`
    5. `## Testing Instructions`
    6. `## Release Process`
    7. `## Security Considerations`
    8. `## PR Guidelines`
    9. `## For AI Agents`
    10. `## Installation`
    11. `## Alternatives Considered`

    Section content requirements:

    ### `## Project Overview`
    - 1-3 bullets: what this is (composite GitHub Actions monorepo for NordVPN ES/US/FR egress), consumer reference form (`pau-vega/nordvpn-actions/actions/nordvpn-<region>@<ref>`), pairs with sibling `disconnect/`.

    ### `## Development Environment`
    - Required local tools: `git`, `gh` (GitHub CLI), `actionlint`, `shellcheck`, `jq`.
    - macOS install: `brew install actionlint shellcheck jq gh`.
    - No Node, no Docker, no Python.

    ### `## Build and Test Commands`
    - List the Phase 1 commands (these will work after Plan 03 ships actions-lint.yml):
      - `actionlint .github/workflows/*.yml` — lint workflows locally.
      - `shellcheck actions/**/scripts/*.sh` — lint shell scripts (no-op until Phase 2 ships scripts).
    - Note: end-to-end self-test (Phase 4) requires NordVPN service credentials; not runnable locally.

    ### `## Code Style`
    - Bash: `set -euo pipefail` at top of every script; never `set -x` (PITFALLS.md §6 — leaks secrets).
    - YAML: 2-space indent.
    - Workflow `uses:` lines: 40-char SHA + ` # vX.Y.Z` comment. NEVER float a tag (`@main`, `@v5`).
    - Composite `action.yml`: hyphenated input/output names (`nordvpn-username`, not `nordvpn_username`).
    - Conventional Commits required from commit #1: `type(scope): subject`.

    ### `## Testing Instructions`
    - Lint runs on every PR via `.github/workflows/actions-lint.yml` (Plan 03 of Phase 1 ships this).
    - Self-test runs on push to `main` and non-fork PRs only (Phase 4).
    - Fork PRs skip self-test cleanly with a `::notice::` — they cannot reach `Preview` environment secrets, by design.

    ### `## Release Process`
    - Conventional Commits drive release-please (Phase 5).
    - One release PR per region (`separate-pull-requests: true`).
    - Tag format: `nordvpn-<region>-vX.Y.Z`. Floating major: `nordvpn-<region>-v<MAJOR>` (force-moved per release; mutable by design).
    - Branch protection on `main` is enabled by `scripts/setup-branch-protection.sh` (Plan 04 of Phase 1 ships this); rerun after any check-name change.
    - DO NOT hand-edit `.release-please-manifest.json` or `actions/*/CHANGELOG.md` — release-please owns them.

    ### `## Security Considerations`
    - All `uses:` references in this repo's own workflows are SHA-pinned (40-char SHA + `# vX.Y.Z` comment). No floating tags. Justification: OpenSSF Scorecard "pinned-dependencies" + Dependabot updates both atomically.
    - This repo BANS `pull_request_target` everywhere in `.github/workflows/**`. The CI grep guard in `.github/workflows/actions-lint.yml` (Plan 03) hard-fails any PR introducing it. Rationale: arbitrary code execution + secret exfiltration class. See `.planning/research/PITFALLS.md §2` for the full attack surface (timescale/pgai GHSA-89qq-hgvp-x37m, hackerbot-claw April 2026 campaign — 475+ malicious PRs in 26h).
    - NordVPN service credentials live in the `Preview` environment as `NORDVPN_SERVICE_USERNAME` and `NORDVPN_SERVICE_PASSWORD`. Account email/password DO NOT authenticate against manual OpenVPN — service credentials only (NordVPN disabled email/password auth on 2023-06-14).
    - Auth file written to `$RUNNER_TEMP/nordvpn-auth.txt` at mode `0600` via `install -m 0600`. Removed by the sibling `disconnect/` action.
    - No `set -x` in any shipped script. Step outputs are never derived from secret values.
    - Composite actions on `ubuntu-latest` only: scripts use `apt-get` + `systemd-resolved`. macOS/Windows runners are not supported; the action fails fast with a clear "Ubuntu runner required" error if `$RUNNER_OS != "Linux"`.

    ### `## PR Guidelines`
    - Commit format: `type(scope): subject` where `type` is one of `feat | fix | docs | refactor | perf | deps | revert | chore | test | ci | style | build`.
    - Phase 1 scopes: `scaf` / `lint` / `chore` / `docs` (no per-region scope yet — no regions exist).
    - Phase 2+ scopes: per-region (`nordvpn-es` / `nordvpn-us` / `nordvpn-fr`). One region per PR when possible — release-please scopes per package path; mixing regions in one PR splits across multiple release PRs.
    - PRs touching `actions/**` or `.github/workflows/**` are auto-validated by `actions-lint` (Plan 03 of Phase 1).
    - Branch protection on `main` requires `actions-lint` checks to pass (Plan 04 of Phase 1). Phase 4 amends to also require `self-test` matrix jobs.

    ### `## For AI Agents`
    - **Run `actionlint` and `shellcheck` locally before pushing.** CI runs them on PR; local pre-flight saves a round trip.
    - **Use Conventional Commits from commit #1.** release-please depends on commit history shape; do not retrofit.
    - **DO NOT touch `.release-please-manifest.json` or `actions/*/CHANGELOG.md`.** release-please owns them; manual edits cause merge conflicts on the next release PR.
    - **DO NOT commit secrets, ever.** No `NORDVPN_SERVICE_PASSWORD` in any file, even encrypted. Use the `Preview` environment.
    - **DO NOT add `pull_request_target` to ANY workflow in this repo, ever.** Not in workflow files, not in inline comments, not as a "simple fix" for fork PR self-test gaps. The grep guard in `actions-lint.yml` blocks it; bypass attempts will fail CI. If a future need genuinely requires fork-PR feedback, use the split-workflow pattern (`pull_request` + `workflow_run`) — never `pull_request_target`. See `.planning/research/PITFALLS.md §2`.
    - **Pin all `uses:` lines by SHA + `# vX.Y.Z` comment.** Use the four canonical SHAs from `CLAUDE.md` (release-please-action, checkout, action-actionlint, action-shellcheck). Floating tags fail OpenSSF Scorecard.
    - **Composite actions cannot use `post:`.** Every region MUST ship a sibling `disconnect/` sub-action (`actions/nordvpn-<region>/disconnect/`). Consumers invoke it with `if: always()`. This is the contract; do not "fix" it by trying to fold disconnect into the main action.
    - **Ubuntu-only.** Scripts use `apt-get`. Do not add macOS or Windows compatibility shims; the action fails fast with `RUNNER_OS != "Linux"` as a feature.

    ### `## Installation`
    - No language toolchain required (pure Bash composite-action repo).
    - Optional local toolchain (mirrors CI):
      ```bash
      brew install actionlint shellcheck jq gh
      ```

    ### `## Alternatives Considered`
    - JavaScript/Docker actions: rejected. Composite is sufficient and minimal; no runtime/toolchain to version. Composite-no-`post:` constraint is the only friction, addressed via sibling `disconnect/`.
    - `commitlint` / husky: rejected. Pure-Bash repo doesn't justify a Node toolchain. Social enforcement via PR review for v1; CI grep is v2 (see `.planning/REQUIREMENTS.md §AUTO-01`).
    - `_shared/scripts/` abstraction: rejected at N=3 regions. Triplicate scripts + CI drift-check (Phase 3) is cheaper than the release-please scoping complications a shared dir introduces. Revisit at N=5+.
    - `pull_request_target` with allowlist: rejected. Allowlists add complexity without proportional safety benefit; one misconfigured allowlist check leaks secrets. See `.planning/research/PITFALLS.md §2`.

    Style: every section is bullets and code blocks. No flowing prose paragraphs. If a sentence runs >25 words, split it.

    File ends with a single trailing newline.
  </action>
  <verify>
    <automated>test -f AGENTS.md && grep -qE '^## Project Overview$' AGENTS.md && grep -qE '^## Development Environment$' AGENTS.md && grep -qE '^## Build and Test Commands$' AGENTS.md && grep -qE '^## Code Style$' AGENTS.md && grep -qE '^## Testing Instructions$' AGENTS.md && grep -qE '^## Release Process$' AGENTS.md && grep -qE '^## Security Considerations$' AGENTS.md && grep -qE '^## PR Guidelines$' AGENTS.md && grep -qE '^## For AI Agents$' AGENTS.md && grep -qE '^## Installation$' AGENTS.md && grep -qE '^## Alternatives Considered$' AGENTS.md && grep -qE 'feat\(nordvpn-' AGENTS.md && grep -qE 'pull_request_target' AGENTS.md && grep -qE 'PITFALLS\.md' AGENTS.md && grep -qE 'if: always\(\)' AGENTS.md && grep -qE 'sibling.*disconnect' AGENTS.md && grep -qE 'ubuntu-latest' AGENTS.md && grep -qE 'NORDVPN_SERVICE_USERNAME' AGENTS.md && grep -qE 'NORDVPN_SERVICE_PASSWORD' AGENTS.md && grep -qE 'Preview' AGENTS.md && grep -qE 'service credential' AGENTS.md</automated>
  </verify>
  <acceptance_criteria>
    - `test -f AGENTS.md` exits 0.
    - All 11 canonical H2 section headings present in order — verified by individual greps:
      - `grep -qE '^## Project Overview$' AGENTS.md`
      - `grep -qE '^## Development Environment$' AGENTS.md`
      - `grep -qE '^## Build and Test Commands$' AGENTS.md`
      - `grep -qE '^## Code Style$' AGENTS.md`
      - `grep -qE '^## Testing Instructions$' AGENTS.md`
      - `grep -qE '^## Release Process$' AGENTS.md`
      - `grep -qE '^## Security Considerations$' AGENTS.md`
      - `grep -qE '^## PR Guidelines$' AGENTS.md`
      - `grep -qE '^## For AI Agents$' AGENTS.md`
      - `grep -qE '^## Installation$' AGENTS.md`
      - `grep -qE '^## Alternatives Considered$' AGENTS.md`
    - SCAF-06 mandatory topic (a) Conventional-Commit scope rules: `grep -qE 'feat\(nordvpn-' AGENTS.md` exits 0 (per-region scope example present).
    - SCAF-06 mandatory topic (b) fork-safety posture: `grep -qE 'pull_request_target' AGENTS.md` exits 0 AND `grep -qE 'PITFALLS\.md' AGENTS.md` exits 0 (rationale citation present).
    - SCAF-06 mandatory topic (c) composite-`post:`-unavailable + sibling disconnect/: `grep -qE 'if: always\(\)' AGENTS.md` exits 0 AND `grep -qE 'sibling.*disconnect' AGENTS.md` exits 0.
    - SCAF-06 mandatory topic (d) Ubuntu-only runner constraint: `grep -qE 'ubuntu-latest' AGENTS.md` exits 0.
    - SCAF-06 mandatory topic (e) service-credentials-only: `grep -qE 'NORDVPN_SERVICE_USERNAME' AGENTS.md` exits 0 AND `grep -qE 'NORDVPN_SERVICE_PASSWORD' AGENTS.md` exits 0 AND `grep -qE 'service credential' AGENTS.md` exits 0 AND `grep -qE 'Preview' AGENTS.md` exits 0.
    - "For AI Agents" section explicitly bans `pull_request_target`: `awk '/^## For AI Agents$/,/^## Installation$/' AGENTS.md | grep -qE 'pull_request_target'` exits 0.
    - File >= 100 lines (`wc -l AGENTS.md` returns at least 100): forward-loaded coverage of 11 sections + 5 mandatory topics produces substantial content.
  </acceptance_criteria>
  <done>AGENTS.md exists at repo root with all 11 canonical sections in order, all 5 SCAF-06 mandatory topics covered, terse instruction-list style throughout, and an explicit ban on `pull_request_target` in the "For AI Agents" section with a citation to PITFALLS.md §2.</done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| Documentation surface only | This plan creates LICENSE, README.md, AGENTS.md — no executable surface, no workflow triggers, no inputs from untrusted sources. |

## STRIDE Threat Register

| Threat ID | Category | Component | Disposition | Mitigation Plan |
|-----------|----------|-----------|-------------|-----------------|
| T-01-01-01 | I (Information disclosure) | AGENTS.md, README.md | accept | Documentation must reference secret names (`NORDVPN_SERVICE_USERNAME`, `NORDVPN_SERVICE_PASSWORD`) and locations (`Preview` environment) so consumers can configure correctly. Names are not secrets; values are never written to docs. Acceptance criteria for AGENTS.md / README.md include the literal secret-name strings, but never any value. Reviewer verifies via `grep -E 'NORDVPN_SERVICE_USERNAME' AGENTS.md` returns the variable name, not a value. |
| T-01-01-02 | T (Tampering) | LICENSE | accept | LICENSE text is the canonical MIT License (SPDX-recognized). Tampering would only break license auto-detection on GitHub, not introduce attack surface. Verification: `grep -qE '^MIT License$' LICENSE && grep -qE 'WITHOUT WARRANTY OF ANY KIND' LICENSE`. |

**Rationale:** Plan 01 produces documentation only. No executable surface, no workflow triggers, no script invocations, no secret handling. The threat model is N/A in the practical sense; the entries above are completeness placeholders. The substantive threat models live in Plan 02 (Dependabot), Plan 03 (lint workflow + grep guard), and Plan 04 (branch protection).
</threat_model>

<verification>
Phase-end gates for this plan (run after all three tasks complete):

1. `test -f LICENSE && test -f README.md && test -f AGENTS.md` exits 0 — all three artifacts present.
2. `grep -qE '^MIT License$' LICENSE` exits 0 — license auto-detected.
3. `grep -qE '^## Available actions$' README.md && grep -qE '^## Pin forms$' README.md` exits 0 — SCAF-02 + SCAF-03 satisfied.
4. `grep -cE '^## ' AGENTS.md` returns >= 11 — all 11 canonical sections present (D-07).
5. `! grep -qE '@main' README.md` exits 0 — no `@main` recommendations.
6. `! grep -qE '!\[CI\]|!\[Build\]|!\[Scorecard\]' README.md` exits 0 — no broken-badge UX (D-06).
</verification>

<success_criteria>
- LICENSE, README.md, AGENTS.md exist at repo root.
- LICENSE is canonical MIT, copyright (c) 2026 Pau Velasco.
- README.md indexes nordvpn-es / nordvpn-us / nordvpn-fr in an "Available actions" table with status notes (placeholder rows allowed) AND documents all three pin forms (SHA / exact tag / floating major) with when-to-use guidance AND warns against `@main`.
- AGENTS.md contains all 11 canonical H2 sections in order AND covers all 5 SCAF-06 mandatory topics AND explicitly bans `pull_request_target` everywhere in the "For AI Agents" section.
- All three files end with a single trailing newline.
- All acceptance criteria for Tasks 1, 2, 3 pass.
</success_criteria>

<output>
After completion, create `.planning/phases/01-scaffolding-lint/01-01-foundation-docs-SUMMARY.md` documenting:
- Files created (LICENSE, README.md, AGENTS.md) with exact byte sizes.
- Action index table contents (3 placeholder rows for ES/US/FR).
- AGENTS.md section list confirming all 11 sections present.
- Any deviations from the byte-exact action text (none expected).
- Confirmation that `@main` does not appear in README.md.
</output>