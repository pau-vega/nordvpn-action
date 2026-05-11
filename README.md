# nordvpn-action

Composite GitHub Actions that route a runner through a NordVPN exit node in a specific country (ES, US, FR) and verify the geo-IP before downstream steps run.

[![CI](https://github.com/pau-vega/nordvpn-action/actions/workflows/actions-lint.yml/badge.svg)](https://github.com/pau-vega/nordvpn-action/actions/workflows/actions-lint.yml)
[![Self-test](https://github.com/pau-vega/nordvpn-action/actions/workflows/self-test.yml/badge.svg)](https://github.com/pau-vega/nordvpn-action/actions/workflows/self-test.yml)
[![OpenSSF Scorecard](https://api.securityscorecards.dev/projects/github.com/pau-vega/nordvpn-action/badge)](https://securityscorecards.dev/viewer/?uri=github.com/pau-vega/nordvpn-action)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](./LICENSE)

The v1 framework is feature-complete — install / connect (with retry) / verify / disconnect for three regions, full self-test workflow, release-please wiring, Dependabot, branch protection. First release tags (`nordvpn-<region>-v1.0.0`) ship via release-please; pin the SHA or the floating-major tag once published.

## Why this exists

A caller adds one `uses:` line and is certain the next steps run from the declared country, or the job fails fast — no hand-written OpenVPN plumbing, no unverified exit IPs.

## Available actions

Three composite actions live under `actions/`. Each pairs with a sibling `disconnect/` sub-action that callers MUST invoke with `if: always()` (composite actions cannot declare `post:` steps — see [community discussion #26743](https://github.com/orgs/community/discussions/26743)).

| Action | Country | `uses:` form |
|--------|---------|--------------|
| [`actions/nordvpn-es`](./actions/nordvpn-es/README.md) | Spain (ES) | `pau-vega/nordvpn-action/actions/nordvpn-es@<SHA> # nordvpn-es-vX.Y.Z` |
| [`actions/nordvpn-us`](./actions/nordvpn-us/README.md) | United States (US) | `pau-vega/nordvpn-action/actions/nordvpn-us@<SHA> # nordvpn-us-vX.Y.Z` |
| [`actions/nordvpn-fr`](./actions/nordvpn-fr/README.md) | France (FR) | `pau-vega/nordvpn-action/actions/nordvpn-fr@<SHA> # nordvpn-fr-vX.Y.Z` |

Replace `<SHA>` with a 40-char commit hash and `vX.Y.Z` with the version that SHA corresponds to. Dependabot keeps both in sync automatically — see [Pin forms](#pin-forms).

## Pin forms

Three ways to pin a `uses:` line, strongest to weakest. Choose based on your reproducibility needs.

### 1. Commit SHA (recommended for release-critical workflows)

```yaml
- uses: pau-vega/nordvpn-action/actions/nordvpn-es@<40-char-SHA> # nordvpn-es-v1.0.0
```

**Use when:** production CI, security-critical workflows, OpenSSF Scorecard "pinned-dependencies" compliance.

**Tradeoff:** byte-exact reproducibility. Update the SHA and the trailing `# vX.Y.Z` comment together — Dependabot does both automatically (configured in `.github/dependabot.yml`).

### 2. Exact version tag

```yaml
- uses: pau-vega/nordvpn-action/actions/nordvpn-es@nordvpn-es-v1.0.0
```

**Use when:** you want a specific version, more readable than a SHA, and you accept that exact tags are technically mutable (release-please does not move them; git permits force-push by a maintainer with write access — this repo does not).

**Tradeoff:** less strict than SHA, more readable.

### 3. Floating major tag (convenience — auto-patch updates)

```yaml
- uses: pau-vega/nordvpn-action/actions/nordvpn-es@nordvpn-es-v1
```

**Use when:** you want auto-bump to the latest patch/minor for major v1 of a region.

**Tradeoff:** **MUTABLE BY DESIGN.** The `nordvpn-es-v1` tag is force-moved to the SHA of every new v1.x.y release by `.github/workflows/release-please.yml` (`tag-floating-major` job). Reproducibility is sacrificed for convenience. Use SHA pinning (form 1) if you cannot tolerate this.

### Never use `@main`

`uses: pau-vega/nordvpn-action/actions/nordvpn-es@main` is **not** a recommended pin form. `main` moves on every merge — your workflow would resolve to whatever code happens to be on `main` at run time, with no version contract. This README does not document `@main` as a supported form. Pinning options are SHA, exact tag, or floating major; nothing else.

## Required setup (consumers)

Every consumer of these actions needs:

1. A `Preview` environment in their repo (Settings → Environments → New environment).
2. Two environment-scoped secrets:
   - `NORDVPN_SERVICE_USERNAME` — dashboard-issued NordVPN service credential username (NOT account email).
   - `NORDVPN_SERVICE_PASSWORD` — dashboard-issued NordVPN service credential password (NOT account password).
3. `runs-on: ubuntu-latest` (Ubuntu 22.04 or 24.04 — macOS and Windows runners are not supported).
4. A paired `disconnect/` step with `if: always()` after any country-gated work.

See each per-action README for full Inputs / Outputs / Usage / Versioning / Credential Rotation / Troubleshooting sections.

## Marketplace

These actions are **not listed on GitHub Marketplace**. Marketplace surfaces a single root-level `action.yml` per repo; this monorepo intentionally ships three sub-folder actions with no root meta-action. Consumers use the actions via the `uses: pau-vega/nordvpn-action/actions/nordvpn-<region>@...` form documented above — Marketplace discoverability is not required for that flow to work.

If you want to discuss adding a root meta-action that dispatches by `region:` input (and would enable a Marketplace listing), open an issue first — see [`.github/CONTRIBUTING.md`](.github/CONTRIBUTING.md) §Marketplace.

## Contributing

- **Human contributors:** see [`.github/CONTRIBUTING.md`](.github/CONTRIBUTING.md) for the human-PR workflow (Conventional Commits, lint commands, one-region-per-PR rule).
- **AI agents / Claude Code / GSD tooling:** see [`AGENTS.md`](./AGENTS.md) for the deeper architectural rules (`CLAUDE.md` is a symlink to the same file).

Code of conduct: this project adopts the [Contributor Covenant 2.1](.github/CODE_OF_CONDUCT.md).

## Security

Report vulnerabilities privately via the GitHub Security Advisory form linked in [`.github/SECURITY.md`](.github/SECURITY.md). Do not open public issues for credential-handling or supply-chain bugs.

## Roadmap

The v1 design is captured in [`.planning/ROADMAP.md`](.planning/ROADMAP.md). The six v1 phases (scaffolding & lint, `nordvpn-es` port, `nordvpn-us` + `nordvpn-fr` mirrors, self-test CI, release-please wiring, floating-major tag automation) are complete; the roadmap is retained for historical context and as the source of truth for v1.1+ scope.

## License

MIT — see [LICENSE](./LICENSE).
