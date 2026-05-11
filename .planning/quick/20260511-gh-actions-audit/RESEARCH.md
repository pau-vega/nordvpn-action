---
name: RESEARCH
type: research
mode: quick-task
date: 2026-05-11
---

# Research: OSS Readiness + GH Actions Best Practices Audit

> **Note on output path:** the focus specified `.planning/quick/260511-fgy-audit-project-for-open-source-readiness-/260511-fgy-RESEARCH.md`, but the freshly-created quick-task directory on disk is `.planning/quick/20260511-gh-actions-audit/`. This RESEARCH.md is written there. The planner should re-target if a renamed directory is desired.

## TL;DR

1. **Marketplace blocker, not just a gap.** GitHub Marketplace lists **only the root-level `action.yml`** of a repo. This monorepo has three composite actions in sub-folders (`actions/nordvpn-{es,us,fr}`) and **no root `action.yml`**, so **none of the three regions can be listed on Marketplace** today regardless of branding. The recent `chore: add branding for GitHub Marketplace` commit (`a4ea045`) sets `branding:` correctly in each sub-folder action, but branding without a root `action.yml` is invisible to Marketplace. Decide explicitly: ship a "meta" root action (discoverability stub), or keep Marketplace deferred and remove the implication that branding alone enables it. ([community discussion #24990](https://github.com/orgs/community/discussions/24990), [GH publishing docs](https://docs.github.com/en/actions/sharing-automations/creating-actions/publishing-actions-in-github-marketplace))
2. **Three MUST-have OSS community-health files are missing:** `SECURITY.md`, `CONTRIBUTING.md`, `CODE_OF_CONDUCT.md`. `SECURITY.md` is the most load-bearing for a credential-handling action — without it, a researcher with a finding has no documented disclosure channel and will default to a public issue. ([GH community health docs](https://docs.github.com/en/communities/setting-up-your-project-for-healthy-contributions/creating-a-default-community-health-file))
3. **Two SHOULD-have supply-chain workflows are missing and apply cleanly:** OpenSSF Scorecard (broad badge-able security posture check) and CodeQL **specifically for GitHub Actions workflow analysis** (CodeQL supports `**/action.yml` and `.github/workflows/*.yml` as a first-class language — this *is* a Bash-only repo but the workflows themselves can still be analyzed). ([CodeQL supported languages](https://codeql.github.com/docs/codeql-overview/supported-languages-and-frameworks/))
4. **README is stale:** declares "Pre-release", marks all three regions as "added when v1.0.0 ships", and the roadmap shows Phase 6 complete. The visitor's first impression contradicts the actual state of the repo. Fix is purely textual.
5. **CI hygiene is already strong**, so refinements are small: missing `timeout-minutes` on VPN jobs (a stuck `tun0` poll + retry could burn 60min runner default), no `step-security/harden-runner` (a single defensible add for an OSS GitHub Action repo), `ubuntu-latest` pin (a deliberate decision to revisit — `ubuntu-latest` flipped 22.04 -> 24.04 in early 2025 and your `apt-get openvpn-systemd-resolved` package name is implicitly relying on this).

---

## 1. OSS Community-Health Gaps

GitHub's "community profile" checker scans `.github/`, repo root, and `docs/` in that priority order ([source](https://docs.github.com/en/communities/setting-up-your-project-for-healthy-contributions/creating-a-default-community-health-file)). Recommendation across this section: put community files in **`.github/`** to keep the repo root focused on consumer-facing docs (README + LICENSE).

### MUST — blocks credible OSS launch

| File | Path | Why MUST | Content shape for THIS repo |
|------|------|----------|------------------------------|
| `SECURITY.md` | `.github/SECURITY.md` | Action handles VPN credentials, runs `sudo`, writes 0600 auth file. A finder needs a non-public channel — repo currently has none. Also a Scorecard signal. | (1) Supported versions table per region (latest minor of each `nordvpn-<region>-v1.x.y`). (2) Private reporting via GitHub "Report a vulnerability" + maintainer email fallback. (3) Explicit "do NOT open a public issue for credential-handling/`pull_request_target`-class bugs" note. (4) SLA shape (acknowledge in N days, fix by). |
| `CONTRIBUTING.md` | `.github/CONTRIBUTING.md` | AGENTS.md is agent-facing and explicitly framed that way. Human contributors need a separate door. Currently README §Contributing punts to AGENTS.md. | (1) Conventional Commit scopes (`feat(nordvpn-es)`, `deps`, etc. — already in AGENTS.md, copy verbatim). (2) "One region per PR" rule. (3) How to run lint locally (`actionlint`, `shellcheck` — already in AGENTS.md). (4) That fork PRs auto-skip self-test and a maintainer must re-run from a trusted branch. (5) Link to AGENTS.md for the deeper architectural rules. |
| `CODE_OF_CONDUCT.md` | `.github/CODE_OF_CONDUCT.md` | GitHub community-profile checklist item; standard expectation; Scorecard signal. | Adopt **Contributor Covenant 2.1** verbatim. Single maintainer contact email under the Enforcement section. |

### SHOULD — expected by community standards

| File | Path | Why SHOULD | Content shape |
|------|------|------------|---------------|
| `.github/ISSUE_TEMPLATE/bug_report.yml` | `.github/ISSUE_TEMPLATE/` | Without this, every issue lands as a free-form text post. For a VPN action where the first 3 things needed are *region, exit-ip ASN, runner Ubuntu version*, structured fields cut triage cost. Use **issue forms** (YAML), not legacy markdown templates — forms are validated, won't drop the diagnostics outputs. | Bug template fields: region (dropdown ES/US/FR), pinned ref (SHA/tag), `ubuntu-*` runner version, all 6 step outputs (paste), full step log excerpt, expected vs actual country. |
| `.github/ISSUE_TEMPLATE/feature_request.yml` | same | Same triage rationale, plus a place to route v2 requests (DIST/REG/AUTO categories in REQUIREMENTS.md) without polluting bugs. | Feature template fields: which region or all, problem statement, proposed approach, links. |
| `.github/ISSUE_TEMPLATE/config.yml` | same | Lets you turn off blank issues and point to Discussions/docs first. Trivial. | `blank_issues_enabled: false`, `contact_links:` to Discussions (if enabled) and to AGENTS.md. |
| `.github/PULL_REQUEST_TEMPLATE.md` | `.github/` | Enforces the "one region per PR" rule + "did you update the right CHANGELOG-owned scope?" check before reviewers touch it. release-please scope rules are easy to forget. | Sections: which region(s), Conventional Commit scope used, did self-test pass on a non-fork branch, breaking-change checkbox. |
| `.github/FUNDING.yml` | `.github/` | Optional — only add if the maintainer actually wants sponsorship. Listed here so the planner consciously decides to skip rather than oversight. | `github: [pau-vega]` if applicable; otherwise drop this row. |

### NICE — polish

| File | Path | Why NICE |
|------|------|----------|
| `.github/SUPPORT.md` | `.github/` | "Where do I get help?" — Discussions vs. paid support vs. nothing. One short paragraph. |
| `.github/DISCUSSIONS_TEMPLATE/` | `.github/` | Only if Discussions is enabled. Probably skip until first community traction. |

---

## 2. Supply-Chain / Marketplace Gaps

### MUST — block Marketplace listing if that's a v1.1 goal

| Item | Status today | Resolution |
|------|--------------|------------|
| **Root-level `action.yml`** | **MISSING** | Marketplace requires a single root `action.yml` per repo ([discussion #24990](https://github.com/orgs/community/discussions/24990); [GH docs](https://docs.github.com/en/actions/sharing-automations/creating-actions/publishing-actions-in-github-marketplace) — "Each repository must contain a single action metadata file (`action.yml` or `action.yaml`) at the root"). Sub-folder `action.yml` files **are not auto-listed**. Two paths: **(a)** ship a thin root `action.yml` that takes a `region: es \| us \| fr` input and dispatches to the per-region implementation (one Marketplace listing, three regions inside) — preserves current per-region tags for SHA pinners. **(b)** Accept Marketplace ineligibility, remove the implication. Decision goes in CONTEXT.md. |
| **Branding present in three places it can't be used** | Verified: `actions/nordvpn-{es,us,fr}/action.yml` all have `branding: icon: lock, color: blue` (commit `a4ea045`). | Sub-folder branding has no Marketplace effect — these fields only matter when the action.yml is at repo root. Don't remove them (they cost nothing), but recognize they're inert until the root-action question is resolved. |

### SHOULD — strong community signals, both can ship in one PR

| Item | Status | Resolution / hint |
|------|--------|-------------------|
| **OpenSSF Scorecard workflow** | MISSING | Add `.github/workflows/scorecard.yml`. Triggers: `branch_protection_rule`, `schedule` (weekly Sat 03:00 UTC to avoid Monday cron contention with self-test), `push` on default. Permissions block at job level: `security-events: write`, `id-token: write`, `contents: read`. Use `ossf/scorecard-action@<SHA> # v2.x` + `github/codeql-action/upload-sarif@<SHA>` to publish. Scorecard's own [README](https://github.com/ossf/scorecard-action) directs to the canonical example at `ossf/scorecard/.github/workflows/scorecard-analysis.yml`. Latest tag at time of research: **v2.4.3** (Sept 2025 — verify before committing). Add the badge to README §1: `[![Scorecard](https://api.securityscorecards.dev/projects/github.com/pau-vega/nordvpn-actions/badge)](https://securityscorecards.dev/viewer/?uri=github.com/pau-vega/nordvpn-actions)`. |
| **CodeQL on GitHub Actions workflow files** | MISSING | CodeQL does **NOT** support Bash ([CodeQL supported languages](https://codeql.github.com/docs/codeql-overview/supported-languages-and-frameworks/) — supported set is C/C++, C#, Go, Java, Kotlin, JavaScript, Python, Ruby, Rust, Swift, TypeScript). **However**, CodeQL has a first-class `actions` language that scans `**/action.yml`, `**/action.yaml`, and `.github/workflows/*.yml`. **This repo benefits — scanning catches workflow-injection / expression-injection / untrusted-input-in-`run:` patterns that actionlint doesn't.** Add `.github/workflows/codeql.yml` with `language: actions`. Skip C/JS/etc. languages — there's no source to analyze in those. |
| **`actions/attest-build-provenance`** | N/A | **Not applicable** to composite-action repos. The action attests built artifacts (binaries, images); composite actions are checked-out source files, not artifacts. Confirmed via [the action's README](https://github.com/actions/attest-build-provenance). Listing here so the planner doesn't add it on the assumption that "all OSS repos should attest." |
| **Marketplace tag immutability** | N/A — Marketplace not listed yet | Once a Marketplace release exists, GitHub auto-enforces tag immutability for the specific version published. Today's `nordvpn-<region>-v<X.Y.Z>` exact tags are *technically* mutable (README §Pin forms is honest about this). No action needed until Marketplace is decided. |
| **Floating major tag posture** | Implemented (Phase 6 — `tag-floating-major` job). | Already correct: force-moves `nordvpn-<region>-v<MAJOR>`. README §Pin forms warns it's mutable by design. No change needed. |

### NICE

| Item | Resolution |
|------|------------|
| **`step-security/harden-runner` egress audit on self-test jobs** | Adds an EDR layer that logs/blocks unexpected egress at runner level. For a workflow whose entire purpose is "connect to one specific external service then verify geo via two more", an `egress-policy: audit` first-step is highly informative for catching future drift. Add as first step in each self-test region job. Latest verified: `step-security/harden-runner@<SHA> # v2.17.0` per their getting-started guide. ([source](https://github.com/step-security/harden-runner)) Mode `audit` first (logs), graduate to `block` after a few clean runs. |

---

## 3. README + Onboarding Gaps

### Root `README.md`

Line-level corrections to the current README (`README.md`, 82 lines):

| Line | Current | Fix |
|------|---------|-----|
| 5 | `**Status:** Pre-release. The repo skeleton ships with this commit; per-region actions land in subsequent phases. See [Roadmap](#roadmap).` | Drop the "Pre-release" framing entirely. Phases 1–6 are complete per `.planning/STATE.md` and `.planning/ROADMAP.md`. Replace with a 1-line status badge row (CI, license, OpenSSF Scorecard, release-please) — see badge block below. |
| 15 | `| `actions/nordvpn-es` ... Ships in v1.0.0 (Phase 2) ... _added when v1.0.0 ships_ \|` | Replace placeholder with `pau-vega/nordvpn-actions/actions/nordvpn-es@nordvpn-es-v<latest>`. release-please-managed manifest is the source of truth (`.release-please-manifest.json`); README should be updated by the release-please PR template or a small CI step on tag publish. |
| 16–17 | Same placeholder for US/FR | Same fix. |
| 74 | `... Six phases: scaffolding & lint (this repo skeleton), nordvpn-es port, ...` | Past tense — "six-phase v1 plan, complete as of 2026-05-10. Roadmap retained for historical context." |
| 76–78 | `## Contributing` punts entirely to AGENTS.md. | Add a one-line "Human contributors: see `.github/CONTRIBUTING.md`. AI agents and tooling: see `AGENTS.md`." |

**Badge block** (insert under H1, above the status paragraph):

```markdown
[![CI](https://github.com/pau-vega/nordvpn-actions/actions/workflows/actions-lint.yml/badge.svg)](https://github.com/pau-vega/nordvpn-actions/actions/workflows/actions-lint.yml)
[![Self-test](https://github.com/pau-vega/nordvpn-actions/actions/workflows/self-test.yml/badge.svg)](https://github.com/pau-vega/nordvpn-actions/actions/workflows/self-test.yml)
[![OpenSSF Scorecard](https://api.securityscorecards.dev/projects/github.com/pau-vega/nordvpn-actions/badge)](https://securityscorecards.dev/viewer/?uri=github.com/pau-vega/nordvpn-actions)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](./LICENSE)
```

Marketplace badge intentionally omitted until the root-action.yml question is resolved (see §2).

### Per-region READMEs (`actions/nordvpn-{es,us,fr}/README.md`)

Verified by reading `actions/nordvpn-es/README.md` — it is **already strong** (Inputs/Outputs/Usage/Versioning/Credential Rotation/Troubleshooting all present). Two gaps:

| Gap | Where | Fix |
|-----|-------|-----|
| **No example `uses:` line with a real published SHA + tag** — line 41 still says `<40-char-SHA> # vX.Y.Z`. | `actions/nordvpn-es/README.md:41`, `actions/nordvpn-es/README.md:48`. Same in US/FR per-region READMEs (assumed — mirror structure). | Substitute the latest release's SHA + tag once a v1.0.0 release exists. release-please's PR template can include a "bump README example" checkbox. |
| **No badge row in per-region READMEs.** A cold visitor landing on `actions/nordvpn-es/README.md` from a Google search has no signal that the action is maintained/passing. | Top of each per-region README. | Add the same 4-badge block as root README, with the `Self-test` badge optionally filtered to a region-specific anchor (`...badge.svg?job=self-test-es` — won't work directly; just link the workflow). |

---

## 4. Workflow / CI Refinements

All three workflows verified by direct read.

### MUST

None. The CI posture is already correct on the load-bearing items (pinned SHAs, least-privilege `permissions: contents: read` at workflow level, `concurrency:` configured, fork-check guard, `pull_request_target` grep-banned).

### SHOULD

| Refinement | Where | Fix |
|------------|-------|-----|
| **`timeout-minutes` on self-test region jobs** | `.github/workflows/self-test.yml` jobs `self-test-es`/`-us`/`-fr` | Currently uses default 360min runner timeout. Realistic upper bound: install (~30s) + connect with 2 attempts × 30s timeout (~60s) + verify (~10s) + disconnect (~10s) = under 3 min. Add `timeout-minutes: 10` per region job. Caps any wedge (e.g., `apt-get` hang, NordVPN API outage) at 10min instead of 6h. |
| **`timeout-minutes` on `release-please` and lint jobs** | Both workflows | Default 360 is excessive. `timeout-minutes: 5` for `release-please-action` (rarely takes > 30s) and the lint workflow's jobs. |
| **`runs-on: ubuntu-22.04` instead of `ubuntu-latest`** | All workflows + composite tests (the regions don't pick the runner — caller does, but our self-test does) | `ubuntu-latest` already flipped 22.04 → 24.04 in early 2025. The `apt-get install openvpn openvpn-systemd-resolved` flow is currently working under 24.04, but pinning explicitly removes one class of "Monday surprise". Caveat: changing self-test's `runs-on` does **not** change what consumers can pin; per-region READMEs already document `ubuntu-latest (22.04 or 24.04)` support. The pin is for *our* CI reproducibility. |
| **`harden-runner` first step in self-test region jobs** | `.github/workflows/self-test.yml` | See §2 NICE. `egress-policy: audit` mode. The audit logs help catch any future "verify-country.sh started talking to a 3rd geo provider we didn't notice." |
| **Scorecard workflow** | New: `.github/workflows/scorecard.yml` | See §2 SHOULD. |
| **CodeQL workflow (actions language only)** | New: `.github/workflows/codeql.yml` | See §2 SHOULD. |

### NICE

| Refinement | Where | Fix |
|------------|-------|-----|
| **`drift-issue` job needs `contents: read`** | `.github/workflows/self-test.yml:241` | Already has `issues: write` — but `gh run view` needs read access to actions. Verify with a manual trigger; may already work via `GITHUB_TOKEN` defaults. |
| **`drift-issue` body uses `\n` which won't render in markdown** | `.github/workflows/self-test.yml:257`, `:264` | `BODY="Run: ${RUN_URL}\nFailed regions/jobs: ${FAILED_JOBS}"` — `\n` is a literal two-character string in bash double-quoted strings, not a newline. Use `$'\n'` or a heredoc. Minor cosmetic bug, but the drift issue this creates is the maintainer's primary signal of regional decay. |
| **actionlint config** | `.github/actionlint.yaml` | Verified: only suppresses the `matrix` false-positive for `${{ matrix.* }}` in `uses:`. Adequate. |
| **Self-test `concurrency:` group includes ref but not workflow name at job level** | self-test.yml lines 57, 121, 182 | Group `self-test-es-${{ github.ref }}` is correct (per-region, per-ref). No change. |
| **Drift issue body should include the workflow run ID for direct link** | self-test.yml | Already present (`RUN_URL`). No change. |

---

## 5. Repo-Hygiene Refactors

### MUST

None.

### SHOULD

| Refactor | Where | Why / hint |
|----------|-------|------------|
| **`.gitignore`** | Repo root — currently absent | A repo with `scripts/`, `.planning/`, and pure Bash still benefits from a minimal `.gitignore` covering `.DS_Store`, `*.swp`, `*.bak`, editor cruft. One-liner per category. Prevents accidental `git add -A` mishaps. |
| **`.editorconfig`** | Repo root | Standardizes the LF/tab/indent rules across shell, YAML, markdown. Three-section file: shell (4-space or tab — match existing), yaml (2-space), md (no trim trailing). Helps drive-by contributors PR cleanly. |
| **`CODEOWNERS` coverage** | `.github/CODEOWNERS` currently scopes only `/actions/**` | Add: `/.github/workflows/** @pau-vega`, `/.planning/** @pau-vega`, `/README.md @pau-vega`, `/AGENTS.md @pau-vega`. Without these, a PR that touches release-please.yml or self-test.yml requires no formal review request — relies on the maintainer noticing. |

### NICE

| Refactor | Where | Why |
|----------|-------|-----|
| **`.gitattributes`** | Repo root | `*.sh text eol=lf` enforces LF on Windows clones — prevents the "CRLF in shell script" class of bug for any future Windows-using contributor. |
| **Labeler workflow** | `.github/labeler.yml` + `.github/workflows/labeler.yml` (uses `actions/labeler@<SHA>`) | Auto-label PRs by path: `region/es` for `actions/nordvpn-es/**`, `ci` for `.github/workflows/**`, etc. Pure quality-of-life. |
| **Stale-issue bot** | `.github/workflows/stale.yml` (`actions/stale@<SHA>`) | At today's traffic level, premature. Revisit when there's a backlog. |
| **`SUPPORT.md`** | `.github/SUPPORT.md` | See §1 NICE. Trivial. |
| **Pre-commit hooks (local)** | `.pre-commit-config.yaml` for shellcheck + actionlint locally | Optional Python toolchain. Project's no-Node stance suggests skipping unless contributors ask. |

---

## 6. Out of Scope — Don't Bother

Items that frequently appear on "OSS readiness" checklists but **don't apply here** — calling them out so the planner doesn't waste a task slot:

| Item | Why not |
|------|---------|
| **Adding tests / test framework** | `self-test.yml` is the end-to-end test, gated on real NordVPN credentials. Adding a unit-test framework (bats, etc.) to a 4-script Bash repo is more ceremony than value at N=3. AGENTS.md §Commands documents the existing test path; that's enough. |
| **Dockerfile / container action variant** | Explicitly out of scope per AGENTS.md ("Pure Bash + composite YAML; no Node, no Docker"). Composite + apt-get is the load-bearing choice. |
| **CodeQL for source languages (C, JS, Python, etc.)** | No source in those languages exists. CodeQL on `actions` language only — see §2. |
| **`actions/attest-build-provenance`** | Composite actions have no build artifacts to attest — see §2. |
| **Renovate** | Dependabot is already configured (`.github/dependabot.yml`) with grouping, `deps:` commit prefix, and full directory coverage. Switching tools is pure churn. |
| **Husky / commitlint** | Pure Bash repo. AGENTS.md explicitly defers `AUTO-01` (commit grep) to v2 with rationale "no Node toolchain tax for v1". Don't re-litigate here. |
| **Monorepo refactor to `_shared/scripts/`** | Explicitly deferred until N=5+ regions per AGENTS.md and ROADMAP.md design notes. Below threshold. |
| **Per-region GitHub Releases automation** | release-please-action already creates per-region GitHub Releases — verified by reading `release-please.yml` + `release-please-config.json` (`separate-pull-requests: true`, `include-component-in-tag: true`). |
| **Branch protection setup checklist** | Already scripted in `scripts/setup-branch-protection.sh` per AGENTS.md §Commands and Phase 4 STATE.md notes. |
| **Marketplace listing badge in README** | Cannot list (no root action.yml) — see §2. Add badge if/when §2 is resolved. |
| **`pull_request_target` enabling for fork CI** | Explicitly banned, hard-blocked in CI, attack rationale documented in `actions-lint.yml:78`. Don't propose. |
| **macOS/Windows self-test matrix expansion** | Scripts are apt-get-based, hard-fail with clear message on non-Linux. AGENTS.md frozen contract. |

---

## Assumptions Log

| # | Claim | Section | Risk if wrong |
|---|-------|---------|---------------|
| A1 | Marketplace listing is a v1.1+ goal worth resolving the root-action.yml question for | §2 | If Marketplace is permanently deferred, §2 MUST item degrades to "remove branding fields" cleanup only. |
| A2 | Single-maintainer status — no separate security committee needed for SECURITY.md | §1 | Low — common pattern for small OSS. |
| A3 | NordVPN's recommendations API has no SLA published, so no incident-response template content can be auto-generated for SECURITY.md | §1 | Low — affects only the "scope of vulnerability" wording. |
| A4 | `ubuntu-latest` is currently 24.04 on GitHub-hosted runners | §4 | Verified by GH changelog up to Jan 2025; if the rollout reverted, the suggestion to pin 22.04 is even stronger. |
| A5 | Per-region US and FR READMEs mirror ES structure (only ES read directly) | §3 | If mirror is incomplete, additional per-region README gaps may exist. Quick `diff` between the three at plan time confirms. |
| A6 | CodeQL `actions` language is generally available (not preview) as of May 2026 | §2 | Verified via CodeQL supported-languages docs; if still preview, gate the suggestion behind a "preview-acceptance" note in CONTEXT.md. |

---

## Priority-ranked planner checklist

For convenience to the planner — a single ordered list across all sections.

**MUST (block credible OSS launch):**
1. `SECURITY.md` (§1)
2. `CONTRIBUTING.md` (§1)
3. `CODE_OF_CONDUCT.md` (§1)
4. README stale-content fixes (§3) — purely textual, high visibility
5. **Decide: Marketplace root-action.yml strategy** (§2) — meta-action or document permanent ineligibility

**SHOULD (community standard, supply-chain hardening):**
6. Issue templates (bug + feature + config) (§1)
7. PR template (§1)
8. OpenSSF Scorecard workflow + badge (§2, §3)
9. CodeQL workflow (actions language only) (§2)
10. `timeout-minutes` on self-test region jobs (§4)
11. Per-region README example `uses:` real-tag fix (§3)
12. CODEOWNERS coverage extension (§5)
13. `.gitignore` + `.editorconfig` (§5)
14. `harden-runner` audit-mode in self-test (§2, §4)
15. Drift-issue `\n` bug fix (§4 NICE — but it's a correctness bug, treat as SHOULD)

**NICE (polish):**
16. `runs-on: ubuntu-22.04` pin (§4) — defensible to defer
17. `.gitattributes` (§5)
18. Labeler workflow (§5)
19. `SUPPORT.md` (§1)
20. `FUNDING.yml` (§1) — only if maintainer wants sponsorship

---

## Sources

- [GitHub: Setting up your project for healthy contributions](https://docs.github.com/en/communities/setting-up-your-project-for-healthy-contributions) — community-profile checklist
- [GitHub: Creating a default community health file](https://docs.github.com/en/communities/setting-up-your-project-for-healthy-contributions/creating-a-default-community-health-file) — file locations (`.github/` > root > `docs/`)
- [GitHub: Publishing actions in GitHub Marketplace](https://docs.github.com/en/actions/sharing-automations/creating-actions/publishing-actions-in-github-marketplace) — root-`action.yml` requirement
- [Community discussion #24990 — multiple actions in one repo](https://github.com/orgs/community/discussions/24990) — Marketplace per-repo limitation + workarounds
- [GitHub: Security hardening for GitHub Actions](https://docs.github.com/en/actions/security-for-github-actions/security-guides/security-hardening-for-github-actions) — least-privilege permissions, SHA pinning
- [OpenSSF Scorecard Action README](https://github.com/ossf/scorecard-action) — workflow shape, permissions block, badge URL
- [CodeQL supported languages and frameworks](https://codeql.github.com/docs/codeql-overview/supported-languages-and-frameworks/) — `actions` is a CodeQL language; Bash is not
- [step-security/harden-runner README](https://github.com/step-security/harden-runner) — EDR for runners, v2.17.0 minimum snippet
- [actions/attest-build-provenance README](https://github.com/actions/attest-build-provenance) — not applicable to composite actions
- [GitHub Changelog: ubuntu-latest will use Ubuntu 24.04](https://github.com/actions/runner-images/issues/10636) — `ubuntu-latest` is a moving target
- [Contributor Covenant 2.1](https://www.contributor-covenant.org/version/2/1/code_of_conduct/) — referenced template for CODE_OF_CONDUCT.md

---

## RESEARCH COMPLETE

**Confidence:** HIGH for §1 (community files), §3 (README diffs — verified directly), §6 (out-of-scope — verified against AGENTS.md). HIGH for §2's Marketplace blocker (verified via GH docs + community discussion). MEDIUM-HIGH for §2's CodeQL applicability (CodeQL `actions` language verified — generally available, but verify it isn't in preview at plan time). MEDIUM for §4's `timeout-minutes` numbers (derived from script-internal poll values; real-world ceiling may differ).
