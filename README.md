# nordvpn-action

Composite GitHub Action that routes a runner through a NordVPN exit node in a selectable country (ES, US, FR) and verifies the geo-IP before downstream steps run.

[![CI](https://github.com/pau-vega/nordvpn-action/actions/workflows/actions-lint.yml/badge.svg)](https://github.com/pau-vega/nordvpn-action/actions/workflows/actions-lint.yml)
[![Self-test](https://github.com/pau-vega/nordvpn-action/actions/workflows/self-test.yml/badge.svg)](https://github.com/pau-vega/nordvpn-action/actions/workflows/self-test.yml)
[![OpenSSF Scorecard](https://api.securityscorecards.dev/projects/github.com/pau-vega/nordvpn-action/badge)](https://securityscorecards.dev/viewer/?uri=github.com/pau-vega/nordvpn-action)
[![OpenSSF Best Practices](https://www.bestpractices.dev/projects/13174/badge)](https://www.bestpractices.dev/projects/13174)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](./LICENSE)

A single composite action that takes a `region:` input and connects the runner through a NordVPN exit node in ES, US, or FR. Install / connect (with retry) / verify / disconnect, full self-test workflow, release-please wiring, Dependabot, branch protection. First release tags (`nordvpn-v1.0.0`) ship via release-please; pin the SHA or the floating-major tag once published.

## Why this exists

A caller adds one `uses:` line and is certain the next steps run from the declared country, or the job fails fast — no hand-written OpenVPN plumbing, no unverified exit IPs.

## Inputs

| Name | Required | Description |
|------|----------|-------------|
| `region` | yes | ISO-2 country code for the exit node. Supported: `ES` (Spain, country_id=202), `US` (United States, country_id=228), `FR` (France, country_id=74). |
| `username` | yes | NordVPN service username. In consumer repos, sourced from a `Preview` environment secret like `NORDVPN_SERVICE_USERNAME`. |
| `password` | yes | NordVPN service password. In consumer repos, sourced from a `Preview` environment secret like `NORDVPN_SERVICE_PASSWORD`. |

NordVPN **service** credentials are required — NordVPN account email/password does NOT work with manual OpenVPN. Generate service credentials from the NordVPN web dashboard.

## Outputs

| Name | Description |
|------|-------------|
| `exit-ip` | Public IPv4 after tunnel up (NordVPN exit gateway in the selected country). |
| `country` | ISO-2 country code of exit IP; guaranteed to match the `region` input on action success. |
| `asn` | ASN/ISP of the exit gateway (string). |
| `tun0-state` | Human-readable tunnel state: `up` or `down-or-missing`. |
| `default-route` | Active IPv4 default route after connect (string). |
| `connect-duration-ms` | Wall-clock time from openvpn invocation to tun0 IPv4 assigned, in milliseconds. |

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
        uses: pau-vega/nordvpn-action@<40-char-SHA> # nordvpn-vX.Y.Z
        with:
          region: ES
          username: ${{ secrets.NORDVPN_SERVICE_USERNAME }}
          password: ${{ secrets.NORDVPN_SERVICE_PASSWORD }}

      - name: Disconnect VPN
        if: always()
        uses: pau-vega/nordvpn-action/disconnect@<40-char-SHA> # nordvpn-vX.Y.Z
```

See the Inputs, Outputs, Internal Steps, Credential Rotation, Versioning, and Troubleshooting sections below.

## Internal Steps

The composite runs four sequential steps:

1. **Install** — `apt-get install openvpn openvpn-systemd-resolved`, asserts `curl`/`jq`/`openvpn` are on PATH.
2. **Connect (bounded retry)** — up to 2 attempts: writes service credentials to `$RUNNER_TEMP/nordvpn-auth.txt` at 0600, resolves a live openvpn_udp server in the selected country via NordVPN's public recommendations API, starts `openvpn --daemon` against the bundled `nordvpn.ovpn` (the `--remote` CLI flag overrides the config's placeholder hostname), polls `ip -4 addr show tun0` for an assigned IPv4 address (30s timeout, 2s interval).
3. **Verify** — queries `ipinfo.io/json` (primary) and `ifconfig.co/json` (secondary). Primary must match the input region (hard fail); secondary is advisory only.
4. **Diagnostics** — emits six structured outputs to `$GITHUB_OUTPUT` and a human-readable table to `$GITHUB_STEP_SUMMARY`.

Any step failing exits the composite non-zero. The caller's `if: always()` disconnect step still runs on failure or cancellation.

## Pin forms

Three ways to pin a `uses:` line, strongest to weakest. Choose based on your reproducibility needs.

### 1. Commit SHA (recommended for release-critical workflows)

```yaml
- uses: pau-vega/nordvpn-action@<40-char-SHA> # nordvpn-v1.0.0
```

**Use when:** production CI, security-critical workflows, OpenSSF Scorecard "pinned-dependencies" compliance.

**Tradeoff:** byte-exact reproducibility. Update the SHA and the trailing `# vX.Y.Z` comment together — Dependabot does both automatically (configured in `.github/dependabot.yml`).

### 2. Exact version tag

```yaml
- uses: pau-vega/nordvpn-action@nordvpn-v1.0.0
```

**Use when:** you want a specific version, more readable than a SHA, and you accept that exact tags are technically mutable (release-please does not move them; git permits force-push by a maintainer with write access — this repo does not).

**Tradeoff:** less strict than SHA, more readable.

### 3. Floating major tag (convenience — auto-patch updates)

```yaml
- uses: pau-vega/nordvpn-action@nordvpn-v1
```

**Use when:** you want auto-bump to the latest patch/minor for major v1.

**Tradeoff:** **MUTABLE BY DESIGN.** The `nordvpn-v1` tag is force-moved to the SHA of every new v1.x.y release by `.github/workflows/release-please.yml` (`tag-floating-major` job). Reproducibility is sacrificed for convenience. Use SHA pinning (form 1) if you cannot tolerate this.

### Never use `@main`

`uses: pau-vega/nordvpn-action@main` is **not** a recommended pin form. `main` moves on every merge — your workflow would resolve to whatever code happens to be on `main` at run time, with no version contract. This README does not document `@main` as a supported form. Pinning options are SHA, exact tag, or floating major; nothing else.

## Required setup (consumers)

Every consumer of this action needs:

1. A `Preview` environment in their repo (Settings → Environments → New environment).
2. Two environment-scoped secrets:
   - `NORDVPN_SERVICE_USERNAME` — dashboard-issued NordVPN service credential username (NOT account email).
   - `NORDVPN_SERVICE_PASSWORD` — dashboard-issued NordVPN service credential password (NOT account password).
3. `runs-on: ubuntu-latest` (Ubuntu 22.04 or 24.04 — macOS and Windows runners are not supported).
4. A paired `disconnect/` step with `if: always()` after any country-gated work.

## Teardown constraint

Composite actions do not support `post:` ([community discussion #26743](https://github.com/orgs/community/discussions/26743)). The caller workflow MUST invoke `./disconnect` as a sibling step with `if: always()` so the OpenVPN daemon and 0600 auth file get cleaned up whether the main action succeeded, failed, or was cancelled.

## Credential Rotation

Rotate `NORDVPN_SERVICE_USERNAME` / `NORDVPN_SERVICE_PASSWORD` without any code change:

1. **Generate new service credentials.** Log in to the NordVPN web dashboard at
   https://my.nordaccount.com/, open **NordVPN -> Set up NordVPN manually** (or the
   equivalent section that exposes OpenVPN service credentials), and generate a fresh
   username/password pair. These are service credentials, NOT your account
   email/password — manual OpenVPN only accepts the dashboard-issued service
   credentials.

2. **Update GitHub environment secrets.** In the GitHub UI, open
   Settings -> Environments -> `Preview`. Edit `NORDVPN_SERVICE_USERNAME` and
   `NORDVPN_SERVICE_PASSWORD` with the new values, then Save. The secrets must live
   in the `Preview` environment — repo-level secrets are NOT read.

3. **Verify with the next workflow run.** Open (or re-run) any pull request whose
   e2e job uses this action. The action picks up the new credentials automatically on
   the next run. In the run's Step Summary look for the **VPN diagnostics**
   `::notice::` annotation and confirm `country: <region>` plus a fresh `exit-ip`.

4. **Revoke the old credentials.** Once the new credentials are verified in a green
   run, revoke the old service credentials from the NordVPN dashboard.

## Troubleshooting

- **`connect.sh` fails with `AUTH_FAILED` in the OpenVPN log.** The service
  credentials were copy-pasted with leading/trailing whitespace, or they were saved
  at the repo level instead of in the `Preview` environment. The action only
  reads `Preview`-scoped secrets.

- **Every run prints `Skipping e2e: VPN-gated` and skips all downstream
  steps.** Either the PR is from a fork (forks cannot access `Preview` secrets —
  this is the intentional fork-safety posture; use `pull_request`, not
  `pull_request_target`) or the secrets are missing from the `Preview` environment.
  Re-run from a maintainer branch, or add the missing secrets.

- **`::error::Unsupported region: <code> (supported: ES, US, FR)`.** The `region`
  input was set to an ISO-2 code the action does not yet support. Either change
  the value to ES, US, or FR, or follow the "Adding a new region" steps above.

- **Country mismatch (`country != region`) in the VPN diagnostics table.** The
  two-provider verification hard-fails before downstream jobs run; the Connect step
  will show red. Check which NordVPN server handled the run via the `asn` /
  `exit-ip` fields in the diagnostics `::notice::` annotation, and re-run the PR.

- **`::error::Ubuntu runner required (detected darwin)` or similar.** The action
  only supports `ubuntu-latest` runners. Scripts use `apt-get` and
  `systemd-resolved`. macOS/Windows runners are not supported — the action fails
  fast with this error as a feature, not a bug.

- **`::error::tun0 did not come up within 30s`.** The OpenVPN daemon failed to
  establish the tunnel within the timeout. Check the openvpn daemon log in the
  step's output (expanded with `::group::openvpn daemon log`). Common causes:
  `AUTH_FAILED` (wrong credentials), API returned a decommissioned server, or
  network issues on the runner.

- **`::error::country mismatch: primary=FR secondary=FR expected=ES`.** Both
  geo providers returned a non-Spanish exit IP. This indicates NordVPN routed
  to a different country. Check the `asn` and `exit-ip` in the diagnostics
  to identify the server, then re-run.

## Adding a new region

The action currently supports `ES` (Spain, country_id=202), `US` (United States, country_id=228), and `FR` (France, country_id=74). To add another country:

1. Add the ISO-2 code and the NordVPN `country_id` (from `api.nordvpn.com/v1/servers/countries`) to the `case` statement in `scripts/connect.sh`.
2. Add the ISO-2 code to the matrix in `.github/workflows/self-test.yml`.
3. Document the new region in the Inputs table above.

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
