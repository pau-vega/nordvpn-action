---
name: SUMMARY
type: summary
mode: quick-task
status: complete
date: 2026-05-11
scope_tier: MUST + SHOULD
marketplace_decision: defer
---

# Summary: OSS Readiness + GitHub Actions Audit

## Scope decision

- **Scope tier:** MUST + SHOULD (user choice).
- **Marketplace root `action.yml`:** deferred (user choice). The three sub-folder actions remain the only listed surface; root meta-action is a v1.1+ discussion to be opened via issue first.
- NICE-tier items skipped (per scope): `runs-on: ubuntu-22.04` pin, `.gitattributes`, labeler workflow, `SUPPORT.md`, `FUNDING.yml`.

## Changes shipped (branch: `chore/oss-readiness`)

| # | Commit | Files | Summary |
|---|--------|-------|---------|
| 1 | `docs: add CODE_OF_CONDUCT.md adopting Contributor Covenant 2.1` | `.github/CODE_OF_CONDUCT.md` | Fixes a 404 link from CONTRIBUTING.md. Adopts CC 2.1 by reference (canonical URL + enforcement routing to the same private channel SECURITY.md uses). |
| 2 | `docs(readme): refresh for OSS launch` | `README.md` | Dropped "Pre-release" framing, added 4-badge row (CI / Self-test / Scorecard / License), replaced placeholder `_added when v1.0.0 ships_` with the real `uses:` form, added §Marketplace (deferred), §Security pointer, split §Contributing into human-vs-agent paths, updated §Roadmap to past tense. |
| 3 | `chore: add community templates and repo hygiene files` | `.github/ISSUE_TEMPLATE/{bug_report,feature_request,config}.yml`, `.github/PULL_REQUEST_TEMPLATE.md`, `.github/CODEOWNERS`, `.gitignore`, `.editorconfig` | Issue forms (validated YAML), PR template with region picker + lint guards, CODEOWNERS extension covering `/.github/**`, `/.planning/**`, docs roots. `.gitignore` + `.editorconfig` for repo hygiene. |
| 4 | `chore(ci): add OpenSSF Scorecard and CodeQL(actions) workflows` | `.github/workflows/scorecard.yml`, `.github/workflows/codeql.yml` | Scorecard on Sat 03:00 UTC cron (offset from Mon self-test); CodeQL `actions` language only on Tue 06:00 UTC. Both SHA-pinned, least-privilege permissions, with `timeout-minutes` and concurrency groups. |
| 5 | `chore(ci): harden workflows — timeout-minutes everywhere, harden-runner audit, drift-issue body fix` | `.github/workflows/self-test.yml`, `.github/workflows/actions-lint.yml`, `.github/workflows/release-please.yml` | Added `timeout-minutes` to every job (10 min for region self-tests; 2–5 min for lint / release-please / drift / fork-check). Added `step-security/harden-runner@v2.19.1 egress-policy: audit` as the first step in each self-test region job. Fixed the drift-issue body bug where `\n` rendered as a literal two-character string in markdown — switched to `printf` with real newlines. |

Five commits, ten new files, six modified files.

## Verification

- `actionlint .github/workflows/*.yml` — clean (exit 0).
- `shellcheck actions/**/scripts/*.sh` — clean (exit 0).
- All ISSUE_TEMPLATE YAML files parse with `yaml.safe_load`.
- All third-party action references are 40-char SHAs with trailing `# vX.Y.Z` comments, fetched and verified via `gh api`:
  - `ossf/scorecard-action@4eaacf0543bb3f2c246792bd56e8cdeffafb205a # v2.4.3`
  - `github/codeql-action@7fd177fa680c9881b53cdab4d346d32574c9f7f4 # v3.35.4`
  - `step-security/harden-runner@a5ad31d6a139d249332a2605b85202e8c0b78450 # v2.19.1`
  - `actions/upload-artifact@043fb46d1a93c77aae656e7c1c64a875d1fc6a0a # v7.0.1`

No existing action surface (inputs/outputs in `actions/**/action.yml`, scripts under `actions/**/scripts/`, frozen v1 contracts) was modified. Self-test contract is unchanged — the harden-runner audit step runs *before* checkout and emits notices only; it does not interpose on the action.

## What was intentionally skipped

| Item | Why |
|------|-----|
| Root `action.yml` meta-action for Marketplace | User chose "Defer" — adds architecture surface v1 deliberately doesn't have. Revisit when discoverability becomes priority. |
| `runs-on: ubuntu-22.04` pin | NICE tier; current `ubuntu-latest` works fine for both 22.04 and 24.04. Worth revisiting if `openvpn-systemd-resolved` package availability changes. |
| Per-region README `<40-char-SHA> # vX.Y.Z` placeholders | Cannot complete until first release-please publishes `nordvpn-<region>-v1.0.0`. Manifest currently at 0.0.0 for every region. Defer to a "post-first-release polish" task. |
| `.gitattributes` (`*.sh text eol=lf`) | NICE tier; superseded operationally by the `.editorconfig` `end_of_line = lf` rule for the same files. |
| Labeler workflow | NICE tier; defer until contributor volume justifies it. |
| `SUPPORT.md`, `FUNDING.yml` | NICE tier; maintainer-preference items, not blockers. |

## Follow-up tasks (for future quick tasks)

1. After the first `nordvpn-es-v1.0.0` release-please publish, update the four `<SHA> # vX.Y.Z` placeholders across README.md and the three per-region READMEs.
2. Once 2–3 weeks of audit-mode harden-runner logs are clean, propose graduating to `egress-policy: block` with an explicit allow-list (NordVPN API + ipinfo.io + ifconfig.co + apt + github).
3. If/when a fourth region is added, re-evaluate the deferred shared-scripts refactor (AGENTS.md §Architecture).
4. Once Scorecard reports a score, decide whether to add `branch-protection`, `pinned-dependencies`, or `dangerous-workflow` policy refinements based on the lowest-scoring checks.
