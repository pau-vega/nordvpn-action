---
status: testing
phase: 01-scaffolding-lint
source: [01-01-foundation-docs-SUMMARY.md, 01-02-github-config-SUMMARY.md, 01-03-lint-workflow-SUMMARY.md, 01-04-branch-protection-SUMMARY.md]
started: 2026-05-07T08:18:56Z
updated: 2026-05-07T08:31:00Z
---

## Current Test

number: 13
name: Branch Protection Script Exists
expected: |
  scripts/setup-branch-protection.sh exists at repo root, is executable (-rwxr-xr-x), has set -euo pipefail, no set -x
awaiting: user response

## Tests

### 1. MIT LICENSE File
expected: LICENSE file exists at repo root with MIT License text, copyright (c) 2026 Pau Velasco, SPDX-recognized form for GitHub auto-detection
result: pass

### 2. README Action Index Table
expected: README.md has action index table with 3 placeholder rows (ES, US, FR) showing "Ships in v1.0.0 (Phase2/3)" status
result: pass

### 3. README Pin Forms Guide
expected: README.md contains three pin forms (SHA + comment, floating tag, @main) with when-to-use guidance and @main warning section
result: pass

### 4. AGENTS.md 11 Canonical Sections
expected: AGENTS.md has all 11 canonical H2 sections (Project Overview, Development Environment, Build and Test Commands, Code Style, Testing Instructions, Release Process, Security Considerations, PR Guidelines, For AI Agents, Installation, Alternatives Considered)
result: pass

### 5. AGENTS.md SCAF-06 Topics
expected: AGENTS.md covers all 5 SCAF-06 mandatory topics (Conventional-Commit scopes, fork-safety/pull_request_target ban, composite post: + disconnect/ + if: always(), Ubuntu-only runner, service-credentials-only auth)
result: pass

### 6. CODEOWNERS Glob Rule
expected: .github/CODEOWNERS exists with single rule `/actions/** @pau-vega` covering all current and future region subdirectories
result: pass

### 7. Dependabot Plural Directories
expected: .github/dependabot.yml uses plural `directories:` key with 7 pre-enumerated paths (root + 3 regions + 3 disconnects), commit-message prefix "deps"
result: pass

### 8. Actions-Lint Workflow Exists
expected: .github/workflows/actions-lint.yml exists with three parallel jobs (actionlint, shellcheck, block-pull-request-target)
result: pass

### 9. SHA-Pinned Actions
expected: All external actions in actions-lint.yml are pinned by 40-char SHA + `# vX.Y.Z` comment (actions/checkout, reviewdog/action-actionlint, ludeeus/action-shellcheck)
result: pass

### 10. LINT-05 pull_request_target Ban
expected: block-pull-request-target job uses two regex patterns to detect pull_request_target in .github/workflows/** files, emits ::error:: annotations with AGENTS.md and PITFALLS.md citations, exits 1 on detection
result: pass

### 11. Workflow Permissions and Concurrency
expected: actions-lint.yml has workflow-level `permissions: contents: read` and concurrency group with cancel-in-progress: true
result: pass

### 12. Actionlint Passes on Workflow
expected: Running `actionlint .github/workflows/actions-lint.yml` locally exits 0 with no errors
result: pass

### 13. Branch Protection Script Exists
expected: scripts/setup-branch-protection.sh exists at repo root, is executable (-rwxr-xr-x), has set -euo pipefail, no set -x
result: [pending]

### 14. Script Constants Correct
expected: setup-branch-protection.sh has OWNER="pau-vega", REPO="nordvpn-actions", 3 required checks (actionlint, shellcheck, block-pull-request-target)
result: [pending]

### 15. Script Pre-flight Checks
expected: setup-branch-protection.sh checks for gh CLI presence, gh auth status, and repo existence before attempting API call
result: [pending]

### 16. Script Uses PUT (Idempotent)
expected: setup-branch-protection.sh uses `gh api --method PUT` (full replace, idempotent), enforce_admins: true, required_approving_review_count: 0, restrictions: null
result: [pending]

### 17. Shellcheck Clean on Scripts
expected: Running `shellcheck scripts/setup-branch-protection.sh` locally exits 0 with no errors
result: [pending]

### 18. Cold Start Smoke Test
expected: Kill any running server/service. Clear ephemeral state (temp DBs, caches, lock files). Start the application from scratch. Server boots without errors, any seed/migration completes, and a primary query (health check, homepage load, or basic API call) returns live data.
result: [pending]

## Summary

total: 18
passed: 12
issues: 0
pending: 6
skipped: 0
blocked: 0

## Gaps

[none yet]
