# nordvpn-actions

## What This Is

A public, MIT-licensed monorepo of composite GitHub Actions that route a runner through a NordVPN exit node in a specific country (ES, US, FR) and verify the geo-IP before downstream steps run. It is a portable, portfolio-quality port of the `nordvpn-es` action currently living inside `Tutellus/tutellus-frontend-utils` (PR #159), re-homed on `pau-vega/nordvpn-actions` so other projects — personal or otherwise — can depend on it via a stable `uses:` reference.

## Core Value

A caller can add one `uses:` line and be certain the next steps run from the declared country, or the job fails fast — no hand-written OpenVPN plumbing, no unverified exit IPs.

## Requirements

### Validated

- [x] Self-test CI workflow: runs the action end-to-end on push to `main` and on non-fork PRs using `Preview` environment secrets; forks skip cleanly — Validated in Phase 4

### Active

- [ ] Repo layout: monorepo with `actions/nordvpn-<region>/` per region; root-level docs, root-level workflows
- [ ] Port the existing `nordvpn-es` composite action (inputs/outputs/scripts/.ovpn) from Tutellus/tutellus-frontend-utils PR #159 with no behavioral changes
- [ ] Add `nordvpn-us` composite action (bundled `.ovpn`, same input/output contract as `-es`, country verified = `US`)
- [ ] Add `nordvpn-fr` composite action (bundled `.ovpn`, same input/output contract as `-es`, country verified = `FR`)
- [ ] Sibling `disconnect/` sub-action per region for `if: always()` teardown (composite actions cannot use `post:`)
- [ ] `actions-lint` CI workflow: `actionlint` + `shellcheck` strict on every PR touching `actions/**` or `.github/workflows/**`

- [ ] Release tooling: release-please monorepo config with per-action `release-type: simple`, `component: nordvpn-<region>`, conventional-commit-driven `CHANGELOG.md` per action
- [ ] Floating major tag automation: after every release of `nordvpn-<region>-vX.Y.Z`, a CI job force-moves `nordvpn-<region>-v<MAJOR>` (and/or `v<MAJOR>` where unambiguous) to the same SHA
- [ ] CODEOWNERS scoped to `/actions/ @pau-vega`
- [ ] Dependabot `github-actions` ecosystem watching `/`, each `/actions/nordvpn-<region>`, and each `/actions/nordvpn-<region>/disconnect`
- [ ] Per-action README with Inputs / Outputs / Usage / Versioning / Troubleshooting / Credential rotation sections
- [ ] Root README indexing every shipped action with pin-form guidance (SHA / exact tag / floating major)
- [ ] `AGENTS.md` contributor guide for AI agents working in this repo
- [ ] `LICENSE` (MIT)
- [ ] Branch protection on `main`: `actions-lint` required to pass before merge

### Out of Scope

- **Marketplace publication** — Deferred to a later milestone. Portfolio-quality repo first; marketplace decision lives in the Marketplace phase (post-v1). The monorepo shape doesn't block marketplace; it does constrain the listing form.
- **Docker-based or JavaScript-based actions** — v1 is composite-only. The install/connect/verify flow is pure shell and Ubuntu-runner-specific; no need for Node or container overhead.
- **Dynamic `.ovpn` fetching from NordVPN's server recommendations API at runtime** — Bundled per-region `.ovpn` keeps the action reproducible and reduces network failure modes. The drift cost (NordVPN rotating servers) is accepted and tracked as a maintenance task.
- **Runners other than `ubuntu-latest`** — macOS/Windows runners are not supported. The scripts assume `apt-get`, `openvpn`, `openvpn-systemd-resolved`, `ip`, `curl`, `jq`. No cross-OS abstraction in v1.
- **Fork PR end-to-end runs** — Fork-safety is deliberate. Forks cannot reach `Preview`-scoped secrets; the self-test workflow skips with a clear message and no secret leak.
- **Countries other than ES / US / FR in v1** — New regions are additive in a future milestone. Each new region = new `actions/nordvpn-<region>/` + bundled `.ovpn` + changelog entry.
- **IPv6 verification** — Verify IPv4 exit IP only. IPv6 is ignored; NordVPN's OpenVPN profiles do not guarantee IPv6 egress.
- **NordVPN account email/password as inputs** — Only NordVPN service credentials (dashboard-issued OpenVPN credentials) are accepted. Account credentials do not authenticate against manual OpenVPN.
- **`post:` teardown inside the composite** — Not supported by GitHub composite actions ([community discussion #26743](https://github.com/orgs/community/discussions/26743)). Callers must invoke the sibling `disconnect/` step with `if: always()`.

## Context

- **Source of truth:** `Tutellus/tutellus-frontend-utils` PR #159 contains the working `nordvpn-es` composite action (`actions/nordvpn-es/` tree: `action.yml`, `disconnect/action.yml`, `scripts/{connect,disconnect,install,verify-country}.sh`, `vpn/nordvpn-es.ovpn`, `README.md`). The existing implementation already runs in Tutellus CI; this project re-homes it on a personal public repo and extends it to US/FR with the same contract.
- **Pin form convention:** Three pin forms, strongest to weakest — commit SHA (byte-for-byte reproducibility) > exact release tag `nordvpn-<region>-vX.Y.Z` > floating major `v<MAJOR>`. README should teach all three and recommend SHA for release-critical CI.
- **Consumer reference form:** `pau-vega/nordvpn-actions/actions/nordvpn-<region>@<ref>` and `pau-vega/nordvpn-actions/actions/nordvpn-<region>/disconnect@<ref>` (sibling sub-action).
- **Current repo state:** Empty git repo at `/Users/pauvelascogarrofe/Documents/nordvpn-action`. No files committed yet. Directory name is singular (`nordvpn-action`); the shipped repo name on GitHub will be plural (`nordvpn-actions`) — local dir rename is deferred, inconsequential for history.
- **Release tooling landscape (verified via research 2026-04):** release-please dominates monorepo composite-action repos (google-github-actions uses it; the amarjanica/release-please-monorepo-example is the canonical template; source PR also uses it). semantic-release is more common for single-package Node repos. Release-please was chosen because it matches the monorepo shape and the caller already knows it from the source PR.
- **Teardown constraint:** Composite actions do not support `post:` steps. Every region ships with a sibling `disconnect/` sub-action the caller must invoke under `if: always()`. This is documented prominently in each action's README.
- **Fork-safety posture:** Self-test uses `pull_request` (not `pull_request_target`) and `environment: Preview`. Fork contributors cannot trigger VPN-gated runs from their branch. This is intentional and documented in AGENTS.md / README.

## Constraints

- **Tech stack**: Composite action only; Bash scripts; Ubuntu runner; OpenVPN + `openvpn-systemd-resolved`; `curl` + `jq` for geo verification. No Node, no Docker, no non-`ubuntu-latest` runners.
- **Credentials**: NordVPN OpenVPN service credentials only (dashboard-issued). Account email/password does not authenticate against manual OpenVPN. Consumer repos must store them in a GitHub environment named `Preview`, secret names `NORDVPN_SERVICE_USERNAME` / `NORDVPN_SERVICE_PASSWORD`.
- **Verification**: Country check must hit two independent geo providers (`ipinfo.io`, `ifconfig.co`); both must return the expected ISO-2 code or the action fails.
- **Security**: Auth file written to `$RUNNER_TEMP` at mode `0600`; removed by `disconnect`. No secrets logged. Actions pinned by SHA + `# vX.Y.Z` comment inside workflows.
- **Release contract**: Every new feature/fix under `actions/nordvpn-<region>/**` must follow Conventional Commits (`feat(nordvpn-es):`, `fix(nordvpn-us):`, etc.) so release-please can compute the right bump per action.
- **Backwards compatibility**: The `nordvpn-es` input/output contract is frozen at v1. US/FR actions must match the same contract (same input names, same output names). Breaking changes require a major bump on the affected action only.
- **Pin-posture contract**: Each action's README must document the three pin forms and recommend SHA pinning for release-critical workflows. This is a promise to consumers, not just a docs style choice.

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Monorepo layout (`actions/nordvpn-<region>/`) instead of one repo per region | Single release pipeline, single CI, shared scripts/docs patterns. Matches the source PR's shape and the google-github-actions precedent. | — Pending |
| release-please for versioning + `CHANGELOG.md` | Dominant tool for monorepo composite actions in 2026; same tool the source PR uses; zero manual changelog work. | — Pending |
| Mutable major tag (`nordvpn-<region>-v1` / `v1`) alongside immutable exact tags | GitHub Actions ecosystem convention; consumers pin floating major for auto-patch updates, SHA for strict reproducibility. | — Pending |
| Self-test runs on push to `main` and non-fork PRs via `Preview` environment | Catches real breakage without leaking secrets to fork PRs; mirrors the fork-safety posture of the source action. | — Pending |
| Bundle fixed `.ovpn` per region instead of fetching at runtime | Reproducibility, no extra network dep, no runtime failure mode; drift is acceptable and handled by periodic refresh. | — Pending |
| `AGENTS.md` as primary contributor guide | Matches source PR pattern; communicates Claude/Codex agent workflow explicitly in a repo that's agent-friendly. | — Pending |
| MIT license | Permissive; GitHub Actions ecosystem norm; portfolio-compatible. | — Pending |
| Marketplace decision deferred | Core value is the working action; marketplace is a distribution concern with extra requirements (single-action listing form, branded assets). Revisit post-v1. | — Pending |
| Ubuntu-only runners | Scripts are `apt-get` + `ip` based; cross-OS support is disproportionate work for v1. | — Pending |
| IPv4-only verification | NordVPN OpenVPN profiles don't guarantee IPv6 egress; keeping the verify surface narrow. | — Pending |

## Evolution

This document evolves at phase transitions and milestone boundaries.

**After each phase transition** (via `/gsd-transition`):
1. Requirements invalidated? → Move to Out of Scope with reason
2. Requirements validated? → Move to Validated with phase reference
3. New requirements emerged? → Add to Active
4. Decisions to log? → Add to Key Decisions
5. "What This Is" still accurate? → Update if drifted

**After each milestone** (via `/gsd-complete-milestone`):
1. Full review of all sections
2. Core Value check — still the right priority?
3. Audit Out of Scope — reasons still valid?
4. Update Context with current state

---
*Last updated: 2026-05-09 after Phase 4 completion*
