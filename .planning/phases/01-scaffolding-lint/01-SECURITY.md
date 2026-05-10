---
phase: 01-scaffolding-lint
slug: scaffolding-lint
status: verified
threats_open: 0
asvs_level: 1
created: 2026-05-10
---

# Phase 01 — Security

> Per-phase security contract: threat register, accepted risks, and audit trail.

---

## Trust Boundaries

| Boundary | Description | Data Crossing |
|----------|-------------|---------------|
| Documentation surface (Plan 01) | LICENSE, README.md, AGENTS.md — no executable surface, no workflow triggers, no inputs from untrusted sources | None |
| Dependabot ↔ repo | Dependabot opens PRs against `main` with proposed dependency upgrades; gated by actions-lint | PR metadata, no secrets |
| CODEOWNERS ↔ PR review | CODEOWNERS auto-assigns `@pau-vega` to PRs touching `/actions/**` | GitHub handle (public) |
| Untrusted PR ↔ workflow runner | PR modifies `.github/workflows/**`; workflow runs from PR HEAD SHA with `pull_request` context, no secrets exposed | Workflow YAML, file contents |
| Workflow runner ↔ GitHub API | Workflow emits `::error::` annotations only; no API writes | Error annotations |
| `block-pull-request-target` ↔ filesystem | Grep scans `.github/workflows/**` file content from checked-out tree | File contents (read-only) |
| Local environment ↔ GitHub API | `gh repo create`, `git push`, `gh api ...protection` mutate the public repo | Maintainer's `gh` auth token |
| Branch protection ↔ future PRs | Every push to `main` must go through PR gated by 3 required checks | PR status check metadata |
| `scripts/setup-branch-protection.sh` ↔ filesystem | Script runs locally, committed to repo | None (local environment) |

---

## Threat Register

| Threat ID | Category | Component | Disposition | Mitigation | Status |
|-----------|----------|-----------|-------------|------------|--------|
| T-01-01-01 | I (Information disclosure) | AGENTS.md, README.md | accept | Documentation must reference secret names (`NORDVPN_SERVICE_USERNAME`, `NORDVPN_SERVICE_PASSWORD`) and locations (`Preview` environment) so consumers can configure correctly. Names are not secrets; values are never written to docs. | closed |
| T-01-01-02 | T (Tampering) | LICENSE | accept | LICENSE text is canonical MIT License (SPDX-recognized). Tampering would only break license auto-detection, not introduce attack surface. | closed |
| T-01-02-01 | E (Elevation of privilege) — supply-chain | `.github/dependabot.yml` Dependabot PRs | mitigate | Dependabot PRs gated by `actions-lint` workflow (actionlint + shellcheck + `block-pull-request-target` grep guard). Grep guard rejects any PR introducing `pull_request_target`. Dependabot updates SHAs atomically. | closed |
| T-01-02-02 | T (Tampering) — silent dependency-confusion | `.github/dependabot.yml` `directories:` list | accept | Full future-region list shipped pre-emptively (7 paths). Phase 2/3 require zero `dependabot.yml` edit. PITFALLS.md §19 captures failure mode. | closed |
| T-01-02-03 | I (Information disclosure) — CODEOWNERS leak | `.github/CODEOWNERS` | accept | Maintainer handle (`@pau-vega`) is public info (repo is public MIT). | closed |
| T-01-02-04 | D (Denial of service) — Dependabot PR flood | `.github/dependabot.yml` `groups: actions: patterns: ["*"]` | mitigate | Batching all action updates into a single weekly PR prevents PR-spam. Default `open-pull-requests-limit: 5` is a backstop. | closed |
| T-01-03-01 | E (Elevation of privilege) — workflow injection / ACE | The workflow itself | mitigate | `block-pull-request-target` job detects any PR introducing `pull_request_target` in `.github/workflows/**`. Two D-10 regex patterns (key form + array-element form). Error message cites `PITFALLS.md §2` and `AGENTS.md §Security Considerations`. Hard fail with `exit 1`. | closed |
| T-01-03-02 | T (Tampering) — bypass guard via comments | Grep guard regex | accept | D-10 regex semantics deliberately exclude comments. YAML triggers are positionally constrained; attackers cannot bypass via comments without breaking workflow functionality. | closed |
| T-01-03-03 | T (Tampering) — replace pinned SHAs | External action pins | mitigate | All `uses:` lines use `<40-char-SHA> # vX.Y.Z` form. Dependabot opens PRs for SHA updates; those PRs go through same `actions-lint` gate. Branch protection requires checks to pass. | closed |
| T-01-03-04 | I (Information disclosure) — secret echo via shell trace | `block-pull-request-target` run-block | mitigate | Run-block uses `set -euo pipefail` (NOT `set -euxo pipefail`). No `set -x`. Workflow has `permissions: contents: read` only — no secrets access. | closed |
| T-01-03-05 | D (Denial of service) — concurrent runs | Workflow concurrency | mitigate | `concurrency: cancel-in-progress: true` cancels in-progress runs on same ref. | closed |
| T-01-03-06 | S (Spoofing) — fork PR pretending to be base-repo PR | `pull_request` trigger | accept | `pull_request` (NOT `pull_request_target`) means fork PRs run in fork's context with no secrets access. Workflow has only `contents: read` — spoofing has no consequence. | closed |
| T-01-04-01 | E (Elevation of privilege) — branch-protection bypass | `enforce_admins` flag | mitigate | Script sets `"enforce_admins": true` — admins cannot bypass required checks. | closed |
| T-01-04-02 | T (Tampering) — malicious modification of `setup-branch-protection.sh` | `scripts/setup-branch-protection.sh` | mitigate | Script committed and version-controlled; modification visible in PR diff. Residual risk: CODEOWNERS does not yet cover `/scripts/**` (flagged for Phase 2+). | closed |
| T-01-04-03 | I (Information disclosure) — `gh` auth token leak via shell trace | `gh api` invocation | mitigate | Script uses `set -euo pipefail`, NOT `set -euxo pipefail`. No `set -x`. `gh` CLI handles auth token storage; script never echoes or transmits token. | closed |
| T-01-04-04 | S (Spoofing) — pretend repo exists | Pre-flight check | accept | Pre-flight checks `gh api repos/${OWNER}/${REPO}` with helpful error. Script is maintainer tool, not a security boundary. | closed |
| T-01-04-05 | D (Denial of service) — branch protection disabled by drift | GitHub UI manual edit | accept | Script is idempotent and committed; re-run after any drift event recovers settings. | closed |
| T-01-04-06 | E (Elevation of privilege) — first push bypassed protection | `git push -u origin main` | accept | First push happens BEFORE protection enabled (unavoidable). First push contains audited Phase 1 scaffold reviewed in Checkpoint A. From Phase 2 onward, all changes go through PRs. | closed |

*Status: open · closed*
*Disposition: mitigate (implementation required) · accept (documented risk) · transfer (third-party)*

---

## Accepted Risks Log

| Risk ID | Threat Ref | Rationale | Accepted By | Date |
|---------|------------|-----------|-------------|------|
| AR-01-01 | T-01-01-01 | Documentation must reference secret names for consumer configuration. Names are not secrets; values never written to docs. | Plan design (D-07) | 2026-04-26 |
| AR-01-02 | T-01-01-02 | Canonical MIT text is pure documentation; tampering only breaks license auto-detection. | Plan design | 2026-04-26 |
| AR-01-03 | T-01-02-02 | Full 7-path list shipped pre-emptively; Phase 2/3 need no edits. PITFALLS.md §19 captures the failure mode. | Plan design (D-08) | 2026-04-26 |
| AR-01-04 | T-01-02-03 | Maintainer handle is public info in a public MIT repo. | Plan design | 2026-04-26 |
| AR-01-05 | T-01-03-02 | D-10 regex semantics deliberately exclude comments. YAML triggers are positionally constrained; attackers cannot bypass. | Plan design (D-10) | 2026-04-26 |
| AR-01-06 | T-01-03-06 | `pull_request` context has no secrets access; workflow has only `contents: read`. | Plan design | 2026-04-26 |
| AR-01-07 | T-01-04-04 | Script is a maintainer tool, not a security boundary. Pre-flight check exists. | Plan design | 2026-04-26 |
| AR-01-08 | T-01-04-05 | Script is idempotent and committed; re-run after drift recovers settings. | Plan design (D-13) | 2026-04-26 |
| AR-01-09 | T-01-04-06 | First push unavoidably bypasses protection (branch doesn't exist remotely yet). Contents audited via Checkpoint A. | Plan design (D-18) | 2026-04-26 |

*Accepted risks do not resurface in future audit runs.*

---

## Security Audit Trail

| Audit Date | Threats Total | Closed | Open | Run By |
|------------|---------------|--------|------|--------|
| 2026-05-10 | 18 | 18 | 0 | gsd-security-auditor (automated) |

---

## Sign-Off

- [x] All threats have a disposition (mitigate / accept / transfer)
- [x] Accepted risks documented in Accepted Risks Log
- [x] `threats_open: 0` confirmed
- [x] `status: verified` set in frontmatter

**Approval:** verified 2026-05-10
