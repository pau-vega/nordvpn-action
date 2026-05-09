# Phase 4: Self-test CI - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-05-08
**Phase:** 04-self-test-ci
**Areas discussed:** Branch protection check naming, Workflow trigger scope, Drift issue behavior, Post-connect defense-in-depth

---

## Branch Protection Check Naming

| Option | Description | Selected |
|--------|-------------|----------|
| Override with static name | Set explicit `name: nordvpn-es self-test` per matrix entry | |
| Use matrix display name | Let GitHub auto-generate `self-test (nordvpn-es)` from matrix key | ✓ |

**User's choice:** Use matrix display name (auto-generated)
**Notes:** Standard GitHub behavior — check names are `self-test (nordvpn-es)`, `self-test (nordvpn-us)`, `self-test (nordvpn-fr)`.

| Option | Description | Selected |
|--------|-------------|----------|
| Inline the 3 new names | Append to existing REQUIRED_CHECKS_JSON in setup-branch-protection.sh | ✓ |
| Separate variable + concat | Define SELF_TEST_CHECKS_JSON separately, concatenate | |

**User's choice:** Inline into existing array. 6 total checks.

---

## Workflow Trigger Scope

| Option | Description | Selected |
|--------|-------------|----------|
| Path-filtered | PRs touching `actions/**, .github/workflows/**` only | ✓ |
| All PRs | Run on every PR regardless of files changed | |

**User's choice:** Path-filtered, same filter as actions-lint.yml.

| Option | Description | Selected |
|--------|-------------|----------|
| Monday 08:00 UTC | `0 8 * * 1` — start of work week | ✓ |
| Sunday 00:00 UTC | `0 0 * * 0` — weekend run | |

**User's choice:** Monday 08:00 UTC.

| Option | Description | Selected |
|--------|-------------|----------|
| Yes, include workflow_dispatch | Manual trigger for testing after credential rotation | ✓ |
| No | Triggers only | |

**User's choice:** Include `workflow_dispatch`.

| Option | Description | Selected |
|--------|-------------|----------|
| main only | Push to main only — PR runs cover branches | ✓ |
| main + pattern branches | Add `release/**` etc. | |

**User's choice:** Push to `main` only.

| Option | Description | Selected |
|--------|-------------|----------|
| Let both run | Push-to-main = post-merge verification, PR = pre-merge | ✓ |
| Suppress push if PR triggered | Skip push self-test on PR merge commits | |

**User's choice:** Let both run.

| Option | Description | Selected |
|--------|-------------|----------|
| Same path filter | Filter push like PR: `actions/**, .github/workflows/**` | ✓ |
| No filter on push | Always run push-to-main self-test | |

**User's choice:** Same path filter on push.

| Option | Description | Selected |
|--------|-------------|----------|
| Region selector input | `workflow_dispatch` with region choice (es/us/fr/all) | ✓ |
| No inputs | Simple dispatch, always all regions | |

**User's choice:** Region selector input, default `all`.

---

## Drift Issue Behavior

| Option | Description | Selected |
|--------|-------------|----------|
| One issue for all failures | Single issue per schedule run listing all failed regions | ✓ |
| One issue per region | Separate issue per failed region | |

**User's choice:** One issue per schedule run.

| Option | Description | Selected |
|--------|-------------|----------|
| Upsert — update existing | Check for open drift issue, add comment, create if none | ✓ |
| Always create new | New issue every failure | |

**User's choice:** Upsert — find existing or create.

| Option | Description | Selected |
|--------|-------------|----------|
| Auto-close with comment | Close when next run passes, comment with date | ✓ |
| Leave open | Maintainer closes manually | |

**User's choice:** Auto-close on pass.

| Option | Description | Selected |
|--------|-------------|----------|
| Run URL + region list | Minimal issue body: failed regions + run link | ✓ |
| Full diagnostics dump | Output excerpts, error messages | |

**User's choice:** Minimal — run URL + failed region list.

| Option | Description | Selected |
|--------|-------------|----------|
| gh CLI | Pure Bash, GITHUB_TOKEN auth native | ✓ |
| actions/github-script | JS dependency, more expressive | |

**User's choice:** `gh` CLI.

---

## Post-Connect Defense-in-Depth

| Option | Description | Selected |
|--------|-------------|----------|
| Add workflow-level geo check | `curl -s ipinfo.io/country` after action step | ✓ |
| Trust action verification | Action's dual-provider check is sufficient | |

**User's choice:** Add workflow-level geo check.

| Option | Description | Selected |
|--------|-------------|----------|
| One provider | ipinfo.io only — plumbing test, not re-validation | ✓ |
| Two providers | Mirror action's dual-provider approach | |

**User's choice:** One provider.

| Option | Description | Selected |
|--------|-------------|----------|
| Assert all 6 outputs | Check all 6 are non-empty, country matches | ✓ |
| Skip output validation | Action verify step already emits outputs | |

**User's choice:** Assert all 6 outputs — test full consumer contract.

---

## the agent's Discretion

- Workflow YAML structure (job ordering, `needs:`, step grouping)
- Fork-skip guard gate job implementation
- Concurrency group exact syntax
- Secret propagation from environment to action inputs
- `gh` CLI commands for drift issue CRUD
- Matrix region configuration
- Post-connect verification step details
- Permissions scoping

## Deferred Ideas

None — discussion stayed within Phase 4 scope.
