# AGENTS.md

This file provides guidance to coding agents (Claude Code, etc.) when working with code in this repository. `CLAUDE.md` is a symlink to this file.

## Project

`pau-vega/nordvpn-action` — public, MIT-licensed monorepo of composite GitHub Actions that route a runner through a NordVPN exit node (ES, US, FR) and verify the geo-IP before downstream steps run. Pure Bash + composite YAML; no Node, no Docker, Ubuntu runners only.

See `README.md` for consumer-facing usage.

## Commands

Local lint mirrors CI (install via `brew install actionlint shellcheck jq gh`):

```bash
actionlint .github/workflows/*.yml          # workflow YAML + inline `run:` shell
shellcheck actions/**/scripts/*.sh          # standalone shell scripts
```

Phase verification dispatcher (runs `.planning/`-driven verify scripts):

```bash
bash scripts/verify.sh                       # run all phases
bash scripts/verify.sh phase-1               # run a specific phase
```

Branch protection (re-run after any required-check name change):

```bash
bash scripts/setup-branch-protection.sh
```

End-to-end self-test is **not runnable locally** — needs `NORDVPN_SERVICE_USERNAME` / `NORDVPN_SERVICE_PASSWORD` in the `Preview` environment. Runs via `.github/workflows/self-test.yml` (push to `main`, non-fork PRs, Monday 08:00 UTC cron, or manual `workflow_dispatch`).

## Architecture

### Three near-identical region trees (intentional triplication)

```
actions/nordvpn-<region>/
  action.yml              # composite — install → connect (2-attempt retry) → verify
  disconnect/action.yml   # sibling sub-action invoked with `if: always()`
  scripts/
    install.sh            # apt-get openvpn + openvpn-systemd-resolved; asserts toolchain
    connect.sh            # writes 0600 auth file, picks live server via NordVPN API, polls tun0
    verify-country.sh     # ipinfo.io (hard) + ifconfig.co (advisory), emits 6 outputs
    disconnect.sh         # SIGTERM→SIGKILL openvpn, rm auth file; never fails the job
  vpn/nordvpn-<region>.ovpn  # baseline OpenVPN config; `--remote` overrides at runtime
```

Regions differ only by ISO-2 code (`ES`/`US`/`FR`) and NordVPN `country_id` (202/228/74). Shared-scripts abstraction was deliberately rejected at N=3; revisit at N=5+.

### Key constraints embedded in the scripts

- **No `set -x` anywhere** — GitHub's secret masking matches exact strings; any transformation (xtrace, base64, sed) bypasses it.
- **`set -euo pipefail` in connect/install/verify; `set -u` only in disconnect** — disconnect must never fail the job under `if: always()`.
- **Readiness is `ip -4 addr show tun0` returning `inet `**, NOT `openvpn --daemon`'s exit code (the daemon forks and exits 0 before the handshake completes). Poll 2s, 30s timeout.
- **`CONNECT_DURATION_MS`** is passed across composite-step boundaries via `$GITHUB_ENV` (set in `connect.sh`, consumed by `verify-country.sh`).
- **Auth file:** `$RUNNER_TEMP/nordvpn-auth.txt` at mode `0600` via `umask 077 + printf + chmod`. Removed by `disconnect.sh`.
- **Server selection:** `connect.sh` queries `api.nordvpn.com/v1/servers/recommendations` (NOT DNS round-robin on `<region>.nordvpn.com` — that hostname doesn't exist). `--remote` CLI flag overrides the `.ovpn` config.
- **Geo verification:** primary `ipinfo.io` `.country` must match (hard fail); secondary `ifconfig.co` `.country_iso` is advisory only (ifconfig.co lags on some servers). Field names differ between providers — `ifconfig.co.country` is the English name, NOT the ISO-2 code.
- **Smoke/chaos env vars** (`SMOKE_PASSWORD_OVERRIDE`, `SMOKE_SKIP_OPENVPN_START`, `SMOKE_UNINSTALL_OPENVPN`, `SMOKE_EXPECT_COUNTRY`) inject failures for self-test. Production callers never set them.

### Why a separate `disconnect/` sub-action?

Composite actions do **not** support `post:` ([community discussion #26743](https://github.com/orgs/community/discussions/26743)). Consumers must invoke `actions/nordvpn-<region>/disconnect` as a sibling step with `if: always()`. Do not fold disconnect into the main action.

## Frozen v1 contracts

### Action output names (consumed verbatim by callers; never rename)

`exit-ip`, `country`, `asn`, `tun0-state`, `default-route`, `connect-duration-ms`.

Same six outputs across ES/US/FR. Same two input names: `username`, `password`.

### Tag format

`nordvpn-<region>-v<X.Y.Z>` (release-please default `-` separator, **not** `@`). Floating major `nordvpn-<region>-v<MAJOR>` is force-moved by `.github/workflows/release-please.yml#tag-floating-major` after each release. No bare `v1` — ambiguous in a 3-region monorepo.

### Pin posture (this repo's own workflows)

All `uses:` lines pin a 40-char SHA + trailing `# vX.Y.Z` comment. Dependabot reads the comment and updates both atomically. Floating tags (`@v5`, `@main`) fail OpenSSF Scorecard.

Canonical SHAs:

```
actions/checkout@de0fac2e4500dabe0009e67214ff5f5447ce83dd                  # v6.0.2
googleapis/release-please-action@45996ed1f6d02564a971a2fa1b5860e934307cf7  # v5.0.0
reviewdog/action-actionlint@6fb7acc99f4a1008869fa8a0f09cfca740837d9d       # v1.72.0
ludeeus/action-shellcheck@00cae500b08a931fb5698e11e79bfbd38e612a38         # 2.0.0
```

### Banned constructs

- **`pull_request_target` anywhere in `.github/workflows/**`** — hard-blocked by the `block-pull-request-target` job in `actions-lint.yml`. Bypass attempts fail CI. If fork-PR feedback is genuinely needed, use the split `pull_request` → artifact → `workflow_run` pattern.
- **`set -x`** in any shipped script — leaks secrets past GitHub's exact-match masking.
- **macOS / Windows runners** — scripts are `apt-get`-based; `connect.sh` exits fast on `RUNNER_OS != Linux`.
- **`@main` / `@v5` floating action refs** — see pin posture above.

## Conventional Commits

Required from commit #1. release-please depends on commit-history shape; do not retrofit.

- **Pre-region (Phase 1) scopes:** `scaf`, `lint`, `chore`, `docs`.
- **Per-region scopes:** `feat(nordvpn-es)`, `fix(nordvpn-us)`, `feat(nordvpn-fr)`, etc. One region per PR — mixing regions splits across multiple release PRs.
- **`deps:` type** is surfaced in changelogs (Dependabot uses this prefix).
- **Files release-please OWNS — do not hand-edit:** `.release-please-manifest.json`, `actions/*/CHANGELOG.md`.

## Self-test workflow shape

Five region jobs gated by `fork-check`:

- `fork-check` outputs `is_fork=true` for PRs from forks → all region jobs skip with `::notice::`.
- Each region job runs `environment: Preview`, invokes its action, asserts all 6 outputs non-empty, asserts `COUNTRY` matches expected, plus a workflow-level `curl ipinfo.io/country` check.
- On `schedule` runs: `drift-issue` upserts a `region-drift`-labeled issue on failure; `drift-close` closes the existing one on full success.

Fork PRs are intentionally skipped — `pull_request` (not `pull_request_target`) means fork code never reaches `Preview` secrets. Maintainer pulls fork PRs to a trusted branch for full self-test runs.

## Pointers

- Per-region inputs/outputs/troubleshooting: `actions/nordvpn-<region>/README.md`.
- Phase artifacts, requirements, research, pitfalls: `.planning/`.

## Project Skills

No project skills found. Add skills to any of: `.claude/skills/`, `.agents/skills/`, `.cursor/skills/`, or `.github/skills/` with a `SKILL.md` index file.

## GSD Workflow Enforcement

Before using Edit, Write, or other file-changing tools, start work through a GSD command so planning artifacts and execution context stay in sync.

Use these entry points:
- `/gsd-quick` for small fixes, doc updates, and ad-hoc tasks
- `/gsd-debug` for investigation and bug fixing
- `/gsd-execute-phase` for planned phase work

Do not make direct repo edits outside a GSD workflow unless the user explicitly asks to bypass it.

## Developer Profile

> Profile not yet configured. Run `/gsd-profile-user` to generate your developer profile.
> This section is managed by `generate-claude-profile` -- do not edit manually.
