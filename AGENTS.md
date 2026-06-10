# AGENTS.md

This file provides guidance to coding agents (Claude Code, etc.) when working with code in this repository. `CLAUDE.md` is a symlink to this file.

## Project

`pau-vega/nordvpn-action` — public, MIT-licensed composite GitHub Action that routes a runner through a NordVPN exit node in a selectable country (ES, US, FR) and verifies the geo-IP before downstream steps run. Pure Bash + composite YAML; no Node, no Docker, Ubuntu runners only.

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

### Single parameterized action

```
actions/nordvpn/
  action.yml              # composite — install → connect (2-attempt retry) → verify
                          # takes required `region:` input (ES, US, or FR)
  disconnect/action.yml   # sibling sub-action invoked with `if: always()`
  scripts/
    install.sh            # apt-get openvpn + openvpn-systemd-resolved; asserts toolchain
    connect.sh            # writes 0600 auth file, maps region→country_id, picks live server via NordVPN API, polls tun0
    verify-country.sh     # ipinfo.io (hard) + ifconfig.co (advisory), emits 6 outputs
    disconnect.sh         # SIGTERM→SIGKILL openvpn, rm auth file; never fails the job
  vpn/nordvpn.ovpn        # baseline OpenVPN config; `--remote` overrides at runtime
```

The single action consolidates what used to be three near-identical region trees (`nordvpn-{es,us,fr}/`). The only region-specific state is a `case` statement in `connect.sh` mapping ISO-2 codes to NordVPN `country_id`s (ES=202, US=228, FR=74). The `.ovpn` file is shared — its placeholder `remote` line is always overridden at runtime by the API-resolved server hostname.

Adding a new region: add the ISO-2 → `country_id` mapping to the `case` statement, add the code to the self-test matrix, document the region in `actions/nordvpn/README.md`. No new directory, no new scripts, no new release-please package.

### Key constraints embedded in the scripts

- **No `set -x` anywhere** — GitHub's secret masking matches exact strings; any transformation (xtrace, base64, sed) bypasses it.
- **`set -euo pipefail` in connect/install/verify; `set -u` only in disconnect** — disconnect must never fail the job under `if: always()`.
- **Readiness is `ip -4 addr show tun0` returning `inet `**, NOT `openvpn --daemon`'s exit code (the daemon forks and exits 0 before the handshake completes). Poll 2s, 30s timeout.
- **`CONNECT_DURATION_MS`** is passed across composite-step boundaries via `$GITHUB_ENV` (set in `connect.sh`, consumed by `verify-country.sh`).
- **`COUNTRY_CODE` / `COUNTRY_ID`** are set in `connect.sh` from the `region` input via a `case` statement. The `case` is the single source of truth for which regions are supported — keep `actions/nordvpn/README.md` in sync.
- **Auth file:** `$RUNNER_TEMP/nordvpn-auth.txt` at mode `0600` via `umask 077 + printf + chmod`. Removed by `disconnect.sh`.
- **Server selection:** `connect.sh` queries `api.nordvpn.com/v1/servers/recommendations` (NOT DNS round-robin on `<region>.nordvpn.com` — that hostname doesn't exist). `--remote` CLI flag overrides the `.ovpn` config.
- **Geo verification:** primary `ipinfo.io` `.country` must match the `region` input (hard fail); secondary `ifconfig.co` `.country_iso` is advisory only (ifconfig.co lags on some servers). Field names differ between providers — `ifconfig.co.country` is the English name, NOT the ISO-2 code.
- **Smoke/chaos env vars** (`SMOKE_PASSWORD_OVERRIDE`, `SMOKE_SKIP_OPENVPN_START`, `SMOKE_UNINSTALL_OPENVPN`, `SMOKE_EXPECT_COUNTRY`) inject failures for self-test. Production callers never set them.

### Why a separate `disconnect/` sub-action?

Composite actions do **not** support `post:` ([community discussion #26743](https://github.com/orgs/community/discussions/26743)). Consumers must invoke `actions/nordvpn/disconnect` as a sibling step with `if: always()`. Do not fold disconnect into the main action.

## Frozen v1 contracts

### Action input names (consumed verbatim by callers; never rename)

`region` (ISO-2: `ES`/`US`/`FR`), `username`, `password`.

### Action output names (consumed verbatim by callers; never rename)

`exit-ip`, `country`, `asn`, `tun0-state`, `default-route`, `connect-duration-ms`.

### Tag format

`nordvpn-v<X.Y.Z>` (release-please default `-` separator, **not** `@`). Floating major `nordvpn-v<MAJOR>` is force-moved by `.github/workflows/release-please.yml#tag-floating-major` after each release.

### Pin posture (this repo's own workflows)

All `uses:` lines pin a 40-char SHA + trailing `# vX.Y.Z` comment. Dependabot reads the comment and updates both atomically. Floating tags (`@v5`, `@main`) fail OpenSSF Scorecard.

Canonical SHAs (as pinned in this repo's workflows):

```
actions/checkout@df4cb1c069e1874edd31b4311f1884172cec0e10                  # v6.0.3
googleapis/release-please-action@45996ed1f6d02564a971a2fa1b5860e934307cf7  # v5.0.0
reviewdog/action-actionlint@6fb7acc99f4a1008869fa8a0f09cfca740837d9d       # v1.72.0
ludeeus/action-shellcheck@00cae500b08a931fb5698e11e79bfbd38e612a38         # 2.0.0
ossf/scorecard-action@4eaacf0543bb3f2c246792bd56e8cdeffafb205a              # v2.4.3
github/codeql-action/*@8aad20d150bbac5944a9f9d289da16a4b0d87c1e            # v4.36.2
step-security/harden-runner@9af89fc71515a100421586dfdb3dc9c984fbf411       # v2.19.4
actions/upload-artifact@043fb46d1a93c77aae656e7c1c64a875d1fc6a0a            # v7.0.1
peter-evans/enable-pull-request-automerge@a660677d5469627102a1c1e11409dd063606628d # v3.0.0
```

### Banned constructs

- **`pull_request_target` anywhere in `.github/workflows/**`** — hard-blocked by the `block-pull-request-target` job in `actions-lint.yml`. Bypass attempts fail CI. If fork-PR feedback is genuinely needed, use the split `pull_request` → artifact → `workflow_run` pattern.
- **`set -x`** in any shipped script — leaks secrets past GitHub's exact-match masking.
- **macOS / Windows runners** — scripts are `apt-get`-based; `connect.sh` exits fast on `RUNNER_OS != Linux`.
- **`@main` / `@v5` floating action refs** — see pin posture above.

## Conventional Commits

Required from commit #1. release-please depends on commit-history shape; do not retrofit.

- **Action scopes:** `feat(nordvpn)`, `fix(nordvpn)`, or no scope for cross-cutting changes. The region is encoded in the commit body, not the scope, since all regions ship as one action.
- **Workflow scopes:** `fix(self-test)`, `lint(actionlint)`, etc.
- **`deps:` type** is surfaced in changelogs (Dependabot uses this prefix).
- **Files release-please OWNS — do not hand-edit:** `.release-please-manifest.json`, `actions/*/CHANGELOG.md`. Hand-editing breaks the next release.

## Self-test workflow shape

`fork-check` + a single `self-test` matrix job:

- `fork-check` outputs `is_fork=true` for PRs from forks → `self-test` skips with `::notice::`.
- `self-test` runs a matrix over `region: [ES, US, FR]`, invokes `./actions/nordvpn` with `region: ${{ matrix.region }}`, asserts all 6 outputs non-empty, asserts `COUNTRY` matches the matrix value, plus a workflow-level `curl ipinfo.io/country` check. `workflow_dispatch` can scope the run to a single region.
- On `schedule` runs: `drift-issue` upserts a `region-drift`-labeled issue on failure; `drift-close` closes the existing one on full success.

Fork PRs are intentionally skipped — `pull_request` (not `pull_request_target`) means fork code never reaches `Preview` secrets. Maintainer pulls fork PRs to a trusted branch for full self-test runs.

## Pointers

- Inputs/outputs/troubleshooting: `actions/nordvpn/README.md`.
- Phase artifacts, requirements, research, pitfalls: `.planning/`.

## Project Skills

No project skills found. Add skills to any of: `.claude/skills/`, `.agents/skills/`, `.cursor/skills/`, or `.github/skills/` with a `SKILL.md` index file.

## GSD Workflow Enforcement

Before using Edit, Write, or other file-changing tools, start work through a GSD command so planning artifacts and execution context stay in sync. These are project-specific slash commands (not built into OpenCode/Claude Code) defined in `.claude/commands/`.

Use these entry points:
- `/gsd-quick` for small fixes, doc updates, and ad-hoc tasks
- `/gsd-debug` for investigation and bug fixing
- `/gsd-execute-phase` for planned phase work

Do not make direct repo edits outside a GSD workflow unless the user explicitly asks to bypass it.

## Developer Profile

> Profile not yet configured. Run `/gsd-profile-user` to generate your developer profile.
> This section is managed by `generate-claude-profile` -- do not edit manually.
