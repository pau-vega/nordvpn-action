# Phase 1: Scaffolding & Lint - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-04-26
**Phase:** 01-scaffolding-lint
**Areas discussed:** Repo bootstrap timing, README v1 + AGENTS.md scope, pull_request_target grep guard mechanics, Branch protection enablement

---

## Repo Bootstrap Timing

### Q1: Local directory name strategy?

| Option | Description | Selected |
|--------|-------------|----------|
| Defer rename (Recommended) | Keep local dir 'nordvpn-action' (singular). GitHub remote will be 'nordvpn-actions' (plural). | |
| Rename now | Rename local dir to 'nordvpn-actions' before first push. | ✓ |

**User's choice:** Rename now
**Notes:** Plan 4 schedules the rename as the LAST step before remote create + push, so it doesn't invalidate the active session mid-execution.

### Q2: When to create the GitHub remote + push?

| Option | Description | Selected |
|--------|-------------|----------|
| End of Phase 1 (Recommended) | Land all Phase 1 artifacts locally, then create GitHub repo and push. | ✓ |
| Early — after first plan | Create remote after LICENSE/README land, push commits as we go. | |
| Now — empty remote first | Create empty GitHub repo before any commits. | |

**User's choice:** End of Phase 1 (Recommended)

### Q3: Initial commit strategy for Phase 1?

| Option | Description | Selected |
|--------|-------------|----------|
| One commit per plan (Recommended) | ~4 commits matching STATE-suggested decomposition. | ✓ |
| Per-artifact granular | Smaller commits — one per file or tight group. | |
| Single 'scaffold v1' commit | Squash everything into one commit at end. | |

**User's choice:** One commit per plan (Recommended)

### Q4: Direct push to main, or first PR to dogfood the lint gate?

| Option | Description | Selected |
|--------|-------------|----------|
| Direct push for Phase 1 (Recommended) | Direct commits to main during Phase 1; gate kicks in for Phase 2+. | ✓ |
| First PR through gate | Open PR for branch-protection commit so the gate runs once before being made required. | |

**User's choice:** Direct push for Phase 1 (Recommended)

---

## README v1 + AGENTS.md Scope

### Q1: Root README v1 content depth?

| Option | Description | Selected |
|--------|-------------|----------|
| Rich chapter from start (Recommended) | Full pin-form section + 'Available actions' table with placeholders. | ✓ |
| Minimal landing now, expand later | Tight intro paragraph + brief pin-form blurb. | |

**User's choice:** Rich chapter from start (Recommended)

### Q2: Badges in root README from start?

| Option | Description | Selected |
|--------|-------------|----------|
| Ship after CI greens (Recommended) | No badges in Phase 1; license badge + 'made for GitHub Actions' OK now. | ✓ |
| Full badge set now | License + actions-lint + Used-by + OpenSSF Scorecard. | |

**User's choice:** Ship after CI greens (Recommended)

### Q3: AGENTS.md content scope for Phase 1?

| Option | Description | Selected |
|--------|-------------|----------|
| Forward-loaded (Recommended) | Cover all CLAUDE.md tech-stack section list now; stub future-phase commands. | ✓ |
| Minimal v1 (5 SCAF-06 topics only) | Just the 5 mandatory topics; other sections deferred. | |

**User's choice:** Forward-loaded (Recommended)

### Q4: AGENTS.md prose style?

| Option | Description | Selected |
|--------|-------------|----------|
| Terse instruction list (Recommended) | Short imperative bullets, code blocks, minimal narrative. | ✓ |
| Narrative with rationale | Each rule has a 'why' paragraph. | |

**User's choice:** Terse instruction list (Recommended)

---

## pull_request_target Grep Guard Mechanics

### Q1: Where does the grep guard live?

| Option | Description | Selected |
|--------|-------------|----------|
| Separate job in actions-lint.yml (Recommended) | Third parallel job alongside actionlint + shellcheck. | ✓ |
| Step inside actionlint job | Bash step at top of actionlint job. | |
| Separate workflow file | Standalone .github/workflows/security-guard.yml. | |

**User's choice:** Separate job in actions-lint.yml (Recommended)

### Q2: Grep pattern strictness?

| Option | Description | Selected |
|--------|-------------|----------|
| YAML-aware regex (Recommended) | Match only when used as workflow trigger; ignore comments/strings. | ✓ |
| Literal substring | Plain `grep -r pull_request_target`. | |

**User's choice:** YAML-aware regex (Recommended)

### Q3: Where does the guard scan?

| Option | Description | Selected |
|--------|-------------|----------|
| `.github/workflows/**` only (Recommended) | Composite action.yml cannot define triggers. | ✓ |
| Workflows + composite action.yml | Defense-in-depth. | |

**User's choice:** `.github/workflows/**` only (Recommended)

### Q4: Guard failure mode?

| Option | Description | Selected |
|--------|-------------|----------|
| Hard fail with pointer to AGENTS.md (Recommended) | Exit 1 with explicit pointer to AGENTS.md + PITFALLS.md §2. | ✓ |
| Warn-only first, hard fail after stabilization | Annotation-only first iteration. | |

**User's choice:** Hard fail with pointer to AGENTS.md (Recommended)

---

## Branch Protection Enablement

### Q1: How to enable branch protection on `main`?

| Option | Description | Selected |
|--------|-------------|----------|
| gh CLI script committed (Recommended) | `scripts/setup-branch-protection.sh` using `gh api`. | ✓ |
| Manual UI + AGENTS.md docs | Configure via GitHub Settings UI. | |
| GitHub Ruleset YAML committed | Newer Repository Rules engine. | |

**User's choice:** gh CLI script committed (Recommended)

### Q2: Required-check job names to enforce?

| Option | Description | Selected |
|--------|-------------|----------|
| Three jobs from actions-lint.yml (Recommended) | Require actionlint, shellcheck, block-pull-request-target. | ✓ |
| Workflow-level only | Single entry for actions-lint workflow. | |

**User's choice:** Three jobs from actions-lint.yml (Recommended)

### Q3: Additional `main` protections beyond required checks?

| Option | Description | Selected |
|--------|-------------|----------|
| Required checks + require PR (Recommended) | Required PR (0 approvals). No required reviewers. No linear history. No signed commits. | ✓ |
| Required checks only | Just status checks; allow direct push. | |
| You decide | Trust the planner / Claude's discretion. | |

**User's choice:** Required checks + require PR (Recommended)

### Q4: Apply protection to admins (you)?

| Option | Description | Selected |
|--------|-------------|----------|
| Admins NOT bypass (Recommended) | `enforce_admins: true`; protection applies to maintainer too. | ✓ |
| Admins can bypass | Allow admin override. | |

**User's choice:** Admins NOT bypass (Recommended)

---

## Claude's Discretion

- Exact regex/awk syntax for the `pull_request_target` grep guard (must satisfy YAML-aware semantics from D-10).
- Branch-protection script location (`scripts/`, `.github/setup/`, etc.).
- Exact wording of README "Available actions" placeholder table.
- Concrete copy in each `AGENTS.md` section.

## Deferred Ideas

- AUTO-01 (Conventional-commits CI grep) → v2.
- OpenSSF Scorecard badge → polish phase before v1.0.0.
- `commitlint` / husky hooks → out of scope (PROJECT.md).
- PR/issue templates → not required by SCAF; revisit if quality drifts.
- AUTO-03 (auto-generated README inputs/outputs) → v2.
