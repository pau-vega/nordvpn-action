# NordVPN US Egress (composite action)

Connects the current GitHub Actions runner to a NordVPN US exit node, verifies `country=US` against two independent geo providers, and exposes a diagnostics bundle as step outputs. Intended to be consumed from any repo via `uses:`. Teardown lives in the sibling `disconnect/` sub-action.

> **Teardown constraint:** composite actions do not support `post:` ([GitHub Community Discussion #26743](https://github.com/orgs/community/discussions/26743)). The caller workflow MUST invoke the `/disconnect` sub-action as a sibling step with `if: always()`. See the Usage section below.

## Inputs

| Name | Required | Description |
|------|----------|-------------|
| `username` | yes | NordVPN service username. In consumer repos, sourced from a `Preview` environment secret like `NORDVPN_SERVICE_USERNAME`. |
| `password` | yes | NordVPN service password. In consumer repos, sourced from a `Preview` environment secret like `NORDVPN_SERVICE_PASSWORD`. |

NordVPN **service** credentials are required — NordVPN account email/password does NOT work with manual OpenVPN. Generate service credentials from the NordVPN web dashboard.

## Outputs

| Name | Description |
|------|-------------|
| `exit-ip` | Public IPv4 after tunnel up (NordVPN US gateway). |
| `country` | ISO-2 country code of exit IP; guaranteed `US` on action success. |
| `asn` | ASN/ISP of the exit gateway (string). |
| `tun0-state` | Human-readable tunnel state: `up` or `down-or-missing`. |
| `default-route` | Active IPv4 default route after connect (string). |
| `connect-duration-ms` | Wall-clock time from openvpn invocation to tun0 IPv4 assigned, in milliseconds. |

## Usage

The action MUST be paired with a sibling `if: always()` disconnect step — see teardown constraint above. Minimum caller shape:

```yaml
jobs:
  example:
    runs-on: ubuntu-latest
    environment: Preview
    steps:
      - uses: actions/checkout@v6

      - name: Connect NordVPN (US)
        id: vpn
        uses: pau-vega/nordvpn-action/actions/nordvpn-us@<40-char-SHA> # vX.Y.Z
        with:
          username: ${{ secrets.NORDVPN_SERVICE_USERNAME }}
          password: ${{ secrets.NORDVPN_SERVICE_PASSWORD }}

      - name: Disconnect VPN
        if: always()
        uses: pau-vega/nordvpn-action/actions/nordvpn-us/disconnect@<40-char-SHA> # vX.Y.Z
```

- Use the 40-character commit SHA for deterministic pinning. The `# vX.Y.Z` comment is for human readability (Dependabot updates both atomically).
- `@<SHA>` is recommended for release-critical workflows. See the `## Versioning` section below for full guidance on pin forms.
- The caller workflow MUST declare `environment: Preview` so the secrets resolve.
- Fork PRs cannot access `Preview` secrets when the calling workflow uses `pull_request` (not `pull_request_target`) — this is the deliberate fork-safety posture. Fork contributors cannot trigger the VPN-gated steps from their fork branch.
- **Never use `pull_request_target`** — it is BANNED in this repo (see AGENTS.md Security section).

## Internal Steps

The composite runs three sequential steps:

1. **Install** — `apt-get install openvpn openvpn-systemd-resolved`, asserts `curl`/`jq`/`openvpn` are on PATH.
2. **Connect (bounded retry)** — up to 2 attempts: writes service credentials to `$RUNNER_TEMP/nordvpn-auth.txt` at 0600, starts `openvpn --daemon` against the bundled `nordvpn-us.ovpn`, polls `ip -4 addr show tun0` for an assigned IPv4 address (30s timeout, 2s interval).
3. **Verify** — queries `ipinfo.io/json` (primary) and `ifconfig.co/json` (secondary). Both must independently return `US`. Emits the six-field diagnostics bundle above to `$GITHUB_OUTPUT`.

Any step failing exits the composite non-zero. The caller's `if: always()` disconnect step still runs on failure or cancellation.

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
   `::notice::` annotation and confirm `country: US` plus a fresh `exit-ip`.

4. **Revoke the old credentials.** Once the new credentials are verified in a green
   run, revoke the old service credentials from the NordVPN dashboard.

## Versioning

Three pin forms, ordered from strongest to weakest reproducibility guarantee:

| Pin form | Example | Use when |
|----------|---------|----------|
| Commit SHA | `@a1b2c3d4e5f60718293a4b5c6d7e8f9012345678` (40 chars) | You need byte-for-byte reproducibility and immunity to tag re-pointing. Recommended for release-critical workflows. |
| Exact version tag | `@nordvpn-us-v1.0.1` | You want a specific, frozen version without the SHA noise. Produced by [release-please](https://github.com/googleapis/release-please) on every automated release. |
| Floating major tag | `@nordvpn-us-v1` | You want automatic non-breaking updates on every `v1.x.y` release. Force-moved by the CI on every new `nordvpn-us-v1.x.y` release. |

**Never use `@main`** — it is not a recommended pin form. Floating tags like `@main` fail the OpenSSF Scorecard "pinned-dependencies" check. The `@main` branch is a moving target and provides no reproducibility guarantee.

Automated releases are cut by [release-please](https://github.com/googleapis/release-please) whenever a conventional commit lands under `actions/nordvpn-us/**`. The resulting tag is `nordvpn-us-vX.Y.Z` and the floating `nordvpn-us-v1` tag is force-updated to the same commit.

Following the pinned-action posture used by this repo's own CI (see `.github/workflows/actions-lint.yml`), **pin SHA for reproducibility** unless you specifically want auto-updates on the `v1` line.

The `nordvpn-us-v1` tag is force-moved on every release. For reproducibility, pin SHA.

### Troubleshooting

- **`connect.sh` fails with `AUTH_FAILED` in the OpenVPN log.** The service
  credentials were copy-pasted with leading/trailing whitespace, or they were saved
  at the repo level instead of in the `Preview` environment. The action only
  reads `Preview`-scoped secrets.

- **Every run prints `Skipping e2e: VPN-gated` and skips all downstream
  steps.** Either the PR is from a fork (forks cannot access `Preview` secrets —
  this is the intentional fork-safety posture; use `pull_request`, not
  `pull_request_target`) or the secrets are missing from the `Preview` environment.
  Re-run from a maintainer branch, or add the missing secrets.

- **Country mismatch (`country != US`) in the VPN diagnostics table.** The
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

- **`::error::country mismatch: primary=FR secondary=FR expected=US`.** Both
  geo providers returned a non-US exit IP. This indicates NordVPN routed
  to a different country. Check the `asn` and `exit-ip` in the diagnostics
  to identify the server, then re-run.
