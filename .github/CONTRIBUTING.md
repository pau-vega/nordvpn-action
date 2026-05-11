# Contributing to `nordvpn-action`

Human contributors: this file. AI agents and Claude Code / GSD tooling: see [`AGENTS.md`](../AGENTS.md) (symlinked from `CLAUDE.md`). The two are intentionally separate — agent-facing rules are deeper and machine-oriented; this file covers what a human PR author needs.

Thank you for considering a contribution. This is a small, intentionally narrow project — three composite GitHub Actions for NordVPN egress in ES/US/FR. The bar for new code is "does it make the existing surface safer, clearer, or more reliable without expanding scope". Drive-by typo fixes and CI hygiene PRs are very welcome.

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
- **Per-region bug fixes.** Single region per PR. Use scope `fix(nordvpn-es)` etc. Do NOT bundle ES + US + FR in one PR — release-please will split the resulting release across multiple PRs and the changelog gets messy.
- **New region (US-CA, DE, etc.).** First open an issue. Adding region 4+ may prompt the shared-scripts refactor that has been deferred since `N=3` — see [`AGENTS.md`](../AGENTS.md) and [`.planning/`](../.planning/).

## What does NOT belong in a PR (please open an issue first)

- New action surface (changing input names, output names, or adding a fourth output channel). The v1 contracts are frozen — see `AGENTS.md` §Frozen v1 contracts.
- Cross-region refactors (moving shared logic to `_shared/scripts/`). Deferred until `N=5+` regions per design notes.
- macOS / Windows runner support. The scripts are `apt-get`-based and exit fast on non-Linux. See `AGENTS.md` §Banned constructs.
- `pull_request_target` reintroduction. Hard-blocked in CI and documented in `AGENTS.md` §Banned constructs.
- Marketplace listing changes. Marketplace eligibility is intentionally deferred — see §Marketplace below.
- Anything that runs Node.js or Docker as part of the action. Composite Bash is a load-bearing choice; the `no Node, no Docker` rule is documented in `AGENTS.md`.

## Conventional Commits

Every commit must follow [Conventional Commits 1.0](https://www.conventionalcommits.org/en/v1.0.0/). release-please depends on the commit history shape — incorrectly typed commits silently fall out of the changelog.

| Type    | Use for                                                       | Example                                                 |
|---------|---------------------------------------------------------------|---------------------------------------------------------|
| `feat`  | New action surface, new region, new output                    | `feat(nordvpn-es): add IPv6 leak check output`          |
| `fix`   | Bug in an existing action's behavior                          | `fix(nordvpn-us): retry on transient API 503`           |
| `docs`  | README, AGENTS.md, this file, action READMEs                  | `docs: clarify pin posture in root README`              |
| `deps`  | Dependency bumps (Dependabot prefix)                          | `deps: bump actions/checkout to v6.0.3`                 |
| `lint`  | Linter config, workflow YAML hygiene, no behavior change      | `lint: enforce permissions block on every job`          |
| `chore` | Everything else that doesn't fit above                        | `chore: relocate community health files to .github/`    |
| `scaf`  | Scaffolding (Phase 1 only — historical, do not reuse)         | `scaf: initial repo layout`                             |

**Scopes:** use the region directory name when the change is region-specific (`feat(nordvpn-es)`, `fix(nordvpn-fr)`). For cross-cutting changes, omit the scope or use the workflow name (`fix(self-test)`, `lint(actionlint)`).

**Breaking changes:** append `!` after the type/scope AND include a `BREAKING CHANGE:` footer. The v1 contracts are frozen, so a breaking change should almost never reach a PR — see §What does NOT belong above.

## Pull request checklist

Before requesting review:

- [ ] Conventional Commit type and scope are correct (see table above).
- [ ] One region per PR (or no region scope at all for cross-cutting changes).
- [ ] `actionlint .github/workflows/*.yml` clean.
- [ ] `shellcheck actions/**/scripts/*.sh` clean.
- [ ] Did NOT hand-edit `.release-please-manifest.json` or `actions/*/CHANGELOG.md` — release-please owns those.
- [ ] All `uses:` lines pin a 40-char SHA + trailing `# vX.Y.Z` comment (Dependabot updates both atomically). No `@main`, no `@v5`.
- [ ] If the change adds a workflow, the workflow has a top-level `permissions:` block and per-job `timeout-minutes`.
- [ ] If the change touches scripts under `actions/**`, no `set -x` was introduced (leaks secrets past GitHub's exact-match masking).

The maintainer will re-run `self-test.yml` from a trusted branch for any non-trivial change before merging — fork PRs cannot reach the `Preview` environment secrets.

## Marketplace

GitHub Marketplace lists only the root-level `action.yml` of a repo. This monorepo has three sub-folder actions and no root `action.yml`, so Marketplace listing is intentionally deferred. The `branding:` blocks present in the per-region `action.yml` files are inert today but cost nothing — they will become live if the maintainer ships a thin root meta-action in a future major.

Do not open a PR adding a root `action.yml` without first opening an issue to discuss the contract (which region is the default, how `region:` input maps to the per-region implementations, how floating-major tags interact with a meta-action tag, etc.).

## Releases

This repo uses [release-please](https://github.com/googleapis/release-please) with `separate-pull-requests: true` and `include-component-in-tag: true`. Each region releases independently. Tags take the form `nordvpn-<region>-v<X.Y.Z>` and the floating major tag `nordvpn-<region>-v<MAJOR>` is force-moved on every release by the `tag-floating-major` job in `release-please.yml`.

Maintainers merge the release-please PR; that triggers the actual tag + release publication. No human edits to `CHANGELOG.md` or `.release-please-manifest.json`.

## Code of conduct

This project adopts the [Contributor Covenant 2.1](./CODE_OF_CONDUCT.md). By participating you agree to abide by its terms.

## License

By contributing you agree your contributions are licensed under the [MIT License](../LICENSE) — the same license as the project.
