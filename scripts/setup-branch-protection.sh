#!/usr/bin/env bash
# scripts/setup-branch-protection.sh
#
# Idempotently enables branch protection on `main` for pau-vega/nordvpn-action.
# Required checks: actionlint, shellcheck, block-pull-request-target (from actions-lint.yml)
# + self-test matrix jobs (ES, US, FR) from self-test.yml.
#
# Usage:
#   gh auth login                      # one-time, if not already authenticated
#   scripts/setup-branch-protection.sh
#
# Re-run after:
#   - First creation of the remote repo (initial enable).
#   - Renaming or adding required-check job names.
#   - Drift recovery (someone manually disabled protection in the GitHub UI).
#
# See .planning/phases/01-scaffolding-lint/01-CONTEXT.md
# §"Branch Protection on `main`" (decisions D-13..D-16) for the rationale
# on each setting.

set -euo pipefail

OWNER="pau-vega"
REPO="nordvpn-action"
BRANCH="main"

# The required check names MUST match the GitHub-reported check-run names.
# `self-test` is now a matrix job with `region: [ES, US, FR]`, so GitHub
# appends the matrix value in parentheses to the job name:
#   self-test (ES), self-test (US), self-test (FR)
# If those names change (job rename or matrix key change), update this list.
REQUIRED_CHECKS_JSON='[
  {"context": "actionlint",                "app_id": -1},
  {"context": "shellcheck",                "app_id": -1},
  {"context": "block-pull-request-target", "app_id": -1},
  {"context": "self-test (ES)",            "app_id": -1},
  {"context": "self-test (US)",            "app_id": -1},
  {"context": "self-test (FR)",            "app_id": -1}
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
#   - required_status_checks.checks: 3 lint job names + 3 self-test matrix names
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
echo "Required checks: actionlint, shellcheck, block-pull-request-target, self-test (ES), self-test (US), self-test (FR)"
echo "Admins enforced: yes (no bypass)"
echo "PR reviews: required (0 approvals — solo repo)"
echo ""
echo "Verify in GitHub UI:"
echo "  https://github.com/${OWNER}/${REPO}/settings/branches"
