# Security Policy

`pau-vega/nordvpn-action` is a public, MIT-licensed monorepo of composite GitHub Actions that route a runner through a NordVPN exit node. The actions handle credentials, write a `0600` auth file under `$RUNNER_TEMP`, and shell out to `openvpn` via `apt-get` packages. Anything that weakens those guarantees is in scope.

## Supported versions

Only the latest minor of each `nordvpn-<region>-v<MAJOR>` line receives security fixes. Older minors of the same major may be patched on a best-effort basis.

| Region    | Supported  |
|-----------|------------|
| `nordvpn-es-v1.x` | latest minor |
| `nordvpn-us-v1.x` | latest minor |
| `nordvpn-fr-v1.x` | latest minor |
| Anything older    | no         |

## Reporting a vulnerability

**Do NOT open a public GitHub issue or pull request.** Public reports for credential-handling or `pull_request_target`-class bugs hand a window to attackers before a fix is available.

Use GitHub's private vulnerability reporting:

1. Open <https://github.com/pau-vega/nordvpn-action/security/advisories/new>
2. Provide:
   - Affected region(s) and pinned ref (SHA or tag)
   - Runner OS version (`ubuntu-22.04`, `ubuntu-24.04`, etc.)
   - Reproduction: workflow YAML excerpt + the relevant step log (redact secrets first)
   - Impact summary: what an attacker gains (RCE, secret exfiltration, geo bypass, etc.)

If GitHub's reporter is unavailable, email the maintainer listed in the repo profile and prefix the subject with `[SECURITY]`.

## What is in scope

- Anything that leaks `NORDVPN_USERNAME` / `NORDVPN_PASSWORD` (or any caller secret) into logs, env, or artifacts.
- Anything that defeats GitHub's exact-string secret masking (`set -x`, base64 round-trips, `sed`/`awk` transformations of secret values).
- Workflow-injection / expression-injection in `.github/workflows/**` or `actions/**/action.yml`.
- Privilege escalation past the runner's expected unprivileged surface.
- Geo verification bypass (`verify-country.sh` returning success when the tunnel is down or the exit node is in the wrong country).
- `pull_request_target` reintroduction or sandbox bypass of the `block-pull-request-target` lint job.
- Tag/release supply-chain issues — a malicious release-please run, a moved-version tag pointing at attacker-controlled code, etc.

## What is out of scope

- Anything that requires write access to `main` or a maintainer machine to exploit. The threat model is "consumer runs the action via `uses:`", not "attacker is a maintainer".
- Vulnerabilities in upstream `openvpn`, `openvpn-systemd-resolved`, or NordVPN's API. Report those to their respective projects.
- Denial-of-service caused by NordVPN exit-node capacity. Mitigated by retry (2 attempts in `action.yml`) and 10-minute job timeout, not a security issue.
- Bugs reachable only by an attacker who already controls the caller's `Preview` environment secrets.

## Response targets

This is a single-maintainer OSS project. Targets are good-faith, not contractual:

| Phase                  | Target            |
|------------------------|-------------------|
| Acknowledge report     | within 3 business days |
| Triage + initial assessment | within 7 business days |
| Fix released (HIGH/CRITICAL) | within 30 days |
| Fix released (MEDIUM/LOW) | within 90 days |

A fix typically means a new patch release of the affected region (`nordvpn-<region>-v1.x.y+1`) with a CHANGELOG entry; the floating-major tag (`nordvpn-<region>-v1`) is force-moved by the existing `tag-floating-major` job so consumers on that pin form get the fix automatically. SHA-pinned consumers are notified via GitHub Security Advisory.

## Coordinated disclosure

Once a fix is released, the reporter is credited in the CHANGELOG and the corresponding GitHub Security Advisory unless they request otherwise. We aim to publish the advisory within 14 days of the fix release; embargoed details are negotiable.
