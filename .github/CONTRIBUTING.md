# Contributing to `nordvpn-action`

Human contributors: this file. AI agents and Claude Code / GSD tooling: see [`AGENTS.md`](../AGENTS.md) (symlinked from `CLAUDE.md`). The two are intentionally separate — agent-facing rules are deeper and machine-oriented; this file covers what a human PR author needs.

Thank you for considering a contribution. This is a small, intentionally narrow project — one composite GitHub Action for NordVPN egress in a selectable country (ES/US/FR). The bar for new code is "does it make the existing surface safer, clearer, or more reliable without expanding scope". Drive-by typo fixes and CI hygiene PRs are very welcome.

## Quick start

```bash
git clone git@github.com:pau-vega/nordvpn-action.git
cd nordvpn-action

# Install local linters (mirrors CI)
brew install actionlint shellcheck jq gh

# Run linters before opening a PR
actionlint .github/workflows/*.yml
shellcheck actions/**/scripts/*.sh
```

End-to-end testing requires `NORDVPN_SERVICE_USERNAME` / `NORDVPN_SERVICE_PASSWORD` configured in the `Preview` environment — not runnable on a fork. The `self-test.yml` workflow skips on fork PRs and the maintainer re-runs from a trusted branch before merging.

## What counts as a good PR

- **Typo, doc, link fix.** Always welcome. Use commit type `docs:` or `chore:`.
- **CI / lint refinements.** Add new lint rules, tighten `permissions:`, fix a workflow bug. Use scope `lint:` or `chore:`.
- **Dependency bumps.** Dependabot handles `github-actions` weekly with grouping. If you have a manual bump for a security reason, label your PR `security` and use `deps:` scope.
- **Bug fixes.** Use scope `fix(nordvpn)` for any change to the action's behavior. The region is encoded in the commit body, not the scope — there is one action, not three.
- **New region (DE, IT, etc.).** First open an issue. Adding a region means (a) extending the `case` statement in `connect.sh`, (b) adding the ISO-2 code to the self-test matrix, and (c) documenting it. No new directory, no new scripts, no new release-please package.

## What does NOT belong in a PR (please open an issue first)

- New action surface (changing input names, output names, or adding a fourth output channel). The v1 contracts are frozen — see `AGENTS.md` §Frozen v1 contracts.
- macOS / Windows runner support. The scripts are `apt-get`-based and exit fast on non-Linux. See `AGENTS.md` §Banned constructs.
- `pull_request_target` reintroduction. Hard-blocked in CI and documented in `AGENTS.md` §Banned constructs.
- Anything that runs Node.js or Docker as part of the action. Composite Bash is a load-bearing choice; the `no Node, no Docker` rule is documented in `AGENTS.md`.
- Splitting the action back into per-region trees. The single parameterized action is the deliberate design — see `AGENTS.md` §Architecture.

## Conventional Commits

Every commit must follow [Conventional Commits 1.0](https://www.conventionalcommits.org/en/v1.0.0/). release-please depends on the commit history shape — incorrectly typed commits silently fall out of the changelog.

| Type    | Use for                                                       | Example                                                 |
|---------|---------------------------------------------------------------|---------------------------------------------------------|
| `feat`  | New action surface, new region, new output                    | `feat(nordvpn): add DE region (country_id=81)`          |
| `fix`   | Bug in the action's behavior                                  | `fix(nordvpn): retry on transient API 503`              |
| `docs`  | README, AGENTS.md, this file, action READMEs                  | `docs: clarify pin posture in root README`              |
| `deps`  | Dependency bumps (Dependabot prefix)                          | `deps: bump actions/checkout to v6.0.3`                 |
| `lint`  | Linter config, workflow YAML hygiene, no behavior change      | `lint: enforce permissions block on every job`          |
| `chore` | Everything else that doesn't fit above                        | `chore: relocate community health files to .github/`    |
| `scaf`  | Scaffolding (Phase 1 only — historical, do not reuse)         | `scaf: initial repo layout`                             |

**Scopes:** use `nordvpn` for any change to the action, the workflow name for CI changes (`fix(self-test)`, `lint(actionlint)`), or omit the scope for cross-cutting changes.

**Breaking changes:** append `!` after the type/scope AND include a `BREAKING CHANGE:` footer. The v1 contracts are frozen, so a breaking change should almost never reach a PR — see §What does NOT belong above.

## Pull request checklist

Before requesting review:

- [ ] Conventional Commit type and scope are correct (see table above).
- [ ] `actionlint .github/workflows/*.yml` clean.
- [ ] `shellcheck actions/**/scripts/*.sh` clean.
- [ ] Did NOT hand-edit `.release-please-manifest.json` or `actions/*/CHANGELOG.md` — release-please owns those.
- [ ] All `uses:` lines pin a 40-char SHA + trailing `# vX.Y.Z` comment (Dependabot updates both atomically). No `@main`, no `@v5`.
- [ ] If the change adds a workflow, the workflow has a top-level `permissions:` block and per-job `timeout-minutes`.
- [ ] If the change touches scripts under `actions/**`, no `set -x` was introduced (leaks secrets past GitHub's exact-match masking).

The maintainer will re-run `self-test.yml` from a trusted branch for any non-trivial change before merging — fork PRs cannot reach the `Preview` environment secrets.

## Releases

This repo uses [release-please](https://github.com/googleapis/release-please) with `separate-pull-requests: true` and `include-component-in-tag: true`. The single `nordvpn` package releases on every conventional commit that lands under `actions/nordvpn/**`. Tags take the form `nordvpn-vX.Y.Z` and the floating major tag `nordvpn-v<MAJOR>` is force-moved on every release by the `tag-floating-major` job in `release-please.yml`.

Maintainers merge the release-please PR; that triggers the actual tag + release publication. No human edits to `CHANGELOG.md` or `.release-please-manifest.json`.

## Code of conduct

This project adopts the [Contributor Covenant 2.1](./CODE_OF_CONDUCT.md). By participating you agree to abide by its terms.

## License

By contributing you agree your contributions are licensed under the [MIT License](../LICENSE) — the same license as the project.
