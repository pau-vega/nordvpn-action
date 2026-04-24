# Research Summary — nordvpn-actions

**Synthesized:** 2026-04-24
**Sources:** STACK.md, FEATURES.md, ARCHITECTURE.md, PITFALLS.md (all HIGH confidence)
**Reader contract:** Roadmapper reads only this file. Everything actionable for phase structure is here.

---

## 1. One-Liner

Port Tutellus PR #159's working `nordvpn-es` composite action to a public MIT-licensed monorepo on `pau-vega/nordvpn-actions`, add sibling `nordvpn-us` and `nordvpn-fr` with identical contract, wire release-please-driven per-region semver + floating-major automation, and ship an actionlint-enforced self-test that proves end-to-end egress without ever touching fork PRs' secret surface. Composite-only, Ubuntu-only, service-credentials-only — no JS, no Docker, no macOS/Windows, no `post:` teardown.

---

## 2. Stack (Verdict)

All entries pinned by 40-char SHA; all verified live 2026-04-24 via `GET /repos/<owner>/<repo>/git/ref/tags/<tag>`.

| Tool | Pin | Rationale |
|------|-----|-----------|
| `googleapis/release-please-action@v5.0.0` | `45996ed1f6d02564a971a2fa1b5860e934307cf7` | Canonical (archived predecessor redirects here); monorepo-native manifest model; v4 API-compatible. |
| `reviewdog/action-actionlint@v1.72.0` | `6fb7acc99f4a1008869fa8a0f09cfca740837d9d` | De facto workflow linter; runs inline-`run:` shellcheck automatically. |
| `ludeeus/action-shellcheck@2.0.0` | `00cae500b08a931fb5698e11e79bfbd38e612a38` | Lints standalone `scripts/*.sh` (gap actionlint does NOT cover). Stable, not abandoned. |
| `actions/checkout@v6.0.2` | `de0fac2e4500dabe0009e67214ff5f5447ce83dd` | Node 24 runner; required by release-please (fetch-depth 0) and self-test. |

**Release config shape (non-negotiable):**
- `release-type: "simple"` per region package (no `package.json`/`version.txt` — pitfall 8).
- `include-component-in-tag: true` + default `-` separator → `nordvpn-<region>-v<X.Y.Z>` tags matching the PROJECT.md pin contract. **Do NOT set `tag-separator: "@"`** (amarjanica example diverges here).
- `separate-pull-requests: true` — a fix to `nordvpn-fr` must never bump `nordvpn-es` (pitfall 9).
- `bump-minor-pre-major: true` + `bump-patch-for-minor-pre-major: true` to keep pre-1.0 versions sane.

**Floating major tag automation:** read per-component outputs `steps.rp.outputs['actions/nordvpn-es--release_created']` / `--tag_name` / `--major` (NOT the global `releases_created`, pitfall 11); matrix over regions; `git tag -fa` + `git push --force`. Component-prefixed only (`nordvpn-es-v1`) — **no bare `v1` tag** (pitfall 10).

**Self-test trigger:** `pull_request` only; **NEVER `pull_request_target`** (pitfall 2). Fork-skip guard job gates the matrix behind `github.event.pull_request.head.repo.full_name == github.repository`. `environment: Preview` scopes `NORDVPN_SERVICE_USERNAME` / `NORDVPN_SERVICE_PASSWORD`. `concurrency: group: nordvpn-selftest-${{ matrix.region }}-${{ github.ref }}`, `cancel-in-progress: false` (pitfall 16).

**Self-test reference form:** `uses: ./actions/nordvpn-${{ matrix.region }}` (local path). Decouples self-test from release-please entirely — either can ship green without the other.

**Exclusions that matter:** no Node toolchain, no Docker, no `commitlint`/husky (social enforcement via PR review), no `_shared/scripts/` abstraction at N=3 (duplicate + CI drift-check). See STACK.md "Alternatives Considered" and "What NOT to Use" for the full matrix.

---

## 3. Features Shipping in v1

**Table stakes (P1 — launch blockers):**
- Port `nordvpn-es` composite action (input/output contract frozen; sibling `disconnect/` sub-action with `if: always()` contract).
- Add `nordvpn-us` and `nordvpn-fr` mirrors (same contract, region-specific `.ovpn` + hardcoded ISO-2 code).
- Per-action README: Inputs / Outputs / Usage (with `if: always()` disconnect) / Versioning (SHA > tag > floating major) / Credential Rotation / Troubleshooting.
- Root README indexing all actions + pin-form guidance.
- LICENSE (MIT), CODEOWNERS (`/actions/** @pau-vega` — glob, not per-region literal — pitfall 18), `.github/dependabot.yml` (`directories:` plural, enumerated).
- `actions-lint` workflow (actionlint + shellcheck, required on PR).
- release-please manifest + config + workflow (per-region components).
- Floating major tag automation (`nordvpn-<region>-v<MAJOR>` force-moved per release).
- `AGENTS.md` (covers Conventional Commits scope rules, fork-safety posture, composite-`post:` gotcha, OS-only constraint).
- Branch protection on `main`: `actions-lint` required.

**Differentiators (P2 — v1.x, add as validation signals come in):**
- Self-test CI E2E workflow (matrix over ES/US/FR, `environment: Preview`, fork-skip, `concurrency:`). Triggers for adding: drift event OR first external consumer.
- Structured diagnostics outputs (`exit_ip`, `country`, `asn`, `tun0_state`, `default_route`, `connect_duration_ms`). Composite outputs are pre-declared (GitHub #10529).
- Two-provider geo verification (ipinfo + ifconfig.co; both must agree — pitfall 15). Port from source PR.
- Bounded retry on connect (2 attempts, 15s settle; explicit in-script, not `continue-on-error: true` — pitfall 24).
- `::notice::` + `$GITHUB_STEP_SUMMARY` diagnostics table.
- Weekly scheduled self-test (cron) as drift sentinel (pitfall 21).
- Badges (CI + release), pin-form matrix, Troubleshooting with real error strings ("AUTH_FAILED" → service credentials, pitfall 17).

**v2+ deferred:** marketplace publication, regions beyond ES/US/FR, dynamic `.ovpn` fetch (explicitly excluded — reproducibility value), cross-OS, IPv6, auto-generated README.

For the full anti-features rationale and exclusions, see FEATURES.md "Anti-Features" section.

---

## 4. Build Order

Phase structure is driven by three architectural constraints:

1. **Lint before code.** Every subsequent PR gets free validation.
2. **ES establishes the contract; US/FR are copies.** Port first, mirror second — doing in parallel multiplies review burden and risks contract drift.
3. **Release tooling is metadata; it plumbs over working code.** Self-test and release-please are independent by design (self-test uses local `./actions/...` refs) — release-please lands last so its first dry-run has three real regions to release.

Suggested phases:

1. **Phase 0 — Scaffolding & Lint.** LICENSE, root README skeleton, CODEOWNERS glob (pitfall 18), Dependabot `directories:` (pitfall 19), `actions-lint.yml` with actionlint + shellcheck strict. **Constraint:** lint must exist before any action code so every port PR is auto-validated (pitfalls 4, 6, 24, 25 all fire here).
2. **Phase 1 — Port nordvpn-es.** Copy `actions/nordvpn-es/{action.yml, scripts/*.sh, vpn/nordvpn-es.ovpn, README.md, disconnect/}` from Tutellus PR #159. Verify/harden: OS guard step (pitfall 13), `$GITHUB_ACTION_PATH/scripts/` (pitfall 4), `$RUNNER_TEMP` + `install -m 0600` auth file (pitfall 5), `openvpn-systemd-resolved` installed + DNS directives (pitfall 3), `--daemon` polling loop + tun0 IPv4 wait (pitfall 14), two-provider geo verify (pitfall 15), sibling `disconnect/` (pitfall 1), no `set -x` / no secret outputs (pitfall 6). **Constraint:** establishes the input/output contract frozen for the life of v1. Contract drift here = breaking v1 for US/FR.
3. **Phase 2 — Self-test workflow.** `pull_request` trigger (NEVER `pull_request_target` — pitfall 2), fork-skip guard job, `environment: Preview`, local `./actions/nordvpn-es` ref, `if: always()` disconnect, `concurrency:` group (pitfall 16), fork-PR friendly skip message (pitfall 22). Self-test runs against ES only in this phase — US/FR matrix entries come in Phase 3. **Constraint:** fork-safety must be correct day-one; retrofitting security after external contributors arrive is never as good.
4. **Phase 3 — Add nordvpn-us + nordvpn-fr.** Mirror the ES tree with region-specific `.ovpn` + hardcoded ISO-2. Expand self-test matrix to all three regions with `fail-fast: false`. Add CI drift-check diffing `scripts/*.sh` across regions (pitfall 20). **Constraint:** mirror, don't refactor — the `_shared/scripts/` temptation breaks the `uses:` pin contract and release-please scoping (ARCHITECTURE.md Anti-Pattern 1; PITFALLS.md pitfall 20).
5. **Phase 4 — release-please wiring.** `release-please-config.json` (`release-type: simple`, `include-component-in-tag: true`, `separate-pull-requests: true`, per-region `packages` stanzas), `.release-please-manifest.json` bootstrap at `0.0.0`, `release-please.yml` workflow with `fetch-depth: 0` (pitfall 27) and use the **canonical `googleapis/release-please-action`** not the archived `google-github-actions/` one (pitfall 7). **Constraint:** needs three real action dirs to validate per-region path scoping (pitfall 9); first merged release PR is the acceptance test.
6. **Phase 5 — Floating major tag automation.** Second job in the release-please workflow, matrix over regions, `fromJSON(paths_released)` or per-component `outputs['actions/nordvpn-es--major']` (NEVER substring-match `paths_released` — pitfall 11), `git tag -fa` + `git push --force`. Component-prefixed tags only (`nordvpn-es-v1`, not `v1` — pitfall 10, ARCHITECTURE.md Anti-Pattern 2). **Constraint:** must run strictly AFTER the release PR merges, never concurrent with release-please (pitfall 12).
7. **Phase 6 — READMEs & polish.** Per-action READMEs with SHA-pin-first examples (no `@main` — pitfall 23), Versioning section documenting floating-major mutability (pitfall 12), Troubleshooting with AUTH_FAILED + service-credentials hint (pitfall 17), root README index, badges, AGENTS.md. Branch protection finalized (`actions-lint` + self-test required on main). **Constraint:** v1 release gate — READMEs are the consumer-facing surface and the pin-form contract.

---

## 5. Top 8 Pitfalls to Prevent Up-Front

Ranked by cost-to-retrofit (highest first) when the default state would otherwise miss them. Each is cited to PITFALLS.md.

| # | Pitfall | Why upfront | Cite |
|---|---------|-------------|------|
| 1 | **Teardown in composite instead of sibling `disconnect/`** — composite actions don't support `post:`; the contract consumers write against (`uses: .../disconnect@v1` + `if: always()`) is frozen at Phase 1. Changing later is a breaking contract change on every region. | Pitfall 1 (Critical) |
| 2 | **`pull_request_target` anywhere in `.github/workflows/`** — one merged misconfiguration = secret exfiltration (GHSA-89qq-hgvp-x37m, 2026 hackerbot-claw campaign). Block in Phase 0 with a grep-CI check; retrofit is incident response, not refactor. | Pitfall 2 (Critical) |
| 3 | **DNS leak via missing `openvpn-systemd-resolved`** — IP check passes, DNS queries escape to clearnet. Silent correctness bug with a green badge. Must be in the Phase 1 port; verify-country.sh must add a DNS-egress check. | Pitfall 3 (Critical) |
| 4 | **Scripts referenced by relative `./scripts/` instead of `$GITHUB_ACTION_PATH/scripts/`** — works locally, breaks on every consumer. Bake `$GITHUB_ACTION_PATH` in from the port; add shellcheck/grep rule in Phase 0. | Pitfall 4 (Critical) |
| 5 | **Auth file under `$GITHUB_WORKSPACE` at 0644** — secret leaks across jobs on self-hosted; `actions/checkout` resets workspace mid-job. `$RUNNER_TEMP` + `install -m 0600` is the only correct shape. Verify in source PR at Phase 1 port. | Pitfall 5 (Critical) |
| 6 | **Using archived `google-github-actions/release-please-action`** — GitHub doesn't follow `uses:` redirects; archived action silently misbehaves on new config keys. Phase 4 mistake that propagates into every release PR. CI grep blocks it. | Pitfall 7 (Critical) |
| 7 | **Missing per-package path filters in release-please config** — a `feat(nordvpn-es):` commit bumps US and FR with empty changelogs; consumers' `@v1` pins auto-bump for nothing. Phase 4: three `packages` stanzas keyed by path, `separate-pull-requests: true`. | Pitfall 9 (Critical) |
| 8 | **CODEOWNERS per-region literal paths / Dependabot static directory list** — invisible ownership/update gaps when regions are added. Use `/actions/** @pau-vega` glob and Dependabot `directories:` list enumerated (plural key, 2024-06 GA). Phase 0 one-line setup. | Pitfalls 18, 19 (Moderate) |

The remaining 19 pitfalls (floating tag mutability contract, `paths_released` substring gotcha, `openvpn --daemon` race, single geo provider, `continue-on-error: true`, `@main` in README, non-Linux runner cryptic error, etc.) are cheap to prevent in their specific phase per PITFALLS.md "Pitfall-to-Phase Mapping" table. They matter — they're just not all as expensive to retrofit as the eight above.

---

## 6. Open Questions for Roadmap

The roadmapper needs a position on each of these before finalizing phase scope.

1. **Is self-test (E2E) a P1 for v1.0 launch or a P2 for v1.x?** FEATURES.md classifies it P2 ("add after validation — add v1.x once drift event or first external consumer"). STACK.md and ARCHITECTURE.md both write it as a first-class Phase 2 workflow. The answer determines whether Phase 2 is "Self-test infrastructure" or "Self-test deferred, ship Phase 3 directly." **Recommendation:** include it as P1 — shipping three regions without an E2E check invites the first `.ovpn` drift event to surface as a consumer issue, not a self-opened maintainer issue. One phase of upfront investment beats retrofit debt.

2. **Should Phase 0 land branch protection, or does that wait until Phase 6?** Branch protection requiring `actions-lint` on main makes sense from day 1 (pitfall prevention compounds). Requiring `self-test` as a check waits until Phase 2 exists. The roadmapper needs to split "enable protection with lint-only requirement" (Phase 0 end) from "add self-test to protection requirements" (Phase 2 end).

3. **Conventional-commits enforcement: social (review-only) or tooling (commitlint)?** STACK.md and FEATURES.md explicitly reject commitlint/husky as a Node-toolchain tax on a pure-Bash repo. PITFALLS.md pitfall 26 flags the risk and suggests a simple CI grep as middle ground. **Position needed:** ship with review-only (matches project ethos), OR add a 20-line grep-based CI check in Phase 0? If the answer is CI-grep, it belongs with actionlint, not in Phase 4.

4. **Structured diagnostics outputs (v1.x feature per FEATURES.md) — land in Phase 1 port, or defer to a v1.1 phase after launch?** Composite actions must pre-declare `outputs:` statically (GitHub #10529). Adding them later requires a minor version bump per region — not breaking, but coordinated across three regions. Landing them in Phase 1 (even with placeholder values) costs little and future-proofs the contract. **Recommendation:** declare outputs in Phase 1 `action.yml`, populate values in Phase 2/later.

5. **Weekly scheduled self-test (drift sentinel) — v1 or v1.x?** FEATURES.md marks it P2; PITFALLS.md pitfall 21 notes it's the only defense against `.ovpn` server decommission. Without it, the first broken region surfaces as a consumer issue. With it, it surfaces as a maintainer-opened auto-issue 6 weeks ahead. Low-cost (cron add-on to Phase 2's self-test workflow), high value. **Recommendation:** include as part of Phase 2's self-test workflow definition; trivial to add, meaningful drift insurance.

---

*Synthesis complete. Roadmapper: proceed to requirements definition. Revisit the five open questions before finalizing phase boundaries.*
