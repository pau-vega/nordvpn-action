# nordvpn-action

Composite GitHub Action that routes a runner through a NordVPN exit node in a selectable country (ES, US, FR) and verifies the geo-IP before downstream steps run.

[![CI](https://github.com/pau-vega/nordvpn-action/actions/workflows/actions-lint.yml/badge.svg)](https://github.com/pau-vega/nordvpn-action/actions/workflows/actions-lint.yml)
[![Self-test](https://github.com/pau-vega/nordvpn-action/actions/workflows/self-test.yml/badge.svg)](https://github.com/pau-vega/nordvpn-action/actions/workflows/self-test.yml)
[![OpenSSF Scorecard](https://api.securityscorecards.dev/projects/github.com/pau-vega/nordvpn-action/badge)](https://securityscorecards.dev/viewer/?uri=github.com/pau-vega/nordvpn-action)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](./LICENSE)

A single composite action that takes a `region:` input and connects the runner through a NordVPN exit node in ES, US, or FR. Install / connect (with retry) / verify / disconnect, full self-test workflow, release-please wiring, Dependabot, branch protection. First release tags (`nordvpn-v1.0.0`) ship via release-please; pin the SHA or the floating-major tag once published.

## Why this exists

A caller adds one `uses:` line and is certain the next steps run from the declared country, or the job fails fast — no hand-written OpenVPN plumbing, no unverified exit IPs.

## Usage

The action takes a required `region:` input (ISO-2 code: `ES`, `US`, or `FR`) plus the NordVPN service credentials. It MUST be paired with a sibling `if: always()` disconnect step — see teardown constraint below.

```yaml
jobs:
  example:
    runs-on: ubuntu-latest
    environment: Preview
    steps:
      - uses: actions/checkout@v6

      - name: Connect NordVPN (ES)
        id: vpn
        uses: pau-vega/nordvpn-action/actions/nordvpn@<40-char-SHA> # nordvpn-vX.Y.Z
        with:
          region: ES
          username: ${{ secrets.NORDVPN_SERVICE_USERNAME }}
          password: ${{ secrets.NORDVPN_SERVICE_PASSWORD }}

      - name: Disconnect VPN
        if: always()
        uses: pau-vega/nordvpn-action/actions/nordvpn/disconnect@<40-char-SHA> # nordvpn-vX.Y.Z
```

See [`actions/nordvpn/README.md`](./actions/nordvpn/README.md) for full Inputs / Outputs / Usage / Versioning / Credential Rotation / Troubleshooting.

## Pin forms

Three ways to pin a `uses:` line, strongest to weakest. Choose based on your reproducibility needs.

### 1. Commit SHA (recommended for release-critical workflows)

```yaml
- uses: pau-vega/nordvpn-action/actions/nordvpn@<40-char-SHA> # nordvpn-v1.0.0
```

**Use when:** production CI, security-critical workflows, OpenSSF Scorecard "pinned-dependencies" compliance.

**Tradeoff:** byte-exact reproducibility. Update the SHA and the trailing `# vX.Y.Z` comment together — Dependabot does both automatically (configured in `.github/dependabot.yml`).

### 2. Exact version tag

```yaml
- uses: pau-vega/nordvpn-action/actions/nordvpn@nordvpn-v1.0.0
```

**Use when:** you want a specific version, more readable than a SHA, and you accept that exact tags are technically mutable (release-please does not move them; git permits force-push by a maintainer with write access — this repo does not).

**Tradeoff:** less strict than SHA, more readable.

### 3. Floating major tag (convenience — auto-patch updates)

```yaml
- uses: pau-vega/nordvpn-action/actions/nordvpn@nordvpn-v1
```

**Use when:** you want auto-bump to the latest patch/minor for major v1.

**Tradeoff:** **MUTABLE BY DESIGN.** The `nordvpn-v1` tag is force-moved to the SHA of every new v1.x.y release by `.github/workflows/release-please.yml` (`tag-floating-major` job). Reproducibility is sacrificed for convenience. Use SHA pinning (form 1) if you cannot tolerate this.

### Never use `@main`

`uses: pau-vega/nordvpn-action/actions/nordvpn@main` is **not** a recommended pin form. `main` moves on every merge — your workflow would resolve to whatever code happens to be on `main` at run time, with no version contract. This README does not document `@main` as a supported form. Pinning options are SHA, exact tag, or floating major; nothing else.

## Required setup (consumers)

Every consumer of this action needs:

1. A `Preview` environment in their repo (Settings → Environments → New environment).
2. Two environment-scoped secrets:
   - `NORDVPN_SERVICE_USERNAME` — dashboard-issued NordVPN service credential username (NOT account email).
   - `NORDVPN_SERVICE_PASSWORD` — dashboard-issued NordVPN service credential password (NOT account password).
3. `runs-on: ubuntu-latest` (Ubuntu 22.04 or 24.04 — macOS and Windows runners are not supported).
4. A paired `disconnect/` step with `if: always()` after any country-gated work.

## Teardown constraint

Composite actions do not support `post:` ([community discussion #26743](https://github.com/orgs/community/discussions/26743)). The caller workflow MUST invoke `./actions/nordvpn/disconnect` as a sibling step with `if: always()` so the OpenVPN daemon and 0600 auth file get cleaned up whether the main action succeeded, failed, or was cancelled.

## Adding a new region

The action currently supports `ES` (Spain, country_id=202), `US` (United States, country_id=228), and `FR` (France, country_id=74). To add another country:

1. Add the ISO-2 code and the NordVPN `country_id` (from `api.nordvpn.com/v1/servers/countries`) to the `case` statement in `actions/nordvpn/scripts/connect.sh`.
2. Add the ISO-2 code to the matrix in `.github/workflows/self-test.yml`.
3. Document the new region in `actions/nordvpn/README.md`.

No new action directory, no new scripts, no new release-please package, no per-region tag scheme.

## Contributing

- **Human contributors:** see [`.github/CONTRIBUTING.md`](.github/CONTRIBUTING.md) for the human-PR workflow (Conventional Commits, lint commands).
- **AI agents / Claude Code / GSD tooling:** see [`AGENTS.md`](./AGENTS.md) for the deeper architectural rules (`CLAUDE.md` is a symlink to the same file).

Code of conduct: this project adopts the [Contributor Covenant 2.1](.github/CODE_OF_CONDUCT.md).

## Security

Report vulnerabilities privately via the GitHub Security Advisory form linked in [`.github/SECURITY.md`](.github/SECURITY.md). Do not open public issues for credential-handling or supply-chain bugs.

## Roadmap

The v1 design is captured in [`.planning/ROADMAP.md`](.planning/ROADMAP.md) (historical — the prior three-region tree was consolidated into a single parameterized action). The roadmap is retained for historical context and as the source of truth for v1.1+ scope.

## License

MIT — see [LICENSE](./LICENSE).
