---
phase: 01-scaffolding-lint
plan: 04
type: execute
wave: 2
depends_on:
  - 01
  - 02
  - 03
files_modified:
  - scripts/setup-branch-protection.sh
autonomous: false
requirements:
  - SCAF-07
must_haves:
  truths:
    - "After this plan runs, branch protection on `main` requires the three actions-lint job names (actionlint, shellcheck, block-pull-request-target) to pass before merge — satisfies success criterion 2 (no merges without lint) + SCAF-07."
    - "After this plan runs, the public GitHub repo `pau-vega/nordvpn-actions` exists with the full Phase 1 scaffold pushed (LICENSE, README.md, AGENTS.md, .github/CODEOWNERS, .github/dependabot.yml, .github/workflows/actions-lint.yml, scripts/setup-branch-protection.sh) — satisfies success criterion 4 + D-02."
    - "Admins do NOT bypass branch protection (`enforce_admins: true` per D-16) — the maintainer goes through the same PR gate from Phase 2 onward."
    - "The local working directory is renamed from `nordvpn-action` (singular) to `nordvpn-actions` (plural) so the local path matches the remote repo name."
  artifacts:
    - path: "scripts/setup-branch-protection.sh"
      provides: "Idempotent gh-CLI script that enables branch protection on main with the three actions-lint required checks (D-13 + D-14)"
      contains: "gh api"
    - path: "github.com/pau-vega/nordvpn-actions"
      provides: "Public MIT-licensed GitHub repo seeded with the Phase 1 scaffold"
      contains: "remote-side artifact, not file"
  key_links:
    - from: "scripts/setup-branch-protection.sh"
      to: "GitHub Branch Protection REST API"
      via: "gh api repos/{owner}/{repo}/branches/main/protection"
      pattern: "branches/main/protection"
    - from: "scripts/setup-branch-protection.sh required_status_checks"
      to: ".github/workflows/actions-lint.yml job names (actionlint, shellcheck, block-pull-request-target)"
      via: "JSON contexts array"
      pattern: "actionlint.*shellcheck.*block-pull-request-target"
---

<objective>
Phase-end choreography for Phase 1: ship the committed `scripts/setup-branch-protection.sh` (idempotent `gh api` invocation that enables main-branch protection requiring the three `actions-lint` job names per D-13/D-14/D-15/D-16), rename the local working directory from `nordvpn-action` (singular) to `nordvpn-actions` (plural) per D-01, create the public GitHub repository `pau-vega/nordvpn-actions` per D-02, push the committed Phase 1 scaffold so the first remote SHA contains everything Plans 01-03 produced, then run the script once against the now-existing remote to enable branch protection.

Purpose: This is the only plan in Phase 1 that crosses the local-to-remote boundary. After this plan completes, the public repo exists, branch protection is on, and Phase 2 onward goes through PRs gated by `actions-lint`. The script is committed so it is re-runnable if the repo is recreated, settings drift, or Phase 4 amends it (TEST-09) to add the self-test matrix jobs.

Output:
- Local artifact: `scripts/setup-branch-protection.sh` (committed alongside the rest of the Phase 1 scaffold).
- Remote artifact: `github.com/pau-vega/nordvpn-actions` exists, public, MIT, with the Phase 1 commits pushed and branch protection enabled.

Covers requirements: SCAF-07.

Internal sequencing (D-18, enforced by task ordering):
1. Task 1 — write `scripts/setup-branch-protection.sh` and commit it together with Plans 01-03's artifacts (one final commit before any remote work).
2. Checkpoint A — verify all Phase 1 local artifacts present and committed.
3. Task 2 (`checkpoint:human-action`) — rename the local directory, run `gh repo create`, push.
4. Task 3 (`checkpoint:human-verify`) — run the branch-protection script and confirm the three required checks are wired.

This plan is `autonomous: false` because Tasks 2 and 3 require human action (terminal restart after rename, GitHub-side authentication for `gh repo create`, `gh api` writes that mutate the public repo).
</objective>

<execution_context>
@$HOME/.claude/get-shit-done/workflows/execute-plan.md
@$HOME/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@CLAUDE.md
@.planning/PROJECT.md
@.planning/REQUIREMENTS.md
@.planning/phases/01-scaffolding-lint/01-CONTEXT.md
@.planning/phases/01-scaffolding-lint/01-01-foundation-docs-PLAN.md
@.planning/phases/01-scaffolding-lint/01-02-github-config-PLAN.md
@.planning/phases/01-scaffolding-lint/01-03-lint-workflow-PLAN.md
@.planning/research/STACK.md
@.planning/research/PITFALLS.md

<key_facts>
<!-- Source-of-truth byte-exact values. Use these verbatim. -->

Required check names (from Plan 03's job names — MUST match exactly or branch protection silently never fires):
  - actionlint
  - shellcheck
  - block-pull-request-target

Branch protection settings (from D-13 through D-16, GitHub Branch Protection REST API shape — see https://docs.github.com/en/rest/branches/branch-protection):

  Endpoint: PUT /repos/{owner}/{repo}/branches/{branch}/protection
  Branch: main

  Settings ENABLED (D-15 + D-16):
    required_status_checks:
      strict: true                # "Require branches to be up to date before merging"
      contexts: ["actionlint", "shellcheck", "block-pull-request-target"]   # the three Plan 03 job names
    enforce_admins: true          # D-16: admins do NOT bypass — dogfoods OpenSSF Scorecard branch-protection check
    required_pull_request_reviews:
      required_approving_review_count: 0   # D-15: solo repo, 0 required approvals (PR-gate only, no second human)
      dismiss_stale_reviews: false
      require_code_owner_reviews: false
    restrictions: null            # D-15: no restrict-who-can-push (would lock the maintainer out)
    allow_force_pushes: false
    allow_deletions: false
    block_creations: false
    required_conversation_resolution: false
    lock_branch: false
    allow_fork_syncing: true

  Settings NOT ENABLED (D-15 explicit opt-outs):
    required_signed_commits: NOT enabled (extra ceremony, no proportional return)
    required_linear_history: NOT enabled (release-please squash-merges may not always be linear)

GitHub API gotchas:
  - The endpoint is PUT (full replace), not PATCH. The script must send the COMPLETE settings each time. PUT with `--input -` and a HEREDOC of the JSON body is the canonical shape.
  - `required_pull_request_reviews` MUST be an OBJECT (or `null`); `required_status_checks` MUST be an OBJECT.
  - `restrictions` MUST be `null` for "no push restrictions" (an empty object would mean "restrict to the empty allowlist" = locked out).
  - `enforce_admins` is a TOP-LEVEL boolean (not nested).
  - The `gh api` CLI accepts `-X PUT` and `--input <file>` to send a JSON body.

Idempotency requirement (D-13):
  - Running the script twice in a row MUST NOT fail.
  - The `PUT` endpoint is naturally idempotent (full replace).
  - The script MUST NOT depend on the absence of prior protection settings.
  - The script SHOULD detect and handle the "repo not found" case (helpful error pointing to D-02 — `gh repo create` first).

Owner / repo:
  - Owner: pau-vega
  - Repo:  nordvpn-actions

Working directory rename (D-01 + D-18):
  - Current local cwd at planning time: `/Users/pauvelascogarrofe/Documents/nordvpn-action` (singular).
  - Target name: `nordvpn-actions` (plural).
  - The rename is a filesystem-level rename of the PARENT directory itself, not an in-repo file rename. This is OUTSIDE the git tree.
  - Recovery if rename happens mid-task: close the active terminal/Claude Code session, `cd` to the renamed directory `/Users/pauvelascogarrofe/Documents/nordvpn-actions`, re-open Claude Code from there. The git history is unaffected.

`gh repo create` flag interaction (D-02):
  - Command shape: `gh repo create pau-vega/nordvpn-actions --public --source=. --remote=origin --description "Composite GitHub Actions for NordVPN country-egress (ES / US / FR)"`.
  - `--license mit` would create an additional LICENSE on the GitHub side. Since Plan 01 already committed `LICENSE` locally, `--license mit` would either collide with the local LICENSE or get overridden by the local LICENSE on `git push`. **Decision:** OMIT `--license mit` from `gh repo create` — the local LICENSE wins; GitHub auto-detects MIT once pushed.
  - `--source=.` tells `gh` the local repo is the source; it adds `origin` as a remote.
  - Do NOT use `--push` — push happens as a separate step so we can verify the local state first.

Push sequence (D-18):
  - After `gh repo create --source=. --remote=origin`, the remote `origin` exists but is empty.
  - `git push -u origin main` seeds the remote with all local commits in one go.
  - Phase 1 commits (one per plan, ~4 commits per D-03) all land on `origin/main` simultaneously.

Phase 1 commits expected at this point (from Plans 01-03 + this plan's Task 1):
  Commit 1 (Plan 01): `docs(scaf): add LICENSE, root README, AGENTS.md` — files: LICENSE, README.md, AGENTS.md.
  Commit 2 (Plan 02): `chore(scaf): add CODEOWNERS and dependabot config` — files: .github/CODEOWNERS, .github/dependabot.yml.
  Commit 3 (Plan 03): `feat(lint): add actions-lint workflow with pull_request_target guard` — files: .github/workflows/actions-lint.yml.
  Commit 4 (this plan, Task 1): `chore(scaf): add branch-protection setup script` — files: scripts/setup-branch-protection.sh.

  (Conventional Commits scopes from CONTEXT.md "Established Patterns": `scaf` / `lint` / `chore` / `docs` — no per-region scope yet.)

  Commit messages above are illustrative; the executor of each plan owns the commit text. The expected COUNT is 4 commits before any push.

Pre-push checklist (Checkpoint A):
  - `git status` shows clean working tree.
  - `git log --oneline` shows 4 commits.
  - `git remote -v` shows NO `origin` (because `gh repo create` hasn't run yet).
  - All artifacts present: `LICENSE`, `README.md`, `AGENTS.md`, `.github/CODEOWNERS`, `.github/dependabot.yml`, `.github/workflows/actions-lint.yml`, `scripts/setup-branch-protection.sh`.
  - Local repo is at `/Users/pauvelascogarrofe/Documents/nordvpn-action` (still singular until Task 2 renames it).
</key_facts>

<interfaces>
<!-- This plan creates one shell script and three GitHub-side mutations (repo create, push, branch-protection PUT). -->
<!-- Downstream consumers: -->
<!--   - Phase 4 amends `scripts/setup-branch-protection.sh` to add the three `self-test` matrix jobs (TEST-09). The script's structure must support easy amendment of the `contexts:` JSON array. -->
<!--   - All future PRs go through the branch protection enabled here. -->
</interfaces>
</context>

<tasks>

<task type="auto">
  <name>Task 1: Write scripts/setup-branch-protection.sh (idempotent gh-API script enabling main protection with three required checks)</name>
  <files>scripts/setup-branch-protection.sh</files>
  <read_first>
    - .planning/REQUIREMENTS.md (SCAF-07 acceptance criterion: branch protection requires actions-lint workflow checks)
    - .planning/phases/01-scaffolding-lint/01-CONTEXT.md (D-13: committed gh api script, idempotent; D-14: three job names, job-level not workflow-level; D-15: solo-repo settings; D-16: enforce_admins true)
    - .planning/phases/01-scaffolding-lint/01-03-lint-workflow-PLAN.md (the three job names: actionlint, shellcheck, block-pull-request-target)
    - .planning/research/STACK.md (`gh api` shape, GitHub Branch Protection REST API)
    - CLAUDE.md (Conventional Commits scopes for Phase 1)
  </read_first>
  <action>
    Create `scripts/setup-branch-protection.sh`. Create the `scripts/` directory if it does not yet exist (`mkdir -p scripts`). The file must be EXECUTABLE (`chmod +x`) so it can be run directly without `bash` prefix.

    Required content (exact bash, copy with substitutions noted):

    ```bash
    #!/usr/bin/env bash
    # scripts/setup-branch-protection.sh
    #
    # Idempotently enables branch protection on `main` for pau-vega/nordvpn-actions.
    # Required checks: actionlint, shellcheck, block-pull-request-target
    # (the three job names from .github/workflows/actions-lint.yml).
    #
    # Usage:
    #   gh auth login                      # one-time, if not already authenticated
    #   scripts/setup-branch-protection.sh
    #
    # Re-run after:
    #   - First creation of the remote repo (initial enable).
    #   - Renaming or adding required-check job names (Phase 4 amends to add `self-test` matrix jobs — TEST-09).
    #   - Drift recovery (someone manually disabled protection in the GitHub UI).
    #
    # See .planning/phases/01-scaffolding-lint/01-CONTEXT.md §"Branch Protection on `main`"
    # (decisions D-13..D-16) for the rationale on each setting.

    set -euo pipefail

    OWNER="pau-vega"
    REPO="nordvpn-actions"
    BRANCH="main"

    # The three required check names MUST match the `name:` field of each job in
    # .github/workflows/actions-lint.yml. If those names change, update this list.
    REQUIRED_CHECKS_JSON='[
      {"context": "actionlint",                  "app_id": -1},
      {"context": "shellcheck",                  "app_id": -1},
      {"context": "block-pull-request-target",   "app_id": -1}
    ]'

    # Pre-flight: confirm gh CLI is installed and authenticated.
    if ! command -v gh >/dev/null 2>&1; then
      echo "::error::gh CLI not found. Install with 'brew install gh' (macOS) or see https://cli.github.com/" >&2
      exit 2
    fi
    if ! gh auth status >/dev/null 2>&1; then
      echo "::error::gh CLI not authenticated. Run 'gh auth login' and retry." >&2
      exit 2
    fi

    # Pre-flight: confirm the remote repo exists. If not, instruct user to run
    # `gh repo create` (Plan 04 Task 2 documents this command).
    if ! gh api "repos/${OWNER}/${REPO}" >/dev/null 2>&1; then
      echo "::error::Remote repo ${OWNER}/${REPO} does not exist." >&2
      echo "Run 'gh repo create ${OWNER}/${REPO} --public --source=. --remote=origin' first," >&2
      echo "then 'git push -u origin main', then re-run this script." >&2
      exit 3
    fi

    echo "Enabling branch protection on ${OWNER}/${REPO}@${BRANCH}..."

    # PUT /repos/{owner}/{repo}/branches/{branch}/protection — full replace, naturally idempotent.
    # Settings ENABLED (D-15 + D-16):
    #   - required_status_checks.strict=true (require branch up-to-date before merge)
    #   - required_status_checks.contexts: 3 job names from Plan 03
    #   - enforce_admins=true (D-16: admins do NOT bypass)
    #   - required_pull_request_reviews with 0 required approvals (D-15: solo repo, no second human)
    #
    # Settings NOT enabled (D-15 explicit opt-outs):
    #   - required_signed_commits (extra ceremony, no proportional return)
    #   - required_linear_history (release-please squash-merges may not always be linear)
    #   - restrictions (would lock the maintainer out — set to null)
    gh api \
      --method PUT \
      "repos/${OWNER}/${REPO}/branches/${BRANCH}/protection" \
      --input - <<EOF
    {
      "required_status_checks": {
        "strict": true,
        "checks": ${REQUIRED_CHECKS_JSON}
      },
      "enforce_admins": true,
      "required_pull_request_reviews": {
        "required_approving_review_count": 0,
        "dismiss_stale_reviews": false,
        "require_code_owner_reviews": false
      },
      "restrictions": null,
      "allow_force_pushes": false,
      "allow_deletions": false,
      "block_creations": false,
      "required_conversation_resolution": false,
      "lock_branch": false,
      "allow_fork_syncing": true
    }
    EOF

    echo ""
    echo "Branch protection enabled on ${OWNER}/${REPO}@${BRANCH}."
    echo "Required checks: actionlint, shellcheck, block-pull-request-target"
    echo "Admins enforced: yes (no bypass)"
    echo "PR reviews: required (0 approvals — solo repo)"
    echo ""
    echo "Verify in GitHub UI:"
    echo "  https://github.com/${OWNER}/${REPO}/settings/branches"
    ```

    File must be:
    - shebang `#!/usr/bin/env bash` on line 1.
    - `set -euo pipefail` early in the body.
    - Executable: `chmod +x scripts/setup-branch-protection.sh`.
    - Shellcheck-clean (no SC errors when run with `shellcheck scripts/setup-branch-protection.sh`).
    - File ends with a single trailing newline.

    DO NOT use:
    - `set -x` (PITFALLS.md §6 — leaks). Use `echo` for diagnostic output.
    - Hardcoded `gh` paths (`/usr/local/bin/gh`) — rely on PATH.
    - `curl` directly against the GitHub REST API — use `gh api` (handles auth, rate limits, redirects).
    - `--method POST` — must be `PUT` (full replace).
    - `restrictions: {}` — must be `restrictions: null` (empty object means "restrict to nobody" = locked out).
    - `required_signed_commits: true` — D-15 explicit opt-out.
    - `required_linear_history: true` — D-15 explicit opt-out.
    - `allow_force_pushes: true` — keeping this `false` is the default safe shape; force-push to main is never needed (release-please pushes via PR merge, not direct push).
    - The deprecated `required_status_checks.contexts` flat-string array — modern API uses `checks: [{context, app_id: -1}]` (which we ARE using above; `app_id: -1` means "any GitHub App", which is what the GitHub Actions check runs are).

    NOTE on `app_id: -1`: this is the "any GitHub App" wildcard that matches GitHub Actions check runs (which are reported by the GitHub Actions app). Using `app_id: -1` is the correct shape per the modern GitHub API — see https://docs.github.com/en/rest/branches/branch-protection?apiVersion=2022-11-28#update-branch-protection.

    Phase 4 amendment hint (NOT for execution now — informational only): when Phase 4 ships TEST-09, this script must be amended to add three more entries to `REQUIRED_CHECKS_JSON` for the self-test matrix job names (Phase 4 planner decides exact strings). The script's structure (a JSON array assigned to a single variable) is designed for trivial amendment.
  </action>
  <verify>
    <automated>test -f scripts/setup-branch-protection.sh && test -x scripts/setup-branch-protection.sh && head -n 1 scripts/setup-branch-protection.sh | grep -qE '^#!/usr/bin/env bash$' && grep -qE '^set -euo pipefail$' scripts/setup-branch-protection.sh && grep -qE 'OWNER="pau-vega"' scripts/setup-branch-protection.sh && grep -qE 'REPO="nordvpn-actions"' scripts/setup-branch-protection.sh && grep -qE '"context": "actionlint"' scripts/setup-branch-protection.sh && grep -qE '"context": "shellcheck"' scripts/setup-branch-protection.sh && grep -qE '"context": "block-pull-request-target"' scripts/setup-branch-protection.sh && grep -qE '"enforce_admins": true' scripts/setup-branch-protection.sh && grep -qE 'gh api' scripts/setup-branch-protection.sh && grep -qE -- '--method PUT' scripts/setup-branch-protection.sh && grep -qE 'branches/.*?/protection' scripts/setup-branch-protection.sh && ! grep -qE '^[^#]*set [+-]?[a-z]*x' scripts/setup-branch-protection.sh && ! grep -qE '"required_signed_commits": true' scripts/setup-branch-protection.sh && ! grep -qE '"required_linear_history": true' scripts/setup-branch-protection.sh</automated>
  </verify>
  <acceptance_criteria>
    - File exists: `test -f scripts/setup-branch-protection.sh` exits 0.
    - File is executable: `test -x scripts/setup-branch-protection.sh` exits 0.
    - Shebang on line 1: `head -n 1 scripts/setup-branch-protection.sh | grep -qE '^#!/usr/bin/env bash$'` exits 0.
    - Strict mode: `grep -qE '^set -euo pipefail$' scripts/setup-branch-protection.sh` exits 0.
    - No `set -x` (any form) outside comments: `! grep -qE '^[^#]*set [+-]?[a-z]*x' scripts/setup-branch-protection.sh` exits 0.
    - Owner/repo constants present: `grep -qE 'OWNER="pau-vega"' scripts/setup-branch-protection.sh` exits 0 AND `grep -qE 'REPO="nordvpn-actions"' scripts/setup-branch-protection.sh` exits 0.
    - All three required check names in the JSON body, byte-exact:
      - `grep -qE '"context": "actionlint"' scripts/setup-branch-protection.sh` exits 0.
      - `grep -qE '"context": "shellcheck"' scripts/setup-branch-protection.sh` exits 0.
      - `grep -qE '"context": "block-pull-request-target"' scripts/setup-branch-protection.sh` exits 0.
    - D-16: `grep -qE '"enforce_admins": true' scripts/setup-branch-protection.sh` exits 0 (admins do NOT bypass).
    - D-15 settings:
      - `grep -qE '"required_approving_review_count": 0' scripts/setup-branch-protection.sh` exits 0 (solo repo, 0 reviewers).
      - `grep -qE '"strict": true' scripts/setup-branch-protection.sh` exits 0 (require up-to-date branches).
      - `grep -qE '"restrictions": null' scripts/setup-branch-protection.sh` exits 0 (no push restrictions — `null`, not `{}`).
      - `! grep -qE '"required_signed_commits": true' scripts/setup-branch-protection.sh` exits 0 (explicit opt-out).
      - `! grep -qE '"required_linear_history": true' scripts/setup-branch-protection.sh` exits 0 (explicit opt-out).
    - API shape:
      - `grep -qE 'gh api' scripts/setup-branch-protection.sh` exits 0.
      - `grep -qE -- '--method PUT' scripts/setup-branch-protection.sh` exits 0 (PUT, not PATCH).
      - `grep -qE 'branches/.*?/protection' scripts/setup-branch-protection.sh` exits 0 (correct endpoint).
    - Idempotency check (D-13): the script handles "repo not found" with a helpful error: `grep -qE 'Remote repo .* does not exist' scripts/setup-branch-protection.sh` exits 0.
    - Pre-flight checks: `grep -qE 'gh auth status' scripts/setup-branch-protection.sh` exits 0 (auth pre-flight) AND `grep -qE 'command -v gh' scripts/setup-branch-protection.sh` exits 0 (CLI presence pre-flight).
    - Shellcheck cleanliness: `shellcheck scripts/setup-branch-protection.sh` (if `shellcheck` is in local PATH) exits 0.
  </acceptance_criteria>
  <done>scripts/setup-branch-protection.sh exists, is executable, has the correct shebang and strict mode, and contains the three Plan 03 job names in its required-checks JSON, plus `enforce_admins: true`, plus the D-15 settings (0 reviewers, strict status checks, no force-push, no signed-commits, no linear-history). It is idempotent (PUT replaces fully) and handles the "repo not yet created" case with a helpful error.</done>
</task>

<task type="checkpoint:human-action" gate="blocking">
  <name>Checkpoint A: Verify Phase 1 local artifacts before remote work</name>
  <files>(no file modifications — verification only)</files>
  <read_first>
    - All Plan 01-03 PLAN.md files in .planning/phases/01-scaffolding-lint/
    - .planning/phases/01-scaffolding-lint/01-CONTEXT.md (D-03 commit shape)
  </read_first>
  <what-built>
    All four Phase 1 plans have committed their artifacts locally. The full Phase 1 scaffold is on the local `main` branch with no remote yet.
  </what-built>
  <action>
    Before proceeding to Task 2 (rename + remote create), verify that the local repository state is exactly correct. This checkpoint is a STOP gate; if any check fails, fix the issue locally before continuing.

    Run all five checks below (in order) and report each output to the user. Do NOT proceed to Task 2 until all five checks pass and the user has approved.

    1. **All artifacts present:**
       ```bash
       ls -la LICENSE README.md AGENTS.md .github/CODEOWNERS .github/dependabot.yml .github/workflows/actions-lint.yml scripts/setup-branch-protection.sh
       ```
       Expected: all 7 files exist; `scripts/setup-branch-protection.sh` is `-rwxr-xr-x` (executable).

    2. **Working tree clean:**
       ```bash
       git status --porcelain
       ```
       Expected: empty output.

    3. **Commit count and shape:**
       ```bash
       git log --oneline | head -n 10
       ```
       Expected: at least 4 NEW commits since planning (one per plan), each with a Conventional-Commit prefix from `scaf` / `lint` / `chore` / `docs`.

    4. **No remote yet:**
       ```bash
       git remote -v
       ```
       Expected: empty output (`gh repo create` hasn't run yet, per D-18 sequence).

    5. **Local working dir name (still singular):**
       ```bash
       basename "$(pwd)"
       ```
       Expected: `nordvpn-action` (singular). The rename happens in Task 2, not yet.
  </action>
  <how-to-verify>
    Run each of the five commands listed in the action block. If any check fails, STOP and resolve before continuing to Task 2.

    Report status to user with the output of all five checks. User responds "approved" or describes the issue.
  </how-to-verify>
  <verify>
    <automated>test -f LICENSE && test -f README.md && test -f AGENTS.md && test -f .github/CODEOWNERS && test -f .github/dependabot.yml && test -f .github/workflows/actions-lint.yml && test -f scripts/setup-branch-protection.sh && test -x scripts/setup-branch-protection.sh && [ -z "$(git status --porcelain)" ] && [ -z "$(git remote -v)" ] && [ "$(basename "$(pwd)")" = "nordvpn-action" ]</automated>
  </verify>
  <acceptance_criteria>
    - All 7 artifact files exist (LICENSE, README.md, AGENTS.md, .github/CODEOWNERS, .github/dependabot.yml, .github/workflows/actions-lint.yml, scripts/setup-branch-protection.sh).
    - `scripts/setup-branch-protection.sh` is executable.
    - `git status --porcelain` returns empty (clean tree).
    - `git remote -v` returns empty (no remote yet).
    - `basename "$(pwd)"` returns `nordvpn-action` (singular — rename has not happened yet).
    - User has approved progression to Task 2.
  </acceptance_criteria>
  <resume-signal>User responds "approved" / "looks good" / equivalent. If issues: fix them locally, re-run the checks, repeat the checkpoint.</resume-signal>
  <done>All five local-state checks pass; user has explicitly approved progression to the rename + remote-create step.</done>
</task>

<task type="checkpoint:human-action" gate="blocking">
  <name>Task 2: Rename local dir, create public GitHub repo, push the Phase 1 scaffold</name>
  <files>(filesystem rename of parent dir; creates remote repo on GitHub; pushes commits — no in-tree file modifications)</files>
  <read_first>
    - .planning/phases/01-scaffolding-lint/01-CONTEXT.md (D-01 rename, D-02 remote create, D-04 direct-to-main commits during Phase 1)
    - .planning/PROJECT.md (constraint: public, MIT, owner pau-vega, repo nordvpn-actions)
  </read_first>
  <what-built>
    All Phase 1 local artifacts are committed (Checkpoint A passed). The local working directory is still named `nordvpn-action` (singular). No GitHub remote exists.
  </what-built>
  <action>
    Run these steps in this exact order. STOP at any failure and resolve before continuing.

    **Step 1: Rename the local working directory (D-01).**

    The rename is a filesystem rename of the parent directory. After the rename, the active terminal session's working directory will be invalidated. The executor (Claude) should:
    - Confirm Checkpoint A passed.
    - Tell the user: "About to rename the working directory from `nordvpn-action` to `nordvpn-actions`. This may invalidate the current terminal/Claude Code session. After rename, close the terminal, `cd /Users/pauvelascogarrofe/Documents/nordvpn-actions`, and re-open Claude Code from the renamed directory."
    - Run from the parent directory:
      ```bash
      cd /Users/pauvelascogarrofe/Documents
      mv nordvpn-action nordvpn-actions
      ```
    - If the rename fails because the active session has files open from the old path: close the session, perform the rename in a fresh shell, reopen Claude Code in the renamed directory, and resume from Step 2.

    **Step 2: Confirm working directory after rename.**
    ```bash
    cd /Users/pauvelascogarrofe/Documents/nordvpn-actions
    pwd
    git status
    git log --oneline | head -n 5
    ```
    Expected: `pwd` ends in `nordvpn-actions` (plural); git history is intact.

    **Step 3: Create the public GitHub repository (D-02).**
    ```bash
    gh repo create pau-vega/nordvpn-actions \
      --public \
      --source=. \
      --remote=origin \
      --description "Composite GitHub Actions for NordVPN country-egress (ES / US / FR)"
    ```
    DO NOT pass `--license mit` (the local LICENSE wins; `--license mit` would create a GitHub-side LICENSE that would either collide or be overwritten on push — see key_facts).
    DO NOT pass `--push` (push is a separate step).
    Expected: `gh repo create` succeeds, prints the new repo URL `https://github.com/pau-vega/nordvpn-actions`, and adds `origin` as a git remote.

    **Step 4: Verify remote was added.**
    ```bash
    git remote -v
    ```
    Expected: `origin` points to `https://github.com/pau-vega/nordvpn-actions.git` (or SSH equivalent).

    **Step 5: Push the Phase 1 scaffold.**
    ```bash
    git push -u origin main
    ```
    Expected: pushes 4+ commits to `origin/main`. The first remote SHA contains the full Phase 1 scaffold.

    **Step 6: Verify the remote has the scaffold.**
    ```bash
    gh api repos/pau-vega/nordvpn-actions/contents/LICENSE | jq -r '.name'
    gh api repos/pau-vega/nordvpn-actions/contents/.github/workflows/actions-lint.yml | jq -r '.name'
    gh api repos/pau-vega/nordvpn-actions/contents/scripts/setup-branch-protection.sh | jq -r '.name'
    ```
    Expected: each command returns the filename.

    **Step 7: Watch the first `actions-lint` workflow run (informational).**
    ```bash
    gh run list --workflow=actions-lint.yml --limit 1
    gh run view --log
    ```
    Expected: the run completes (likely successfully — no `actions/**/scripts/*.sh` to lint, workflow well-formed, guard finds no offenders). If the run fails, STOP and resolve before Task 3.

    Report status to user with the output of each step.
  </action>
  <how-to-verify>
    All seven steps in the action block succeed. After Step 7, `gh api repos/pau-vega/nordvpn-actions` returns 200 OK and the local `git remote -v` shows `origin`.
  </how-to-verify>
  <verify>
    <automated>git remote -v | grep -qE '^origin\s+https://github\.com/pau-vega/nordvpn-actions(\.git)?\s|^origin\s+git@github\.com:pau-vega/nordvpn-actions(\.git)?\s' && git rev-parse origin/main >/dev/null 2>&1 && [ "$(basename "$(pwd)")" = "nordvpn-actions" ]</automated>
  </verify>
  <acceptance_criteria>
    - Local working directory renamed: `basename "$(pwd)"` returns `nordvpn-actions` (plural).
    - `git remote -v` shows `origin` pointing to `pau-vega/nordvpn-actions`.
    - `git rev-parse origin/main` returns the SHA of the pushed Phase 1 scaffold (exits 0).
    - `gh api repos/pau-vega/nordvpn-actions` returns 200 OK.
    - `gh api repos/pau-vega/nordvpn-actions/contents/LICENSE`, `...contents/.github/workflows/actions-lint.yml`, `...contents/scripts/setup-branch-protection.sh` all return 200 OK.
    - The first `actions-lint` workflow run on `main` has completed (gh run list shows status `completed`).
    - User has approved progression to Task 3.
  </acceptance_criteria>
  <resume-signal>User responds "approved" / "looks good" / equivalent after confirming all 7 steps succeeded. If `gh auth login` is needed mid-task, the executor pauses, the user authenticates, and the executor resumes from the failing step.</resume-signal>
  <done>Local directory renamed, public remote `pau-vega/nordvpn-actions` exists with the Phase 1 scaffold pushed to `origin/main`, and the first `actions-lint` workflow run on `main` has completed (success expected — empty `actions/` directory means shellcheck no-ops, actionlint validates the workflow itself, guard finds no offenders).</done>
</task>

<task type="checkpoint:human-verify" gate="blocking">
  <name>Task 3: Run setup-branch-protection.sh and verify branch protection is enabled with the three required checks</name>
  <files>(no file modifications — mutates remote pau-vega/nordvpn-actions branch protection settings)</files>
  <read_first>
    - scripts/setup-branch-protection.sh (the script being run)
    - .planning/phases/01-scaffolding-lint/01-CONTEXT.md (D-13..D-16 — settings expectations)
  </read_first>
  <what-built>
    Task 2 succeeded: the public GitHub repo `pau-vega/nordvpn-actions` exists with the Phase 1 scaffold pushed. Branch protection is NOT yet enabled.
  </what-built>
  <action>
    **Step 1: Run the branch-protection script.**

    From the renamed working directory (`/Users/pauvelascogarrofe/Documents/nordvpn-actions`):
    ```bash
    scripts/setup-branch-protection.sh
    ```

    Expected output (line-for-line):
    ```
    Enabling branch protection on pau-vega/nordvpn-actions@main...

    Branch protection enabled on pau-vega/nordvpn-actions@main.
    Required checks: actionlint, shellcheck, block-pull-request-target
    Admins enforced: yes (no bypass)
    PR reviews: required (0 approvals — solo repo)

    Verify in GitHub UI:
      https://github.com/pau-vega/nordvpn-actions/settings/branches
    ```
    Exit code MUST be 0.

    **Step 2: Verify the protection settings via the API.**
    ```bash
    gh api repos/pau-vega/nordvpn-actions/branches/main/protection \
      | jq '{
          required_status_checks: .required_status_checks.checks | map(.context),
          strict: .required_status_checks.strict,
          enforce_admins: .enforce_admins.enabled,
          required_approving_review_count: .required_pull_request_reviews.required_approving_review_count,
          allow_force_pushes: .allow_force_pushes.enabled,
          allow_deletions: .allow_deletions.enabled
        }'
    ```
    Expected JSON output:
    ```json
    {
      "required_status_checks": [
        "actionlint",
        "shellcheck",
        "block-pull-request-target"
      ],
      "strict": true,
      "enforce_admins": true,
      "required_approving_review_count": 0,
      "allow_force_pushes": false,
      "allow_deletions": false
    }
    ```
    Order of `required_status_checks` may vary — what matters is the array contains EXACTLY those three strings.

    **Step 3: Idempotency test (D-13).**
    ```bash
    scripts/setup-branch-protection.sh
    ```
    Expected: exit code 0, no error, settings unchanged.

    **Step 4: Visual verification in the GitHub UI.**

    Visit https://github.com/pau-vega/nordvpn-actions/settings/branches in a browser. Confirm visually:
    - A rule for `main` is listed.
    - "Require a pull request before merging" enabled with 0 required approvals.
    - "Require status checks to pass before merging" enabled.
    - "Require branches to be up to date before merging" checked.
    - The three status checks `actionlint`, `shellcheck`, `block-pull-request-target` are listed as required.
    - "Do not allow bypassing the above settings" (i.e., `enforce_admins`) is checked.
    - "Allow force pushes" is unchecked.
    - "Allow deletions" is unchecked.

    **Step 5 (informational, not blocking): Confirm Phase 1 success criterion 2 by attempting to merge a deliberately-broken PR.**

    Optional — Phase 2's first PR will exercise this naturally:
    - Create a branch, add a workflow file with `pull_request_target:`, push, open a PR.
    - The `block-pull-request-target` check fails.
    - Branch protection prevents the merge.
    - Close the PR without merging.
  </action>
  <how-to-verify>
    Run all four required steps (1-4) and report each output to the user. The user visually confirms Step 4 in the GitHub UI and reports back.
  </how-to-verify>
  <verify>
    <automated>gh api repos/pau-vega/nordvpn-actions/branches/main/protection >/dev/null 2>&1 && [ "$(gh api repos/pau-vega/nordvpn-actions/branches/main/protection | jq -r '.enforce_admins.enabled')" = "true" ] && [ "$(gh api repos/pau-vega/nordvpn-actions/branches/main/protection | jq -r '.required_pull_request_reviews.required_approving_review_count')" = "0" ] && [ "$(gh api repos/pau-vega/nordvpn-actions/branches/main/protection | jq -r '.required_status_checks.checks | map(.context) | sort | join(",")')" = "actionlint,block-pull-request-target,shellcheck" ]</automated>
  </verify>
  <acceptance_criteria>
    - `scripts/setup-branch-protection.sh` exit code 0 on first run.
    - `gh api repos/pau-vega/nordvpn-actions/branches/main/protection` returns 200 OK.
    - The three required check contexts are present (sorted: `actionlint`, `block-pull-request-target`, `shellcheck`).
    - `.enforce_admins.enabled` is `true`.
    - `.required_pull_request_reviews.required_approving_review_count` is `0`.
    - `.required_status_checks.strict` is `true`.
    - `.allow_force_pushes.enabled` is `false`.
    - `.allow_deletions.enabled` is `false`.
    - Second run of `scripts/setup-branch-protection.sh` returns exit 0 (idempotency confirmed).
    - User has visually confirmed the settings in the GitHub UI.
  </acceptance_criteria>
  <resume-signal>User confirms via "approved" / "looks good" after seeing the script output, the API JSON output (or screenshot of the GitHub Branches settings page), and the idempotent second run.</resume-signal>
  <done>Branch protection on `main` is enabled with the three Plan 03 job names as required checks, `enforce_admins: true`, 0 required reviews, strict status checks, no force-push, no deletions; the script is idempotent; user has visually confirmed in the GitHub UI.</done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| Local environment ↔ GitHub API | `gh repo create`, `git push`, and `gh api ...protection` all mutate the public GitHub repo. The maintainer's `gh` auth token is the trust root. |
| Branch protection ↔ future PRs | After this plan completes, every push to `main` MUST go through a PR gated by the three `actions-lint` checks. Direct push to `main` is blocked except for the maintainer's first push (which seeded the repo before protection was enabled — see footnote). |
| `scripts/setup-branch-protection.sh` ↔ filesystem | The script is committed to the repo and runs locally. A malicious modification of this script in a future PR could weaken or disable branch protection. |

## STRIDE Threat Register

| Threat ID | Category | Component | Disposition | Mitigation Plan |
|-----------|----------|-----------|-------------|-----------------|
| T-01-04-01 | E (Elevation of privilege) — branch-protection bypass | `enforce_admins` flag on the GitHub API call | mitigate | The script sets `"enforce_admins": true` (D-16), which means even repo admins (the maintainer) cannot bypass the required checks. This dogfoods the contract and makes OpenSSF Scorecard `branch-protection` check pass. **Verification:** `gh api repos/pau-vega/nordvpn-actions/branches/main/protection | jq '.enforce_admins.enabled'` returns `true`. |
| T-01-04-02 | T (Tampering) — malicious modification of `setup-branch-protection.sh` in a future PR | `scripts/setup-branch-protection.sh` | mitigate | A future PR that weakens the script (e.g., removes `enforce_admins`, drops a required check, swaps the repo name) would be visible in the diff. Plan 03's actions-lint paths filter is `actions/**` + `.github/workflows/**`, NOT `scripts/**`. **Residual risk:** PRs that ONLY touch `scripts/**` do not trigger `actions-lint`. CODEOWNERS does not yet cover `/scripts/**` either (Plan 02's CODEOWNERS only covers `/actions/**`). **Action item for Phase 2 or later (NOT this phase):** add `/scripts/** @pau-vega` to CODEOWNERS, OR add `scripts/**` to Plan 03's actions-lint paths filter, so future modifications get auto-reviewed. **Accepted residual risk for Phase 1:** the maintainer is the only person who can merge anyway, and any merge requires a PR per branch protection. The script's content is small; manual review at PR time is acceptable. |
| T-01-04-03 | I (Information disclosure) — gh auth token leak via shell trace | `gh api ...` invocation in the script | mitigate | The script uses `set -euo pipefail`, NOT `set -euxo pipefail`. No `set -x`. The `gh` CLI handles auth token storage (in the OS keychain on macOS, in `~/.config/gh/hosts.yml` elsewhere); the script never echoes or transmits the token. Verification: `! grep -qE '^[^#]*set [+-]?[a-z]*x' scripts/setup-branch-protection.sh` exits 0. |
| T-01-04-04 | S (Spoofing) — pretend the repo exists when it doesn't | `gh api repos/pau-vega/nordvpn-actions` pre-flight | accept | The script's pre-flight checks `gh api repos/${OWNER}/${REPO}` and emits a helpful error if the repo doesn't exist. A malicious user could spoof this check by creating their own `pau-vega/nordvpn-actions` (impossible — owner is bound), or by editing the script (covered by T-01-04-02). Accepted: the script is a maintainer tool, not a security boundary. |
| T-01-04-05 | D (Denial of service) — branch protection disabled by drift | GitHub UI manual edit | accept | If a maintainer (the only user with admin access) disables protection in the UI, re-running `scripts/setup-branch-protection.sh` re-enables it. The script is committed and idempotent. **Recovery:** `scripts/setup-branch-protection.sh` after any drift event. |
| T-01-04-06 | E (Elevation of privilege) — first push bypassed protection | `git push -u origin main` (Task 2 Step 5) | accept | The first push to `main` happens BEFORE branch protection is enabled (Task 3 runs after Task 2). This is unavoidable: branch protection cannot be enabled on a branch that doesn't exist yet, and `main` doesn't exist remotely until the first push. **Acceptance rationale:** the first push contains exactly the audited Phase 1 scaffold (Plans 01-04 outputs); it is reviewed in Checkpoint A before Task 2 runs. From Phase 2 onward, all changes go through PRs. |

**ASVS L1 mapping:**
- V14.5 (Validate file type / extension / structure): `scripts/setup-branch-protection.sh` is a shell script; verified by shellcheck.
- V8.3 (Restrict access to sensitive data): `gh` CLI handles the auth token; the script never reads or echoes it.
- V1.1 (Architecture: SDLC integration of security): branch protection IS the SDLC enforcement mechanism; this plan installs it.
- V1.6 (Architecture: trust boundaries): documented above.
- V1.10 (Architecture: high-impact security controls): branch protection is a high-impact control. The required-checks list is the contract for "what must pass before merge."

**High-severity threats:** T-01-04-01 (admin bypass) and T-01-04-02 (script tampering). T-01-04-01 is mitigated by `enforce_admins: true`. T-01-04-02 has a residual risk (CODEOWNERS doesn't cover `/scripts/**`) flagged as a Phase 2+ action item; for Phase 1 with one maintainer, accepted.
</threat_model>

<verification>
Phase-end gates for this plan (run after all tasks complete):

1. `test -f scripts/setup-branch-protection.sh && test -x scripts/setup-branch-protection.sh` exits 0 — local script artifact present and executable.
2. `gh api repos/pau-vega/nordvpn-actions` exits 0 — remote repo exists.
3. `gh api repos/pau-vega/nordvpn-actions/branches/main/protection` exits 0 — branch protection is enabled.
4. The three required check contexts present in the protection settings:
   ```bash
   gh api repos/pau-vega/nordvpn-actions/branches/main/protection \
     | jq -r '.required_status_checks.checks[] | .context' \
     | sort | tr '\n' ',' \
     | grep -qE 'actionlint,block-pull-request-target,shellcheck,'
   ```
5. `gh api repos/pau-vega/nordvpn-actions/branches/main/protection | jq -r '.enforce_admins.enabled'` returns `true`.
6. `gh api repos/pau-vega/nordvpn-actions/branches/main/protection | jq -r '.required_pull_request_reviews.required_approving_review_count'` returns `0`.
7. The local working directory has been renamed: `basename "$(pwd)"` returns `nordvpn-actions` (plural).
</verification>

<success_criteria>
- `scripts/setup-branch-protection.sh` exists locally, executable, idempotent.
- The public GitHub repo `pau-vega/nordvpn-actions` exists, MIT-detected, with the full Phase 1 scaffold pushed.
- Branch protection on `main` requires the three job names from Plan 03's `actions-lint.yml`: `actionlint`, `shellcheck`, `block-pull-request-target`.
- `enforce_admins: true` (D-16) — admins cannot bypass.
- 0 required PR reviews (D-15) — solo repo.
- Strict status checks (require up-to-date branches before merge).
- No force-push, no deletions, no signed-commits required, no linear-history required (D-15 explicit opt-outs).
- Local working directory renamed `nordvpn-action` → `nordvpn-actions` (D-01).
- All acceptance criteria for Tasks 1, 2, 3 (and Checkpoint A) pass.
</success_criteria>

<output>
After completion, create `.planning/phases/01-scaffolding-lint/01-04-branch-protection-SUMMARY.md` documenting:
- File created: `scripts/setup-branch-protection.sh` with byte size and exec bit confirmation.
- Remote repo URL: `https://github.com/pau-vega/nordvpn-actions`.
- Push hash (the first remote SHA): output of `git rev-parse origin/main`.
- Branch protection settings (excerpt of the API response):
  - `required_status_checks.checks[].context`: `actionlint`, `shellcheck`, `block-pull-request-target`.
  - `enforce_admins.enabled`: `true`.
  - `required_pull_request_reviews.required_approving_review_count`: `0`.
  - `allow_force_pushes.enabled`: `false`.
- Confirmation: working directory renamed `nordvpn-action` → `nordvpn-actions` (per D-01).
- Confirmation: idempotency verified by running the script twice with no error.
- Note for Phase 4: TEST-09 amends this script to add the `self-test` matrix job names (3 more entries in `REQUIRED_CHECKS_JSON`); the script's structure is designed for easy amendment of that JSON array.
- Note for Phase 2: consider extending CODEOWNERS to cover `/scripts/** @pau-vega` so future modifications of this script auto-request review (currently only covered by branch protection's PR-required gate, not by reviewer-required gate).
</output>
