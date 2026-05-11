#!/usr/bin/env bash
# scripts/verify-phase-1.sh
#
# Centralized verification script for Phase 1 (01-scaffolding-lint).
# Checks all automated requirements from Plans 01-04.
#
# Usage:
#   bash scripts/verify-phase-1.sh
#
# Exit code 0 = all checks pass.
# Exit code 1 = one or more checks fail.

set -euo pipefail

PASS=0
FAIL=0
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

# Colors (disabled if no tty)
if [ -t 1 ]; then
  GREEN='\033[0;32m'
  RED='\033[0;31m'
  NC='\033[0m'
else
  GREEN=''
  RED=''
  NC=''
fi

pass() {
  PASS=$((PASS + 1))
  printf "  ${GREEN}PASS${NC}  %s\n" "$1"
}

fail() {
  FAIL=$((FAIL + 1))
  printf "  ${RED}FAIL${NC}  %s\n" "$1"
}

# Track whether any requirement fails for exit code
any_fail=0

check_req() {
  local req="$1"
  local desc="$2"
  shift 2
  if "$@"; then
    pass "${req}: ${desc}"
  else
    fail "${req}: ${desc}"
    any_fail=1
  fi
}

echo ""
echo "=========================================="
echo " Phase 1 (01-scaffolding-lint) Verification"
echo "=========================================="
echo ""

# ──────────────────────────────────────────────
# Plan 01 — Foundation Docs (SCAF-01, SCAF-02, SCAF-03, SCAF-06)
# ──────────────────────────────────────────────

echo "--- Plan 01: Foundation Docs ---"

cd "$REPO_ROOT"

# SCAF-01: LICENSE exists with MIT License text
check_req "SCAF-01" "LICENSE exists" test -f LICENSE
check_req "SCAF-01" "LICENSE line 1 = 'MIT License'" grep -qE '^MIT License$' LICENSE
check_req "SCAF-01" "LICENSE has copyright line" grep -qE '^Copyright \(c\) 2026 Pau Velasco$' LICENSE
check_req "SCAF-01" "LICENSE has warranty disclaimer" grep -qE 'WITHOUT WARRANTY OF ANY KIND' LICENSE

# SCAF-02: README.md has action index section
check_req "SCAF-02" "README has '## Available actions'" grep -qE '^## Available actions$' README.md
check_req "SCAF-02" "README lists nordvpn-es" grep -qE 'nordvpn-es' README.md
check_req "SCAF-02" "README lists nordvpn-us" grep -qE 'nordvpn-us' README.md
check_req "SCAF-02" "README lists nordvpn-fr" grep -qE 'nordvpn-fr' README.md

# SCAF-03: README.md has three-pin-form chapter
check_req "SCAF-03" "README has '## Pin forms'" grep -qE '^## Pin forms$' README.md
check_req "SCAF-03" "Pin form 1: Commit SHA" grep -qE '### 1\. Commit SHA' README.md
check_req "SCAF-03" "Pin form 2: Exact version tag" grep -qE '### 2\. Exact version tag' README.md
check_req "SCAF-03" "Pin form 3: Floating major tag" grep -qE '### 3\. Floating major tag' README.md
check_req "SCAF-03" "README warns against @main" grep -qE '@main' README.md

# SCAF-06: AGENTS.md has For AI Agents section + mandatory topics
check_req "SCAF-06" "AGENTS has '## For AI Agents'" grep -qE '^## For AI Agents$' AGENTS.md
check_req "SCAF-06" "AGENTS mentions pull_request_target" grep -qE 'pull_request_target' AGENTS.md
check_req "SCAF-06" "AGENTS cites PITFALLS.md" grep -qE 'PITFALLS\.md' AGENTS.md
check_req "SCAF-06" "AGENTS mentions NORDVPN_SERVICE_USERNAME" grep -qE 'NORDVPN_SERVICE_USERNAME' AGENTS.md
check_req "SCAF-06" "AGENTS mentions NORDVPN_SERVICE_PASSWORD" grep -qE 'NORDVPN_SERVICE_PASSWORD' AGENTS.md
check_req "SCAF-06" "AGENTS mentions service credential" grep -qE 'service credential' AGENTS.md
check_req "SCAF-06" "AGENTS mentions ubuntu-latest" grep -qE 'ubuntu-latest' AGENTS.md

# All 11 canonical H2 sections present
for section in \
  "Project Overview" \
  "Development Environment" \
  "Build and Test Commands" \
  "Code Style" \
  "Testing Instructions" \
  "Release Process" \
  "Security Considerations" \
  "PR Guidelines" \
  "For AI Agents" \
  "Installation" \
  "Alternatives Considered"; do
  check_req "SCAF-06" "AGENTS has '## ${section}'" grep -qE "^## ${section}$" AGENTS.md
done

echo ""

# ──────────────────────────────────────────────
# Plan 02 — GitHub Config (SCAF-04, SCAF-05)
# ──────────────────────────────────────────────

echo "--- Plan 02: GitHub Config ---"

# SCAF-04: CODEOWNERS with glob ownership
check_req "SCAF-04" "CODEOWNERS exists" test -f .github/CODEOWNERS
check_req "SCAF-04" "CODEOWNERS has /actions/** @pau-vega" grep -qE '/actions/\*\* @pau-vega' .github/CODEOWNERS
check_req "SCAF-04" "No global catch-all in CODEOWNERS" bash -c '! grep -qE "^\* @" .github/CODEOWNERS'
check_req "SCAF-04" "No per-region literals in CODEOWNERS" bash -c '! grep -qE "/actions/nordvpn-" .github/CODEOWNERS'

# SCAF-05: Dependabot with plural directories
check_req "SCAF-05" "Dependabot exists" test -f .github/dependabot.yml
check_req "SCAF-05" "Dependabot has plural 'directories:'" grep -qE 'directories:' .github/dependabot.yml
check_req "SCAF-05" "No singular 'directory:'" bash -c '! grep -qE "^\s+directory:" .github/dependabot.yml'
check_req "SCAF-05" "Dependabot has 7 paths" bash -c '[ "$(grep -cE "^\s+- \"/" .github/dependabot.yml)" = "7" ]'
check_req "SCAF-05" "Dependabot has weekly schedule" grep -qE 'interval: "weekly"' .github/dependabot.yml
check_req "SCAF-05" "Dependabot deps prefix" grep -qE 'prefix: "deps"' .github/dependabot.yml

echo ""

# ──────────────────────────────────────────────
# Plan 03 — Lint Workflow (LINT-01..05)
# ──────────────────────────────────────────────

echo "--- Plan 03: Lint Workflow ---"

check_req "LINT-01" "Workflow exists" test -f .github/workflows/actions-lint.yml
check_req "LINT-01" "Workflow name is actions-lint" grep -qE '^name: actions-lint$' .github/workflows/actions-lint.yml
check_req "LINT-01" "Workflow triggers on pull_request" grep -qE 'pull_request:' .github/workflows/actions-lint.yml
check_req "LINT-01" "Workflow triggers on push to main" grep -qE 'push:' .github/workflows/actions-lint.yml

# LINT-02: actionlint job
check_req "LINT-02" "actionlint job uses reviewdog/action-actionlint" grep -qE 'reviewdog/action-actionlint' .github/workflows/actions-lint.yml
check_req "LINT-02" "actionlint has fail_on_error: true" grep -qE 'fail_on_error: true' .github/workflows/actions-lint.yml
check_req "LINT-02" "actionlint has level: error" grep -qE 'level: error' .github/workflows/actions-lint.yml

# LINT-03: shellcheck job
check_req "LINT-03" "shellcheck job uses ludeeus/action-shellcheck" grep -qE 'ludeeus/action-shellcheck' .github/workflows/actions-lint.yml
check_req "LINT-03" "shellcheck scandir ./actions" grep -qE 'scandir: \./actions' .github/workflows/actions-lint.yml
check_req "LINT-03" "shellcheck severity style" grep -qE 'severity: style' .github/workflows/actions-lint.yml
check_req "LINT-03" "shellcheck has SHELLCHECK_OPTS" grep -qE 'SHELLCHECK_OPTS' .github/workflows/actions-lint.yml

# LINT-04: permissions + concurrency
check_req "LINT-04" "Workflow has permissions block" grep -qE '^permissions:$' .github/workflows/actions-lint.yml
check_req "LINT-04" "Workflow has contents: read" grep -qE 'contents: read' .github/workflows/actions-lint.yml
check_req "LINT-04" "Workflow has concurrency block" grep -qE '^concurrency:$' .github/workflows/actions-lint.yml
check_req "LINT-04" "Workflow has cancel-in-progress" grep -qE 'cancel-in-progress: true' .github/workflows/actions-lint.yml

# LINT-05: block-pull-request-target job
check_req "LINT-05" "Workflow has block-pull-request-target job" grep -qE 'block-pull-request-target' .github/workflows/actions-lint.yml
check_req "LINT-05" "Guard cites AGENTS.md" grep -qE 'AGENTS\.md' .github/workflows/actions-lint.yml
check_req "LINT-05" "Guard cites PITFALLS.md" grep -qE 'PITFALLS\.md' .github/workflows/actions-lint.yml
check_req "LINT-05" "Guard uses exit 1" grep -qE 'exit 1' .github/workflows/actions-lint.yml
check_req "LINT-05" "Guard uses ::error::" grep -qE '::error::' .github/workflows/actions-lint.yml
check_req "LINT-05" "No pull_request_target in workflow" bash -c '! grep -qE "^[[:space:]]*pull_request_target[[:space:]]*:" .github/workflows/actions-lint.yml'

# Pin posture: no floating tags
check_req "LINT-PIN" "No uses: @main tag" bash -c '! grep -qE "uses: [^@]+@main" .github/workflows/actions-lint.yml'
check_req "LINT-PIN" "No uses: @latest tag" bash -c '! grep -qE "uses: [^@]+@latest" .github/workflows/actions-lint.yml'
check_req "LINT-PIN" "actions/checkout pinned by SHA" grep -qE 'actions/checkout@de0fac2e4500dabe0009e67214ff5f5447ce83dd' .github/workflows/actions-lint.yml
check_req "LINT-PIN" "action-actionlint pinned by SHA" grep -qE '6fb7acc99f4a1008869fa8a0f09cfca740837d9d' .github/workflows/actions-lint.yml
check_req "LINT-PIN" "action-shellcheck pinned by SHA" grep -qE '00cae500b08a931fb5698e11e79bfbd38e612a38' .github/workflows/actions-lint.yml

echo ""

# ──────────────────────────────────────────────
# Plan 04 — Branch Protection (SCAF-07)
# ──────────────────────────────────────────────

echo "--- Plan 04: Branch Protection Script ---"

# SCAF-07: script exists, executable, has correct content
check_req "SCAF-07" "Script exists" test -f scripts/setup-branch-protection.sh
check_req "SCAF-07" "Script is executable" test -x scripts/setup-branch-protection.sh
check_req "SCAF-07" "Script has bash shebang" bash -c 'head -n 1 scripts/setup-branch-protection.sh | grep -qE "^#!/usr/bin/env bash$"'
check_req "SCAF-07" "Script has set -euo pipefail" grep -qE '^set -euo pipefail$' scripts/setup-branch-protection.sh
check_req "SCAF-07" "OWNER = pau-vega" grep -qE 'OWNER="pau-vega"' scripts/setup-branch-protection.sh
check_req "SCAF-07" "REPO = nordvpn-action" grep -qE 'REPO="nordvpn-action"' scripts/setup-branch-protection.sh
check_req "SCAF-07" "Required check: actionlint" grep -qE '"context": "actionlint"' scripts/setup-branch-protection.sh
check_req "SCAF-07" "Required check: shellcheck" grep -qE '"context": "shellcheck"' scripts/setup-branch-protection.sh
check_req "SCAF-07" "Required check: block-pull-request-target" grep -qE '"context": "block-pull-request-target"' scripts/setup-branch-protection.sh
check_req "SCAF-07" "enforce_admins: true" grep -qE '"enforce_admins": true' scripts/setup-branch-protection.sh
check_req "SCAF-07" "gh api --method PUT" grep -qE -- '--method PUT' scripts/setup-branch-protection.sh
check_req "SCAF-07" "No set -x (leak prevention)" bash -c '! grep -qE "^[^#]*set [+-]?[a-z]*x" scripts/setup-branch-protection.sh'

echo ""
echo "--- All Plans: Lint Checks ---"

# Run actionlint on the workflow file
if command -v actionlint >/dev/null 2>&1; then
  if actionlint "$REPO_ROOT/.github/workflows/actions-lint.yml" >/dev/null 2>&1; then
    pass "actionlint: .github/workflows/actions-lint.yml passes"
  else
    fail "actionlint: .github/workflows/actions-lint.yml has errors"
    any_fail=1
  fi
else
  fail "actionlint: command not found (install with 'brew install actionlint')"
  any_fail=1
fi

# Run shellcheck on the branch protection script
if command -v shellcheck >/dev/null 2>&1; then
  if shellcheck "$REPO_ROOT/scripts/setup-branch-protection.sh" >/dev/null 2>&1; then
    pass "shellcheck: scripts/setup-branch-protection.sh passes"
  else
    fail "shellcheck: scripts/setup-branch-protection.sh has errors"
    any_fail=1
  fi
else
  fail "shellcheck: command not found (install with 'brew install shellcheck')"
  any_fail=1
fi

echo ""
echo "=========================================="
printf " Result: %d passed, %d failed\n" "$PASS" "$FAIL"
echo "=========================================="
echo ""

if [ "$any_fail" -eq 1 ]; then
  exit 1
fi
