# AGENTS.md

Contributor guide for humans and AI agents working in `pau-vega/nordvpn-actions`.

---

## Project Overview

- Composite GitHub Actions monorepo: `actions/nordvpn-es`, `actions/nordvpn-us`, `actions/nordvpn-fr`.
- Consumer reference form: `pau-vega/nordvpn-actions/actions/nordvpn-<region>@<ref>`.
- Every region pairs with a sibling `disconnect/` sub-action (`actions/nordvpn-<region>/disconnect/`).
- Consumers MUST invoke `disconnect/` with `if: always()` — composite actions cannot use `post:`.

---

## Development Environment

Required local tools:

- `git` — version control.
- `gh` — GitHub CLI (repo create, branch protection, issue/PR management).
- `actionlint` — workflow YAML linter.
- `shellcheck` — Bash script linter.
- `jq` — JSON processor (used in release scripts and verification).

macOS install:

```bash
brew install actionlint shellcheck jq gh
```

No Node. No Docker. No Python.

---

## Build and Test Commands

Lint workflows locally (mirrors CI):

```bash
actionlint .github/workflows/*.yml
```

Lint shell scripts locally (no-op until Phase 2 ships scripts):

```bash
shellcheck actions/**/scripts/*.sh
```

End-to-end self-test requires NordVPN service credentials in the `Preview` environment. Not runnable locally — runs in CI (Phase 4).

---

## Code Style

- **Bash:** `set -euo pipefail` at top of every script. Never `set -x` — it leaks secrets to logs.
- **YAML:** 2-space indent.
- **Workflow `uses:` lines:** 40-char SHA + ` # vX.Y.Z` comment. Never float a tag (`@main`, `@v5`, `@latest`).
- **Composite `action.yml`:** hyphenated input/output names (`nordvpn-username`, not `nordvpn_username`).
- **Conventional Commits** required from commit #1: `type(scope): subject`.
- Phase 1 scopes: `scaf`, `lint`, `chore`, `docs`.
- Phase 2+ scopes: per-region (`nordvpn-es`, `nordvpn-us`, `nordvpn-fr`).

---

## Testing Instructions

- Lint (`actionlint` + `shellcheck`) runs on every PR via `.github/workflows/actions-lint.yml` (Phase 1, Plan 3).
- Self-test workflow runs on push to `main` and on non-fork PRs only (Phase 4).
- Fork PRs skip self-test with a `::notice::` — they cannot reach `Preview` environment secrets by design.
- To test locally before pushing, run `actionlint` and `shellcheck` commands from **Build and Test Commands** above.

---

## Release Process

- Conventional Commits drive release-please (Phase 5). One release PR per region (`separate-pull-requests: true`).
- Tag format: `nordvpn-<region>-vX.Y.Z`. Floating major: `nordvpn-<region>-v<MAJOR>` (force-moved per release).
- DO NOT hand-edit `.release-please-manifest.json` or `actions/*/CHANGELOG.md` — release-please owns them.
- Branch protection on `main` is set by `scripts/setup-branch-protection.sh` (Phase 1, Plan 4). Rerun after any check-name change.
- Per-region scopes required: `feat(nordvpn-es):`, `fix(nordvpn-us):`, `feat(nordvpn-fr):` — these drive independent version bumps per region.

---

## Security Considerations

- All `uses:` references in this repo's own workflows are SHA-pinned (40-char SHA + `# vX.Y.Z` comment). No floating tags. Justification: OpenSSF Scorecard "pinned-dependencies" check; Dependabot updates both SHA and comment atomically.
- **`pull_request_target` is BANNED everywhere in `.github/workflows/**`.** The CI grep guard in `.github/workflows/actions-lint.yml` (Plan 3) hard-fails any PR introducing it. Rationale: `pull_request_target` runs the workflow from the base ref with full secrets access; combined with checkout of a PR head SHA = arbitrary code execution (ACE) + secret exfiltration. See `.planning/research/PITFALLS.md §2` for the full attack surface (timescale/pgai GHSA-89qq-hgvp-x37m; hackerbot-claw April 2026 campaign — 475+ malicious PRs in 26 hours).
- NordVPN service credentials live in the `Preview` environment as `NORDVPN_SERVICE_USERNAME` and `NORDVPN_SERVICE_PASSWORD`. Account email/password DO NOT authenticate against manual OpenVPN — only dashboard-issued service credentials work (NordVPN disabled email/password auth on 2023-06-14).
- Auth file written to `$RUNNER_TEMP/nordvpn-auth.txt` at mode `0600` via `install -m 0600`. Removed by the sibling `disconnect/` action on teardown.
- Never use `set -x` in any shipped script. Step outputs must never be derived from secret values.
- Composite actions on `ubuntu-latest` only: scripts use `apt-get` + `systemd-resolved`. macOS/Windows runners are not supported — the action fails fast with a clear "Ubuntu runner required" error if `$RUNNER_OS != "Linux"`.

---

## PR Guidelines

- Commit format: `type(scope): subject`. Type is one of: `feat | fix | docs | refactor | perf | deps | revert | chore | test | ci | style | build`.
- Phase 1 scopes: `scaf` / `lint` / `chore` / `docs` (no per-region scope — no regions exist yet).
- Phase 2+ scopes: per-region (`nordvpn-es` / `nordvpn-us` / `nordvpn-fr`). One region per PR when possible — mixing regions in one PR splits across multiple release PRs.
- PRs touching `actions/**` or `.github/workflows/**` are auto-validated by `actions-lint` (Phase 1, Plan 3).
- Branch protection on `main` requires `actions-lint` checks to pass (Phase 1, Plan 4). Phase 4 amends to also require `self-test` matrix jobs.
- Fork contributors: open a PR from your fork. Maintainer pulls to a trusted branch for a full self-test run. Fork PRs cannot reach `Preview` environment secrets by design.

---

## For AI Agents

- **Run `actionlint` and `shellcheck` locally before pushing.** CI runs them on PR; local pre-flight saves a round trip.
- **Use Conventional Commits from commit #1.** release-please depends on commit history shape; do not retrofit.
- **DO NOT touch `.release-please-manifest.json` or `actions/*/CHANGELOG.md`.** release-please owns them; manual edits cause merge conflicts on the next release PR.
- **DO NOT commit secrets, ever.** No `NORDVPN_SERVICE_PASSWORD` in any file, even encrypted. Use the `Preview` environment.
- **DO NOT add `pull_request_target` to ANY workflow in this repo, ever.** Not in workflow files, not in inline comments, not as a "simple fix" for fork PR self-test gaps. The grep guard in `actions-lint.yml` blocks it; bypass attempts fail CI. If a future need genuinely requires fork-PR feedback, use the split-workflow pattern (`pull_request` + `workflow_run`) — never `pull_request_target`. See `.planning/research/PITFALLS.md §2`.
- **Pin all `uses:` lines by SHA + `# vX.Y.Z` comment.** Use the four canonical SHAs from `CLAUDE.md` (release-please-action, checkout, action-actionlint, action-shellcheck). Floating tags fail OpenSSF Scorecard.
- **Composite actions cannot use `post:`.** Every region MUST ship a sibling `disconnect/` sub-action (`actions/nordvpn-<region>/disconnect/`). Consumers invoke it with `if: always()`. Do not attempt to fold disconnect into the main action.
- **Ubuntu-only.** Scripts use `apt-get`. Do not add macOS or Windows compatibility shims — the action fails fast with `RUNNER_OS != "Linux"` as a feature, not a bug.

---

## Installation

No language toolchain required (pure Bash composite-action repo).

Optional local toolchain (mirrors CI):

```bash
brew install actionlint shellcheck jq gh
```

---

## Alternatives Considered

- **JavaScript/Docker actions:** rejected. Composite is sufficient and minimal; no runtime or toolchain to version. The composite no-`post:` constraint is the only friction; addressed via sibling `disconnect/`.
- **`commitlint` / husky:** rejected. Pure-Bash repo does not justify a Node toolchain. Social enforcement via PR review for v1; CI grep is v2 (see `.planning/REQUIREMENTS.md AUTO-01`).
- **`_shared/scripts/` abstraction:** rejected at N=3 regions. Triplicate scripts + CI drift-check (Phase 3) is cheaper than the release-please scoping complications a shared directory introduces. Revisit at N=5+.
- **`pull_request_target` with allowlist:** rejected. Allowlists add complexity without proportional safety benefit; one misconfigured allowlist check leaks secrets. See `.planning/research/PITFALLS.md §2`.
- **macOS/Windows runner support:** rejected for v1. Scripts are `apt-get`-based; cross-OS abstraction is disproportionate work. Ubuntu-only constraint is documented as intentional.
