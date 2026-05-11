# nordvpn-action

Composite GitHub Actions that route a runner through a NordVPN exit node in a specific country (ES, US, FR) and verify the geo-IP before downstream steps run.

> **Status:** Pre-release. The repo skeleton ships with this commit; per-region actions land in subsequent phases. See [Roadmap](#roadmap).

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
- uses: pau-vega/nordvpn-action/actions/nordvpn-es@<40-char-SHA> # nordvpn-es-v1.0.0
```

**Use when:** production CI, security-critical workflows, OpenSSF Scorecard "pinned-dependencies" compliance.

**Tradeoff:** byte-exact reproducibility. Update the SHA and the trailing `# vX.Y.Z` comment together — Dependabot does both automatically once `.github/dependabot.yml` is configured.

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

**Tradeoff:** **MUTABLE BY DESIGN.** The `nordvpn-es-v1` tag is force-moved to the SHA of every new v1.x.y release. Reproducibility is sacrificed for convenience. Use SHA pinning (form 1) if you cannot tolerate this.

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

See each per-action README for full Inputs / Outputs / Usage / Versioning / Credential Rotation / Troubleshooting sections (those READMEs ship with their respective region in v1.0.0).

## Roadmap

See [ROADMAP](.planning/ROADMAP.md) for the full v1 plan. Six phases: scaffolding & lint (this repo skeleton), nordvpn-es port, nordvpn-us + nordvpn-fr mirrors, self-test CI, release-please wiring, floating-major tag automation.

## Contributing

See [AGENTS.md](./AGENTS.md) for contributor guidelines (Conventional Commits, fork-safety posture, composite-action mechanics, Ubuntu-only constraint, service-credentials-only auth).

## License

MIT — see [LICENSE](./LICENSE).
