# Requirements: nordvpn-actions

**Defined:** 2026-04-24
**Core Value:** A caller can add one `uses:` line and be certain the next steps run from the declared country, or the job fails fast — no hand-written OpenVPN plumbing, no unverified exit IPs.

## v1 Requirements

Requirements for initial release. Each maps to exactly one roadmap phase.

### Repository Scaffolding (SCAF)

- [ ] **SCAF-01**: Repo has `LICENSE` (MIT) at root
- [ ] **SCAF-02**: Repo has root `README.md` indexing every shipped action with a link to each action's README
- [ ] **SCAF-03**: Repo has root `README.md` section explaining the three pin forms (SHA, exact tag `nordvpn-<region>-vX.Y.Z`, floating major `nordvpn-<region>-v<MAJOR>`) with recommendations for when to use each
- [ ] **SCAF-04**: Repo has `.github/CODEOWNERS` with `/actions/** @pau-vega` glob so new `actions/<region>/` directories are covered without per-region edits
- [ ] **SCAF-05**: Repo has `.github/dependabot.yml` with `github-actions` ecosystem and plural `directories:` key covering `/`, `/actions/nordvpn-es`, `/actions/nordvpn-es/disconnect`, `/actions/nordvpn-us`, `/actions/nordvpn-us/disconnect`, `/actions/nordvpn-fr`, `/actions/nordvpn-fr/disconnect`
- [ ] **SCAF-06**: Repo has `AGENTS.md` at root covering: Conventional Commits scope rules (per-region scope required), fork-safety posture, composite `post:` unavailability + sibling `disconnect/` contract, Ubuntu-only runner constraint, service-credentials-only auth requirement
- [ ] **SCAF-07**: Branch protection on `main` requires the `actions-lint` workflow checks before merge

### Linting CI (LINT)

- [ ] **LINT-01**: `.github/workflows/actions-lint.yml` runs on PRs that touch `actions/**` or `.github/workflows/**`
- [ ] **LINT-02**: Workflow runs `reviewdog/action-actionlint@<pinned-sha>` (v1.72.0) with `fail_on_error: true`
- [ ] **LINT-03**: Workflow runs `ludeeus/action-shellcheck@<pinned-sha>` (2.0.0) with strict severity over every `actions/*/scripts/` directory
- [ ] **LINT-04**: Workflow declares `permissions: contents: read` and a `concurrency:` group that cancels in-progress runs on the same ref
- [ ] **LINT-05**: Workflow prevents `pull_request_target` triggers anywhere in `.github/workflows/**` via a grep-based CI check (blocks the ACE class of attacks)

### NordVPN Spain Action (NVES)

- [ ] **NVES-01**: `actions/nordvpn-es/action.yml` declares `using: composite` with `name`, `description`, `inputs.username` (required), `inputs.password` (required)
- [ ] **NVES-02**: `action.yml` pre-declares six outputs: `exit-ip`, `country`, `asn`, `tun0-state`, `default-route`, `connect-duration-ms`, each wired to the verify step (composite outputs cannot be added dynamically post-release)
- [ ] **NVES-03**: Install step calls `actions/nordvpn-es/scripts/install.sh` via `$GITHUB_ACTION_PATH`; installs `openvpn` + `openvpn-systemd-resolved`, asserts `curl`/`jq`/`openvpn` on PATH
- [ ] **NVES-04**: Connect step writes credentials to `$RUNNER_TEMP/nordvpn-auth.txt` at mode `0600` via `install -m 0600`, starts `openvpn --daemon` against `actions/nordvpn-es/vpn/nordvpn-es.ovpn`, polls tun0 IPv4 assignment (30s timeout, 2s interval) AND waits for `Initialization Sequence Completed` in the openvpn logfile
- [ ] **NVES-05**: Connect step implements bounded retry: up to 2 attempts; between attempts runs disconnect cleanup; exits non-zero on final failure (no `continue-on-error: true`)
- [ ] **NVES-06**: Action pre-flights with an Ubuntu-runner guard: fails fast with a clear error if `$RUNNER_OS` is not `Linux`
- [ ] **NVES-07**: Verify step queries two independent geo-IP providers (ipinfo.io + ifconfig.co) and fails if either returns a country code other than `ES`
- [ ] **NVES-08**: Verify step emits all six output values to `$GITHUB_OUTPUT` AND a diagnostics table to `$GITHUB_STEP_SUMMARY` via `::notice::`
- [ ] **NVES-09**: Verify step includes a DNS-egress check: runs a DNS lookup and asserts the query went through the VPN tunnel (prevents the DNS-leak silent-success class of bug)
- [ ] **NVES-10**: `actions/nordvpn-es/disconnect/action.yml` is a sibling composite sub-action that kills openvpn and removes the auth file; runs in callers' workflow as a separate step with `if: always()` (composite `post:` is unavailable)
- [ ] **NVES-11**: No `set -x` in any script; no step output or log emits any secret; bash scripts all declare `set -euo pipefail`
- [ ] **NVES-12**: `actions/nordvpn-es/README.md` documents Inputs, Outputs, Usage (with the mandatory `if: always()` disconnect step), Versioning (three pin forms, SHA first), Credential Rotation (step-by-step for `NORDVPN_SERVICE_USERNAME` / `NORDVPN_SERVICE_PASSWORD` under `Preview` environment), and Troubleshooting (AUTH_FAILED → service credentials, country mismatch, fork PR skip)
- [ ] **NVES-13**: README never recommends `@main`; floating-major-tag mutability is explicitly documented in the Versioning section so consumers pin SHA for reproducibility

### NordVPN US Action (NVUS)

- [ ] **NVUS-01**: `actions/nordvpn-us/` mirrors `actions/nordvpn-es/` tree shape (`action.yml`, `scripts/*.sh`, `vpn/nordvpn-us.ovpn`, `README.md`, `disconnect/action.yml`)
- [ ] **NVUS-02**: Input/output contract is identical to `nordvpn-es` (same input names, same six output names)
- [ ] **NVUS-03**: Verify step hard-checks the expected country is `US` against both geo-IP providers
- [ ] **NVUS-04**: Bundled `vpn/nordvpn-us.ovpn` is a valid, tested US NordVPN OpenVPN profile pinned at port in the repo
- [ ] **NVUS-05**: Action-specific README mirrors `nordvpn-es/README.md` structure with `US` substitutions and the correct `uses:` path

### NordVPN France Action (NVFR)

- [ ] **NVFR-01**: `actions/nordvpn-fr/` mirrors `actions/nordvpn-es/` tree shape (`action.yml`, `scripts/*.sh`, `vpn/nordvpn-fr.ovpn`, `README.md`, `disconnect/action.yml`)
- [ ] **NVFR-02**: Input/output contract is identical to `nordvpn-es` (same input names, same six output names)
- [ ] **NVFR-03**: Verify step hard-checks the expected country is `FR` against both geo-IP providers
- [ ] **NVFR-04**: Bundled `vpn/nordvpn-fr.ovpn` is a valid, tested FR NordVPN OpenVPN profile pinned at port in the repo
- [ ] **NVFR-05**: Action-specific README mirrors `nordvpn-es/README.md` structure with `FR` substitutions and the correct `uses:` path

### Release & Versioning (REL)

- [ ] **REL-01**: `.github/release-please-manifest.json` tracks per-region versions (`actions/nordvpn-es`, `actions/nordvpn-us`, `actions/nordvpn-fr`) seeded at `0.0.0`
- [ ] **REL-02**: `.github/release-please-config.json` defines three packages with `release-type: "simple"`, `include-component-in-tag: true`, `separate-pull-requests: true`, `bump-minor-pre-major: true`, `bump-patch-for-minor-pre-major: true`
- [ ] **REL-03**: Each package has a `changelog-sections` array with `feat`, `fix`, `docs`, `refactor`, `perf` visible; `chore`, `test`, `ci`, `style` hidden
- [ ] **REL-04**: `.github/workflows/release-please.yml` runs on push to `main`, uses the canonical `googleapis/release-please-action@<pinned-sha>` (v5.0.0), and has `permissions: contents: write, pull-requests: write`
- [ ] **REL-05**: Workflow uses `actions/checkout@<pinned-sha>` with `fetch-depth: 0` so release-please sees the full commit history
- [ ] **REL-06**: Release tags are produced in the form `nordvpn-<region>-vX.Y.Z` (no bare `vX.Y.Z`, no `<region>@X.Y.Z`)
- [ ] **REL-07**: A `tag-floating-major` job runs after release-please in the same workflow; reads per-component outputs (`outputs['actions/nordvpn-<region>--release_created']`, `--tag_name`, `--major`) — never substring-matches `paths_released`
- [ ] **REL-08**: `tag-floating-major` job matrixes over regions, force-moves per-component tags `nordvpn-<region>-v<MAJOR>` via `git tag -fa` + `git push --force`; no bare `v<MAJOR>` tags are created

### Self-Test CI (TEST)

- [ ] **TEST-01**: `.github/workflows/self-test.yml` triggers on `push` to `main`, `pull_request`, and `schedule` (weekly cron drift sentinel); never uses `pull_request_target`
- [ ] **TEST-02**: Workflow has a fork-skip guard job that gates the matrix behind `github.event.pull_request.head.repo.full_name == github.repository`; forks get a clear `::notice::` skip message
- [ ] **TEST-03**: Matrix test job runs across all three regions (`nordvpn-es`, `nordvpn-us`, `nordvpn-fr`) with `fail-fast: false`
- [ ] **TEST-04**: Each matrix job references the action via local path (`uses: ./actions/nordvpn-${{ matrix.region }}`), not a tagged ref, so self-test is independent of release tooling
- [ ] **TEST-05**: Each matrix job runs the paired disconnect step with `if: always()` to prove the consumer contract works
- [ ] **TEST-06**: Workflow declares `environment: Preview` and reads `NORDVPN_SERVICE_USERNAME` / `NORDVPN_SERVICE_PASSWORD` from the Preview environment; secrets never echoed
- [ ] **TEST-07**: Workflow declares a `concurrency:` group keyed by region + ref with `cancel-in-progress: false` (prevents concurrent runs fighting for the same NordVPN session)
- [ ] **TEST-08**: Workflow emits a drift sentinel: the scheduled weekly run opens a GitHub issue on failure (labels it `region-drift`) so maintainer is alerted ahead of consumer impact
- [ ] **TEST-09**: Branch protection on `main` requires the `self-test` matrix jobs in addition to `actions-lint` once this phase ships

## v2 Requirements

Deferred. Not in current roadmap.

### Distribution (DIST)

- **DIST-01**: Publish actions to the GitHub Actions Marketplace (one listing per region, since marketplace doesn't fit monorepo listings cleanly)
- **DIST-02**: Badges for Marketplace listing in per-action READMEs
- **DIST-03**: Decision on marketplace listing form (per-region vs umbrella) once the action has landed and received external pull signals

### Additional Regions (REG)

- **REG-01**: `nordvpn-de` (Germany)
- **REG-02**: `nordvpn-uk` (United Kingdom)
- **REG-03**: `nordvpn-it` (Italy)
- **REG-04**: Generic `nordvpn` action with a `region` input (parametric; decide vs per-region actions after N=5+ regions)

### Automation & Polish (AUTO)

- **AUTO-01**: Conventional-commits CI grep check in addition to social PR review
- **AUTO-02**: `.ovpn` refresh automation: scheduled job checks NordVPN server health for each pinned profile, opens PR with replacement if decommissioned
- **AUTO-03**: Auto-generated action READMEs from `action.yml` inputs/outputs (e.g., `actionlint`-compatible doc generator)
- **AUTO-04**: Release-please configured to update README pin examples with the latest version automatically

## Out of Scope

Explicitly excluded. Do not reintroduce without revisiting the rationale.

| Feature | Reason |
|---------|--------|
| Runners other than `ubuntu-latest` (macOS / Windows) | Scripts are `apt-get`-based and depend on `ip`, `systemd-resolved`, `openvpn-systemd-resolved`. Cross-OS abstraction is disproportionate work for v1. |
| Docker-based or JavaScript-based action implementations | Composite is sufficient and minimal; no runtime/toolchain to version. |
| Dynamic `.ovpn` fetching at runtime from NordVPN API | Extra network failure mode and not reproducible. Bundled profiles + drift cron (TEST-08) handle the drift risk. |
| IPv6 egress verification | NordVPN OpenVPN profiles don't guarantee IPv6 egress; keeping the verify surface to IPv4 only. |
| NordVPN account email/password as action inputs | Manual OpenVPN does not authenticate with account credentials (NordVPN disabled this 2023-06); only dashboard-issued service credentials work. |
| `post:` teardown inside the composite action | Not supported by GitHub for composite actions (community discussion #26743). Consumers must use the sibling `disconnect/` sub-action with `if: always()`. |
| Fork PR end-to-end self-test runs | Fork-safety is deliberate. Fork contributors cannot reach `Preview` environment secrets. Forks skip with a clear message; no secret leak. |
| `_shared/` script abstraction across regions | At N=3, duplication + CI drift-check is cheaper than the pin-path/release-please complications a shared dir introduces. Revisit at N=5+. |
| `commitlint` / husky hooks | Would tax a pure-Bash repo with a Node toolchain for no proportional return. Social enforcement via PR review for now; a CI grep check is v2 (AUTO-01). |
| Marketplace listing in v1 | Requires single-action listing form, branded assets, and support expectation. Ship the action first; list after validation (v2: DIST-01). |
| Bare `v1` / `v2` floating tags | Unambiguous only in a single-action repo. In a monorepo with three regions, bare major tags collide. Only `<region>-v<MAJOR>` form is shipped. |

## Traceability

Maps each v1 requirement to exactly one phase. Populated by the roadmapper on 2026-04-24.

| Requirement | Phase | Status |
|-------------|-------|--------|
| SCAF-01 | Phase 1 | Pending |
| SCAF-02 | Phase 1 | Pending |
| SCAF-03 | Phase 1 | Pending |
| SCAF-04 | Phase 1 | Pending |
| SCAF-05 | Phase 1 | Pending |
| SCAF-06 | Phase 1 | Pending |
| SCAF-07 | Phase 1 | Pending |
| LINT-01 | Phase 1 | Pending |
| LINT-02 | Phase 1 | Pending |
| LINT-03 | Phase 1 | Pending |
| LINT-04 | Phase 1 | Pending |
| LINT-05 | Phase 1 | Pending |
| NVES-01 | Phase 2 | Pending |
| NVES-02 | Phase 2 | Pending |
| NVES-03 | Phase 2 | Pending |
| NVES-04 | Phase 2 | Pending |
| NVES-05 | Phase 2 | Pending |
| NVES-06 | Phase 2 | Pending |
| NVES-07 | Phase 2 | Pending |
| NVES-08 | Phase 2 | Pending |
| NVES-09 | Phase 2 | Pending |
| NVES-10 | Phase 2 | Pending |
| NVES-11 | Phase 2 | Pending |
| NVES-12 | Phase 2 | Pending |
| NVES-13 | Phase 2 | Pending |
| NVUS-01 | Phase 3 | Pending |
| NVUS-02 | Phase 3 | Pending |
| NVUS-03 | Phase 3 | Pending |
| NVUS-04 | Phase 3 | Pending |
| NVUS-05 | Phase 3 | Pending |
| NVFR-01 | Phase 3 | Pending |
| NVFR-02 | Phase 3 | Pending |
| NVFR-03 | Phase 3 | Pending |
| NVFR-04 | Phase 3 | Pending |
| NVFR-05 | Phase 3 | Pending |
| REL-01 | Phase 5 | Pending |
| REL-02 | Phase 5 | Pending |
| REL-03 | Phase 5 | Pending |
| REL-04 | Phase 5 | Pending |
| REL-05 | Phase 5 | Pending |
| REL-06 | Phase 5 | Pending |
| REL-07 | Phase 6 | Pending |
| REL-08 | Phase 6 | Pending |
| TEST-01 | Phase 4 | Pending |
| TEST-02 | Phase 4 | Pending |
| TEST-03 | Phase 4 | Pending |
| TEST-04 | Phase 4 | Pending |
| TEST-05 | Phase 4 | Pending |
| TEST-06 | Phase 4 | Pending |
| TEST-07 | Phase 4 | Pending |
| TEST-08 | Phase 4 | Pending |
| TEST-09 | Phase 4 | Pending |

**Coverage:**
- v1 requirements: 52 total (correcting an earlier draft that read "49"; authoritative count is this table)
- Mapped to phases: 52 (100%)
- Unmapped: 0

**Phase totals:**
- Phase 1 (Scaffolding & Lint): 12 requirements (SCAF-01..07, LINT-01..05)
- Phase 2 (Port nordvpn-es): 13 requirements (NVES-01..13)
- Phase 3 (Mirror nordvpn-us + nordvpn-fr): 10 requirements (NVUS-01..05, NVFR-01..05)
- Phase 4 (Self-test CI): 9 requirements (TEST-01..09)
- Phase 5 (release-please wiring): 6 requirements (REL-01..06)
- Phase 6 (Floating major tag automation): 2 requirements (REL-07..08)

---
*Requirements defined: 2026-04-24*
*Last updated: 2026-04-24 after roadmap creation (traceability populated)*
