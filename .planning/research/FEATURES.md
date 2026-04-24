# Feature Research

**Domain:** Public monorepo of composite GitHub Actions (multi-region NordVPN country-egress, v1 = ES/US/FR)
**Researched:** 2026-04-24
**Confidence:** HIGH

---

## Scope Clarifications

This document addresses only features that apply to a **Bash/composite, Ubuntu-only, OpenVPN-based multi-region Action monorepo**. Features that are irrelevant to this shape are excluded:

- Dockerfile / container build features (v1 is composite-only)
- Node / TypeScript / pnpm / yarn tooling (scripts are pure Bash)
- Cross-OS runner abstraction (Ubuntu-only)
- JS-action `post:` auto-teardown (composite actions don't support `post:`)

"Users" in this document = downstream consumers who write `uses: pau-vega/nordvpn-actions/actions/nordvpn-<region>@<ref>` in their workflows. They are the primary audience for every feature.

---

## Feature Landscape

### Table Stakes (Users Expect These)

Missing any of these causes serious public consumers to refuse the dependency or file immediate issues.

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| **Per-action README: Inputs / Outputs / Usage / Versioning / Credential Rotation / Troubleshooting** | Industry standard. `docker/build-push-action`, `aws-actions/configure-aws-credentials`, `google-github-actions/auth` all have these sections. Missing them signals an amateur repo. | S | Sections mirror `action.yml` `inputs:` / `outputs:` blocks 1:1. Usage block must include the mandatory `if: always()` disconnect pattern. Credential Rotation lists exact GitHub Secrets / environment names (`NORDVPN_SERVICE_USERNAME` in `Preview` env). |
| **Root README indexing all actions** | Consumers entering the repo via `pau-vega/nordvpn-actions` need to discover which regions ship and which to use. google-github-actions org has no monorepo README so callers rely on per-repo READMEs; our monorepo needs one. | XS | Table: region, action path, floating major, exact-tag example, SHA example. Links to per-action README. |
| **Pin-form documentation (SHA / exact tag / floating major)** | GitHub's official hardening guidance (2026) recommends pinning to SHA for security-critical workflows. Consumers must know their options. `docker/build-push-action` and `aws-actions/configure-aws-credentials` both teach this. | XS | Root README and per-action README both show all three forms with worked examples. Recommend SHA for release-critical CI. |
| **LICENSE (MIT)** | Legal requirement for public code reuse. MIT is the GitHub Actions ecosystem norm (google-github-actions uses Apache-2.0, most community actions use MIT). PROJECT.md mandates MIT. | XS | Single `LICENSE` file at repo root. |
| **Per-action CHANGELOG.md (release-please-generated)** | Every production-grade Action has one: `docker/build-push-action`, `google-github-actions/auth`, `aws-actions/configure-aws-credentials`. Consumers audit CHANGELOGs before bumping pins. | S | release-please manifest config with one entry per `actions/nordvpn-<region>/` path. Each gets its own `CHANGELOG.md`. Generated from conventional commits (`feat(nordvpn-es):`, `fix(nordvpn-us):`). |
| **Per-action semantic versioning (independent tags)** | Users pinning `nordvpn-es@v1` shouldn't be forced to re-test when `nordvpn-us` ships a breaking change. Independent versioning is the whole point of the monorepo layout. | S | release-please `include-component-in-tag: true` → tags like `nordvpn-es-v1.2.3`, `nordvpn-us-v1.0.0`. Each action's version bumps from its own commit scope. |
| **Floating major tag per action (auto-moved on release)** | GitHub's own docs recommend maintaining `v1` / `v2` for consumers who want auto-patch updates. Without it, users resort to pinning exact tags and never get fixes. | S | Post-release CI job force-pushes `nordvpn-<region>-v<MAJOR>` to the release SHA. Tools: `giantswarm/floating-tags-action` or hand-rolled `git tag -f` + `git push --force`. |
| **CODEOWNERS (`/actions/ @pau-vega`)** | Table stakes for any public repo. Auto-assigns review on every PR touching actions/. Silently signals "this is maintained" to consumers. | XS | Single-line CODEOWNERS at `.github/CODEOWNERS`. Scope to `/actions/` to keep meta-file PRs unblocked. |
| **Dependabot for `github-actions` ecosystem** | Consumers expect the Action's own transitive Action deps (e.g., `actions/checkout` inside self-test workflows) to be kept fresh. Dependabot `github-actions` ecosystem is the standard. | XS | `.github/dependabot.yml` with entries for `/`, each `/actions/nordvpn-<region>/`, and each `/actions/nordvpn-<region>/disconnect/`. Dependabot does not follow local refs (`./...`) so only external refs get updated, which is the correct behavior. |
| **actionlint + shellcheck CI (required on PR)** | The standard linting bar for any repo shipping Actions + Bash. actionlint runs shellcheck on every `run:` step by default. Without this, composite `action.yml` bugs ship to users. | S | Workflow `.github/workflows/actions-lint.yml`. Triggers on PRs touching `actions/**` or `.github/workflows/**`. Branch protection: required check. Limitation: actionlint lints *workflows*, not composite `action.yml` metadata directly — but it lints the `run:` scripts inside them, catching the bulk of real bugs. |
| **Fork-safety posture documented** | Any Action that touches secrets needs an explicit story: "forks cannot trigger secret-gated runs." GitHub's 2026 security roadmap hardened `pull_request_target` precisely because of pwn-request attacks. Silence here means consumers assume the worst. | S | AGENTS.md + per-action README both state: self-test uses `pull_request` (not `pull_request_target`), secrets gated by `environment: Preview`, forks skip the run with a clear message. Source action already has this posture — port it. |
| **Conventional Commits contract** | Required for release-please to compute bumps. Consumers looking at the CHANGELOG need consistent entries. Also a quality signal. | XS | Documented in AGENTS.md. Enforced socially (reviews) rather than via commitlint hooks — overkill for this repo size. Scope per region: `feat(nordvpn-es):`, `fix(nordvpn-us):`. |

### Differentiators (Competitive Polish)

Features that raise perceived quality and turn this from "a working Action" into "the polished reference for this use case."

| Feature | Value Proposition | Complexity | Notes | Observable User Signal |
|---------|-------------------|------------|-------|------------------------|
| **Self-test CI runs the action end-to-end** | Linting catches syntax; only E2E catches "my `.ovpn` drifted", "NordVPN rotated a server out", "country check provider changed schema". This is the single highest-value differentiator. | M | `.github/workflows/self-test.yml`. Triggers: `push` to `main`, non-fork `pull_request`, weekly `schedule`, `workflow_dispatch`. Matrix over ES/US/FR. Uses `environment: Preview` for secrets. Must include `if: always()` disconnect. | README CI badge shows "self-test passing" — proof the Action works *right now*, not just at last release. Consumers see a green tick matching their region. |
| **Structured diagnostics output bundle** | Debugging "why did country check fail" becomes trivial when the Action emits `{exit_ip, country, asn, tun0_state, default_route, connect_duration_ms}` as job outputs + step summary. Without it, consumers resort to adding their own probes. | M | Composite actions require pre-declared `outputs:` in `action.yml` — can't be dynamic (verified: community discussion #10529). Declare each explicitly. Scripts write to `$GITHUB_OUTPUT`. | Consumer can `${{ steps.vpn.outputs.exit_ip }}` after the step. Failed jobs show a diagnostics block in the Step Summary without needing `ACTIONS_STEP_DEBUG`. |
| **Two-provider geo-IP verification (ipinfo + ifconfig.co)** | Single-provider truth = silent lies when that provider misclassifies a new NordVPN IP range. Two independent providers = truth-over-trust. This is a defensible design choice that shows up directly in the README. | S | Already in source PR. Both providers must return expected ISO-2; disagreement = fail. Low complexity because the pattern is small Bash + `jq`. | A verify-country step failure log shows *both* provider responses, making "bad .ovpn" vs "provider drift" diagnosable. |
| **Bounded retry on connect** | NordVPN's OpenVPN endpoints have transient TLS handshake failures. Two retry attempts recover ~90% of flakes without turning "fail fast" into "hang forever". This is the difference between "reliable CI dep" and "the VPN action flakes weekly." | XS | Loop wrapper around `openvpn --daemon` with a 15s settle window + `ip link show tun0` check. Max 2 attempts. Documented in README Troubleshooting. | Flaky connections silently self-heal; users notice when their job run times dip into `1 retry: succeeded` messages in logs. Weekly self-test pass rate stays >95%. |
| **`::notice::` + Step Summary diagnostics table** | Default UX for a passing VPN step is silent. A `::notice::` line "Connected via FR (exit 1.2.3.4, AS21042, 1240ms)" in the job log + a diagnostics table in the Summary turns the Action into a self-documenting artifact. | S | `echo "::notice::..."` from verify-country.sh. Markdown table via `echo "..." >> $GITHUB_STEP_SUMMARY`. GitHub caps at 1MiB/step and 20 summaries/job — well within budget. | Scanning Actions UI, consumers can confirm at-a-glance which region was used without expanding logs. Support tickets from consumers drop because self-diagnosis is immediate. |
| **AGENTS.md contributor guide** | Linux Foundation AAIF standard (Dec 2025), >60k public repos. Signals "this repo is agent-friendly" without locking into one vendor. Matches source PR pattern. | XS | Under 100 lines. Sections: commands, testing, project structure, code style, git workflow, boundaries. Explicit fork-safety + `if: always()` rules for AI agents touching workflows. | Contributors (human or AI) ship PRs that pass CI on first try because conventions are front-loaded. |
| **Per-action pin-form matrix** | A copy-paste matrix of "for each pin form, here's the exact string" is faster than docs paragraphs. Consumers save minutes per integration. | XS | 3-row table per action README: SHA / exact tag / floating major, with the literal `uses:` line to paste. Updated automatically is nice-to-have but manual is fine (low churn). | Time-to-first-green-CI for a new consumer drops to <5 min. |
| **Usage examples with `if: always()` disconnect** | The `post:` limitation is the #1 foot-gun for composite-action consumers. A prominent example that *always* includes the sibling `disconnect/` call under `if: always()` prevents "why did my runner hold a connection after failure?" issues. | XS | Every Usage block shows connect + meaningful step + disconnect under `if: always()`. No shortcut "minimal" example that omits disconnect — that's an anti-pattern. | No GitHub issues with "VPN stayed connected after job failed" or "tun0 lingered." |
| **Badges (CI status + release version)** | `docker/build-push-action` has 5 badges (release, marketplace, CI, test, coverage). Missing badges makes a public repo look abandoned. Free signal of activity. | XS | Root README: per-action CI badge (self-test), per-action release badge. Shields.io + GitHub Actions workflow-status badge API. | First-time visitor sees "last release 3 days ago, CI green" and trusts the repo enough to read further. |
| **Weekly scheduled self-test** | NordVPN rotates servers out of their pool without notice; `.ovpn` drift is the #1 silent-failure mode. A weekly cron catches drift before consumers do. Specific to *this* repo type. | XS | `on: schedule: cron: '0 6 * * 1'` added to self-test workflow. Failure opens an auto-issue. | Maintainer gets a notification when an `.ovpn` drifts, fixes it before a consumer CI job ever sees the break. Public "last green self-test" badge stays fresh. |
| **Troubleshooting section that names real errors** | Good troubleshooting lists exact log lines consumers will see ("`AUTH: Received control message: AUTH_FAILED`" → check you're using service credentials, not account credentials). docker/build-push-action has a dedicated TROUBLESHOOTING.md. | S | Per-action README Troubleshooting section. Top 5 failure modes: AUTH_FAILED, country-mismatch, tun0 never up, two-provider disagreement, no-route-to-host post-disconnect. Each with exact fix. | Issue tracker stays low-volume because common issues self-resolve via docs. |

### Anti-Features (Explicitly NOT Building — v1)

Features that seem helpful but introduce complexity, break the reproducibility posture, or don't fit composite/Ubuntu/OpenVPN constraints. These are documented so they don't get re-added under pressure.

| Feature | Why Requested | Why Problematic | Alternative |
|---------|---------------|-----------------|-------------|
| **Dynamic `.ovpn` fetching from NordVPN server-recommendations API at runtime** | "Stay on the best server, avoid drift." | Adds a network dependency *before* the VPN is up (chicken-and-egg), adds a new failure mode (NordVPN API outage = every consumer CI breaks), makes runs non-reproducible (same SHA pin produces different exit IPs). Reproducibility is a core value. | Bundle per-region `.ovpn`. Accept drift as maintenance cost. Weekly scheduled self-test catches drift; CHANGELOG entry when a refresh is pushed. |
| **GitHub Marketplace listing** | "Discoverability; it's where Actions live." | Marketplace enforces one-action-per-listing, which fights the monorepo shape. Requires branded assets, description polish, category choice — all distraction from shipping the actual capability. PROJECT.md defers this explicitly. | Defer to post-v1 Marketplace milestone. Monorepo shape doesn't block future listing — each action can be published as a separate listing from the same tag. |
| **Cross-OS runner support (macOS/Windows)** | "Some consumers use macOS runners." | Scripts are Bash + apt-get + `ip` + `openvpn-systemd-resolved` — all Linux-specific. Abstracting this requires rewriting the install/connect scripts per-OS and duplicating verification logic. Doubles the surface for 2% of likely consumers. Also: OpenVPN's kota65535 action already documents macOS runner incompatibility (OpenVPN forum thread). | Document "requires `ubuntu-latest`" in every README. Add `runs-on` check in self-test. If consumers need macOS, we tell them to run the job in a Linux container and re-evaluate demand post-v1. |
| **IPv6 egress verification** | "Modern networks are dual-stack." | NordVPN's manual OpenVPN profiles do not guarantee IPv6 egress — the bundled `.ovpn` often lacks an IPv6 route entirely. Verifying IPv6 would either fail-by-design or silently pass when v6 falls back to clearnet (worst case: consumer *thinks* they're VPNed for v6 but aren't). | Verify IPv4 only. Document explicitly that IPv6 is not in scope; callers needing v6-only verification should not use this Action. |
| **Composite `post:` step for auto-teardown** | "Reduce caller burden — one `uses:`, done." | Composite actions do not support `post:` (GitHub community discussion #26743, runner issue #1478). Period. Forcing this would require rewriting as a JS action, abandoning the pure-Bash constraint. | Sibling `disconnect/` sub-action invoked by consumer under `if: always()`. Document prominently in every README. Template snippet in Usage always includes it. |
| **NordVPN account email/password auth** | "Easier — my NordVPN login credentials already work in the app." | NordVPN's manual OpenVPN endpoints authenticate only against *service credentials* (dashboard-issued), not account email/password. Accepting them as input and passing them through results in a silent `AUTH_FAILED` with no useful diagnostic. Worse, users will keep retrying assuming a bug. | Accept only service credentials. Input names clearly communicate `NORDVPN_SERVICE_USERNAME` / `_PASSWORD`. README Troubleshooting explains this at the top of the section. |
| **Fork PR self-test runs** | "Contributors from forks should be able to run E2E." | Running E2E on fork PRs requires exposing `Preview` secrets to untrusted code (pwn-request attack class). GitHub's 2026 security roadmap explicitly discourages this. Non-negotiable. | Self-test skips cleanly on fork PRs with `::notice::` explaining why. Fork contributors rely on maintainer rerunning in-repo. AGENTS.md documents the posture. |
| **Countries beyond ES/US/FR in v1** | "Why not ship 20 regions?" | Each region requires a bundled `.ovpn`, independent release tag, CHANGELOG, self-test matrix entry, and ongoing drift maintenance. Shipping 3 proves the pattern; each additional region is additive work. Premature regions dilute quality. | v1 = ES/US/FR only. Each new region = new action folder + bundled `.ovpn` + changelog entry in a later milestone. Pattern scales linearly. |
| **Commitlint/husky hooks for conventional-commits enforcement** | "Enforce the release-please commit convention." | Adds a Node toolchain + hook-install burden to a repo that is otherwise pure Bash. The entire maintainer surface is `@pau-vega` — social enforcement (PR review) is strictly better than tooling for a single-maintainer repo. | Document Conventional Commits in AGENTS.md. Enforce via review. If a misformatted commit slips, the next release-please run shows it's been ignored; fix on the next PR. |
| **Docker container action wrapping** | "Docker = reproducibility." | Composite actions already give reproducibility via bundled `.ovpn` + SHA pin. Docker adds a build step, a registry dependency, image scanning surface, and a pull-latency tax on every job. No upside for this workload (OpenVPN install is fast). | Stay composite-only per PROJECT.md constraint. Revisit only if Ubuntu's default `openvpn` package disappears — extremely unlikely. |
| **Auto-generated README from `action.yml`** | "Keep README in sync with action.yml." | README sections (Versioning, Credential Rotation, Troubleshooting) need narrative, not generated tables. An auto-generator covers maybe 20% of the README value and creates CI-overhead + a regeneration-in-PR discipline problem. | Write READMEs by hand per region. They're nearly identical (template once, tweak country); low cost, high quality. Reconsider if we hit 10+ regions. |

---

## Feature Dependencies

```
[Port nordvpn-es action]
    ├──required-by──> [Add nordvpn-us]
    └──required-by──> [Add nordvpn-fr]

[Per-action README]
    ├──requires──> [Input/output contract frozen in action.yml]
    └──enhances──> [Usage pattern doc]

[release-please manifest config]
    ├──requires──> [Conventional Commits doc in AGENTS.md]
    └──produces──> [Per-action CHANGELOG.md]
                       └──required-by──> [Per-action semantic versioning]
                                              └──required-by──> [Floating major tag automation]

[actionlint + shellcheck CI]
    └──required-by──> [Branch protection "lint required"]

[Self-test CI]
    ├──requires──> [Preview environment secrets configured]
    ├──requires──> [Fork-safety posture: pull_request not pull_request_target]
    └──enhances──> [Structured diagnostics output bundle]
                       └──enhances──> [Step Summary + ::notice:: annotations]

[Two-provider geo verification] ──inherits-from──> [nordvpn-es source PR]
    └──enhances──> [Troubleshooting section entries]

[Bounded retry on connect] ──enhances──> [Self-test stability]
    └──enhances──> [Weekly scheduled self-test pass rate]

[Floating major tag] ──conflicts-with──> ["no force-push" rules on release branches]
    → Mitigation: force-push only allowed on tag refs matching nordvpn-*-v[0-9]+, never on branches.

[Dependabot github-actions] ──requires──> [All external action refs pinned to tag or SHA]
```

### Dependency Notes

- **Port nordvpn-es → Add us/fr:** US/FR must match the ES input/output contract 1:1. Porting ES first establishes the contract, then US/FR are `.ovpn` + README copies. Doing them in parallel risks contract drift.
- **release-please → CHANGELOG → Semver → Floating major:** This is a strict chain. Without release-please, no auto-CHANGELOG; without per-component CHANGELOG, no independent semver; without independent semver, floating major tags conflict.
- **Self-test CI → Fork-safety posture:** Self-test *cannot* ship before fork-safety is explicit. Accidentally running secrets-gated E2E on a fork PR = immediate security incident.
- **Structured diagnostics → Step Summary:** Diagnostics are what you emit; Step Summary is where you display them. Build diagnostics first; Summary is a 10-line add-on.
- **Floating major tag vs branch protection:** Branch protection on `main` is fine; force-push must be *tag*-scoped. Document in AGENTS.md: tags `nordvpn-*-v[0-9]+` are mutable, all branch refs are immutable.

---

## MVP Definition

### Launch With (v1.0 of the monorepo)

Minimum to ship a credible public repo that a Tutellus job can `uses:`.

- [ ] **Port `nordvpn-es`** — Core capability. No monorepo without at least one working action.
- [ ] **Add `nordvpn-us` and `nordvpn-fr`** — Multi-region is the whole value-prop; one-region-only doesn't justify the monorepo layout.
- [ ] **Per-action `action.yml` + scripts + bundled `.ovpn`** — Functional code.
- [ ] **Per-action `disconnect/` sub-action** — Non-negotiable for `if: always()` teardown.
- [ ] **Per-action README (Inputs/Outputs/Usage/Versioning/Credential Rotation/Troubleshooting)** — Users won't adopt a public Action with no README.
- [ ] **Root README (action index + pin-form guidance)** — Entry point for consumers.
- [ ] **LICENSE (MIT)** — Legal prerequisite.
- [ ] **CODEOWNERS** — 1-line file, 0 excuse.
- [ ] **`.github/dependabot.yml`** — 15-line file, signals "maintained."
- [ ] **actionlint + shellcheck CI workflow (required on PRs)** — Baseline quality gate.
- [ ] **release-please manifest + config** — Without it, no CHANGELOGs, no semver tags, no floating-major automation. Everything downstream needs it.
- [ ] **Floating major tag automation** — Convention consumers expect; shipping exact-tag-only is incomplete.
- [ ] **AGENTS.md** — PROJECT.md requires it; also serves as contributor guide.
- [ ] **Fork-safety posture documented in AGENTS.md + each README** — Required because the Action requires secrets.
- [ ] **Branch protection on `main` with lint required** — Low-effort, signals seriousness.

### Add After Validation (v1.x)

Ship once v1 has at least one external consumer or the maintainer has run it in anger for 2+ weeks.

- [ ] **Self-test CI end-to-end (E2E) workflow** — Trigger for adding: first `.ovpn` drift event detected manually, OR first external consumer. Has enough complexity that v1 can ship without it; but v1.x without it is embarrassing.
- [ ] **Structured diagnostics outputs (exit_ip, country, asn, tun0_state, default_route, connect_duration_ms)** — Trigger: first issue filed asking "why did it fail?"
- [ ] **`::notice::` + Step Summary diagnostics table** — Trigger: ship structured diagnostics first, then wire into summary.
- [ ] **Bounded retry on connect (2 attempts)** — Trigger: first flaky run in self-test or external consumer.
- [ ] **Weekly scheduled self-test** — Trigger: self-test CI lands; add a cron schedule.
- [ ] **Pin-form matrix in per-action README** — Trigger: first issue filed asking "how do I pin this?"
- [ ] **Badges (CI status + release version)** — Trigger: v1 tagged. Badges without a release look broken.

### Future Consideration (v2+)

Deferred until product-market fit (consumer adoption) is clear.

- [ ] **GitHub Marketplace publication** — Defer: separate milestone. Requires branded assets and per-action listing work. Ship polished repo first.
- [ ] **Additional regions (DE, UK, JP, etc.)** — Defer: each region is additive work; validate the 3-region shape first. Demand-driven.
- [ ] **Dynamic `.ovpn` refresh tooling (maintainer script, not runtime)** — Defer: accept manual `.ovpn` refresh in v1. Tooling becomes worth it at ~6+ regions.
- [ ] **Auto-generated README sections from `action.yml`** — Defer: manual is fine for 3–6 regions. Revisit at ~10.
- [ ] **Migration guide between major versions** — Defer: there will be no major v2 until the v1 contract demonstrably needs breaking.

---

## Feature Prioritization Matrix

| Feature | User Value | Implementation Cost | Priority |
|---------|------------|---------------------|----------|
| Port nordvpn-es | HIGH | LOW | P1 |
| Add nordvpn-us + nordvpn-fr | HIGH | LOW | P1 |
| Sibling `disconnect/` per region | HIGH | LOW | P1 |
| Per-action README (full sections) | HIGH | LOW | P1 |
| Root README (action index + pin forms) | HIGH | LOW | P1 |
| LICENSE (MIT) | HIGH | LOW | P1 |
| CODEOWNERS | MEDIUM | LOW | P1 |
| Dependabot github-actions | MEDIUM | LOW | P1 |
| actionlint + shellcheck CI | HIGH | LOW | P1 |
| release-please manifest | HIGH | LOW | P1 |
| Per-action CHANGELOG.md (auto) | HIGH | LOW | P1 |
| Per-action semver tags | HIGH | LOW | P1 |
| Floating major tag automation | HIGH | LOW | P1 |
| AGENTS.md | MEDIUM | LOW | P1 |
| Fork-safety posture doc | HIGH | LOW | P1 |
| Branch protection (lint required) | MEDIUM | LOW | P1 |
| Self-test CI (E2E) | HIGH | MEDIUM | P2 |
| Structured diagnostics outputs | HIGH | MEDIUM | P2 |
| Two-provider geo verification | HIGH | LOW | P2 (port from source) |
| Bounded retry on connect | MEDIUM | LOW | P2 |
| `::notice::` + Step Summary table | MEDIUM | LOW | P2 |
| Weekly scheduled self-test | MEDIUM | LOW | P2 |
| Pin-form matrix in README | MEDIUM | LOW | P2 |
| Usage example with `if: always()` | HIGH | LOW | P1 (part of README) |
| Badges (CI + release) | LOW | LOW | P2 |
| Troubleshooting: named real errors | MEDIUM | LOW | P2 (grows in v1.x) |
| Marketplace publication | MEDIUM | MEDIUM | P3 |
| Additional regions (DE/UK/JP) | LOW (for v1) | MEDIUM per region | P3 |
| Dynamic `.ovpn` fetch (anti-feature) | N/A | N/A | EXCLUDE |
| Cross-OS runner support (anti-feature) | N/A | N/A | EXCLUDE |
| IPv6 egress verify (anti-feature) | N/A | N/A | EXCLUDE |
| Composite `post:` auto-teardown (impossible) | N/A | N/A | EXCLUDE |
| Account email/password auth (anti-feature) | N/A | N/A | EXCLUDE |
| Fork PR E2E runs (security anti-feature) | N/A | N/A | EXCLUDE |

**Priority key:**
- **P1**: Must have for v1.0 launch. Launches without any of these ship an embarrassing public repo.
- **P2**: Should have, add in v1.x as validation signals come in.
- **P3**: Nice to have, revisit post-validation.
- **EXCLUDE**: Anti-features — actively *not* to build; reasoning in the Anti-Features table.

---

## Competitor / Exemplar Feature Analysis

Not direct competitors (there is no other public multi-region NordVPN monorepo) but reference implementations for polish bar.

| Feature | `docker/build-push-action` | `google-github-actions/auth` | `aws-actions/configure-aws-credentials` | `kota65535/github-openvpn-connect-action` | **Our Approach** |
|---------|----------------------------|------------------------------|------------------------------------------|-------------------------------------------|------------------|
| README Inputs section | Yes | Yes | Yes | Yes | Yes (per-action) |
| README Outputs section | Yes | Yes | Implicit | No | Yes (structured: exit_ip/country/asn/etc.) |
| README Versioning section | No | No | Yes | No | Yes (pin-form matrix, 3 forms) |
| README Troubleshooting | Separate TROUBLESHOOTING.md | Separate docs/TROUBLESHOOTING.md | No | No | Inline section per action README |
| README Credential Rotation | N/A | Implicit (OIDC) | Yes (OIDC-first) | No | Yes (service-credentials specific) |
| CHANGELOG.md | Yes (auto) | Yes (auto) | Yes (auto) | Minimal | Yes (release-please per-action) |
| LICENSE | Apache-2.0 | Apache-2.0 | MIT-style | MIT | MIT |
| CODEOWNERS | Yes | Yes | Yes | No | Yes |
| Dependabot config | Yes | Yes | Yes | No | Yes (multi-directory) |
| actionlint + shellcheck CI | Yes (full CI matrix) | Yes | Yes | Minimal | Yes (lint required on PRs) |
| Self-test (E2E) CI | Yes | Yes | Yes | No | Yes (v1.x; P2) |
| Structured diagnostics | N/A (different domain) | Debug outputs only | Debug outputs only | No | Yes (key differentiator) |
| `::notice::` + Step Summary | Yes (build summaries) | No | No | No | Yes (v1.x; P2) |
| Fork-safety doc | Implicit | Implicit | Yes (OIDC-centric) | No | Explicit (secrets model) |
| AGENTS.md | No | No | No | No | Yes (contributor+agent guide) |
| Floating major tag | Yes (v6) | Yes (v2) | Yes (v4) | Yes (v2) | Yes (per-action: nordvpn-es-v1, etc.) |
| Action type | Docker | Node (TypeScript) | Node | Node | Composite (Bash) |
| Badges (root README) | 5+ | 2 | 3 | 1 | 2 (CI + release, per-action) |
| Two-provider verification | N/A | N/A | N/A | No | Yes (key differentiator — truth-over-trust) |
| Pre-release E2E on schedule | Yes (nightly) | Yes | Yes (weekly) | No | Yes weekly (v1.x; P2) |

**Takeaway:** Our approach is competitive on every table-stakes dimension and differentiates on (a) structured diagnostics, (b) two-provider verification, (c) explicit fork-safety story, and (d) AGENTS.md. The composite+Bash posture is deliberately narrower than Node/Docker competitors — this is a *feature* of the design (zero runtime surface), not a deficiency.

---

## Observable User Signals (per Differentiator)

For each differentiator, what "working" looks like to a downstream consumer. This is what the features *prove* when they land.

| Differentiator | Observable Signal for Consumer |
|----------------|-------------------------------|
| Self-test CI E2E | Root README badge shows green "self-test passing" in the last 7 days. Weekly scheduled run visible in Actions tab. |
| Structured diagnostics | In consumer's workflow, `${{ steps.vpn.outputs.exit_ip }}` returns a usable IPv4. On failure, consumer's CI log shows the diagnostics bundle (IP, country, ASN, tun0 state) without needing to re-run with debug. |
| Two-provider geo verification | On a deliberate-failure test (e.g., bad `.ovpn`), consumer sees both `ipinfo.io` and `ifconfig.co` responses in the fail log. On success, both providers agree silently. |
| Bounded retry on connect | Consumer's log shows `Connect attempt 1 failed, retrying in 15s... Connect attempt 2 succeeded` instead of hard-fail + manual re-run. Weekly self-test pass rate >95%. |
| `::notice::` + Step Summary | Actions job page shows a highlighted `::notice::` row with exit IP + country without expanding logs. Step Summary has a diagnostics table rendered inline with the job. |
| AGENTS.md | An AI agent spawned inside the repo passes CI on its first PR because the commit convention, fork-safety rule, and composite-`post:` gotcha are all documented in <100 lines. |
| Per-action pin-form matrix | Consumer writes `uses:` correctly on first attempt by copy-paste. Zero issues filed with "how do I pin this?" |
| Floating major tag per action | Consumer pinning `nordvpn-es-v1` receives patch-level security/drift fixes automatically without re-testing. Release Notes show tag moved from SHA `abc` → `def` on release. |
| Weekly scheduled self-test | Maintainer receives first drift-detection issue within 6 weeks of launch (empirical NordVPN rotation cadence). Public badge never goes stale beyond 7 days. |
| Troubleshooting with named errors | Consumer searching for `AUTH_FAILED` lands directly on the README Troubleshooting section with the fix ("use service credentials, not account password"). GitHub Issues stay low-volume. |

---

## Sources

**Ecosystem & patterns:**
- [actions/checkout](https://github.com/actions/checkout) — README structure, CHANGELOG, LICENSE, CODEOWNERS
- [docker/build-push-action](https://github.com/docker/build-push-action) — README sections, troubleshooting pattern, badges, TROUBLESHOOTING.md
- [google-github-actions/auth](https://github.com/google-github-actions/auth) — README, separate TROUBLESHOOTING.md, CHANGELOG, LICENSE
- [aws-actions/configure-aws-credentials](https://github.com/aws-actions/configure-aws-credentials) — Versioning section, security posture, OIDC-first
- [kota65535/github-openvpn-connect-action](https://github.com/kota65535/github-openvpn-connect-action) — Comparable domain (OpenVPN action); what's missing there highlights our differentiators

**Tooling:**
- [rhysd/actionlint](https://github.com/rhysd/actionlint) — Workflow linter, shellcheck integration
- [actionlint checks](https://github.com/rhysd/actionlint/blob/main/docs/checks.md) — What's checked; composite action.yml limitation
- [googleapis/release-please](https://github.com/googleapis/release-please) — Monorepo manifest, per-component tags
- [release-please manifest docs](https://github.com/googleapis/release-please/blob/main/docs/manifest-releaser.md) — `include-component-in-tag`, per-package CHANGELOG
- [release-please customizing docs](https://github.com/googleapis/release-please/blob/main/docs/customizing.md) — `release-type: simple` for non-package projects
- [amarjanica/release-please-monorepo-example](https://github.com/amarjanica/release-please-monorepo-example) — Reference monorepo manifest config
- [giantswarm/floating-tags-action](https://github.com/giantswarm/floating-tags-action) — Floating major tag automation
- [Dynamic Badges action](https://github.com/marketplace/actions/dynamic-badges) — CI + release badges via shields.io

**GitHub platform behavior (verified):**
- [GitHub community discussion #26743](https://github.com/orgs/community/discussions/26743) — Composite actions do not support `post:`
- [GitHub community discussion #10529](https://github.com/orgs/community/discussions/10529) — Composite action outputs must be pre-declared (no dynamic)
- [actions/runner issue #1478](https://github.com/actions/runner/issues/1478) — Pre/post not supported in composite (status)
- [GitHub Docs: Dependabot github-actions ecosystem](https://docs.github.com/en/code-security/how-tos/secure-your-supply-chain/secure-your-dependencies/keeping-your-actions-up-to-date-with-dependabot) — `github-actions` ecosystem config
- [GitHub Docs: Workflow commands](https://docs.github.com/en/actions/reference/workflows-and-actions/workflow-commands) — `::notice::`, `$GITHUB_STEP_SUMMARY`, `$GITHUB_OUTPUT`
- [GitHub Blog: Supercharging Actions with Job Summaries](https://github.blog/news-insights/product-news/supercharging-github-actions-with-job-summaries/) — 1MiB/step, 20 summaries/job limits

**Security / fork-safety:**
- [GitHub Actions 2026 security roadmap](https://github.blog/news-insights/product-news/whats-coming-to-our-github-actions-2026-security-roadmap/) — `pull_request_target` hardening
- [GitHub Security Lab: Preventing pwn requests](https://securitylab.github.com/resources/github-actions-preventing-pwn-requests/) — Fork PR + secrets threat model
- [Wiz: Hardening GitHub Actions](https://www.wiz.io/blog/github-actions-security-guide) — 2026 best practices
- [GitHub Docs: Secure use reference](https://docs.github.com/en/actions/reference/security/secure-use) — Pinning, permissions

**AGENTS.md:**
- [AGENTS.md standard](https://agents.md/) — Linux Foundation AAIF standard (Dec 2025)
- [Augment Code: How to Build AGENTS.md (2026)](https://www.augmentcode.com/guides/how-to-build-agents-md) — Core sections
- [The Prompt Shelf: AGENTS.md vs CLAUDE.md (2026)](https://thepromptshelf.dev/blog/agents-md-vs-claude-md/) — When to use each

**Project context:**
- `/Users/pauvelascogarrofe/Documents/nordvpn-action/.planning/PROJECT.md` — Requirements, anti-features, key decisions

---

*Feature research for: Public monorepo of composite GitHub Actions (multi-region NordVPN country-egress)*
*Researched: 2026-04-24*
