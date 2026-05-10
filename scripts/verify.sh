#!/usr/bin/env bash
# scripts/verify.sh
#
# Generic verification dispatcher.
# Runs phase-specific verify scripts.
#
# Usage:
#   bash scripts/verify.sh [phase-slug]
#
# If no phase-slug given, runs all available phase verify scripts.
# If phase-slug given, runs only that phase's verify script.
#
# Examples:
#   bash scripts/verify.sh                          # run all phases
#   bash scripts/verify.sh 01-scaffolding-lint       # run phase 1 by slug
#   bash scripts/verify.sh phase-1                   # run phase 1 by short name

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PHASE="${1:-}"

# Map a phase slug to a verify script path.
# Supports:
#   - "phase-N"     -> verify-phase-N.sh
#   - "NN-slug"     -> verify-phase-N.sh  (extracts N from leading digits)
#   - "NN-slug"     -> verify-NN-slug.sh  (exact match)
resolve_script() {
  local slug="$1"

  # Direct match: verify-{slug}.sh
  local direct="$REPO_ROOT/scripts/verify-${slug}.sh"
  if [ -f "$direct" ]; then
    echo "$direct"
    return 0
  fi

  # Pattern: phase-N -> verify-phase-N.sh
  if [[ "$slug" =~ ^phase-([0-9]+)$ ]]; then
    local candidate="$REPO_ROOT/scripts/verify-phase-${BASH_REMATCH[1]}.sh"
    if [ -f "$candidate" ]; then
      echo "$candidate"
      return 0
    fi
  fi

  # Pattern: NN-slug -> extract NN, try verify-phase-NN.sh
  if [[ "$slug" =~ ^([0-9]+)- ]]; then
    local num="${BASH_REMATCH[1]}"
    local candidate="$REPO_ROOT/scripts/verify-phase-${num}.sh"
    if [ -f "$candidate" ]; then
      echo "$candidate"
      return 0
    fi
  fi

  # Fallback: return the direct path (will fail with clear message)
  echo "$direct"
  return 1
}

run_phase_verify() {
  local script="$1"
  local label="$2"

  if [ -f "$script" ]; then
    echo ""
    echo "=== Phase: ${label} ==="
    bash "$script"
  else
    echo "No verify script for phase '${label}' (expected: ${script})"
    return 1
  fi
}

if [ -n "$PHASE" ]; then
  # Run a specific phase
  script="$(resolve_script "$PHASE")"
  run_phase_verify "$script" "$PHASE"
else
  # Run all available phase verify scripts
  any_fail=0
  for script in "$REPO_ROOT"/scripts/verify-*.sh; do
    # Skip the dispatcher itself
    [ "$(basename "$script")" = "verify.sh" ] && continue
    [ ! -f "$script" ] && continue

    label="$(basename "$script" .sh | sed 's/^verify-//')"
    if ! run_phase_verify "$script" "$label"; then
      any_fail=1
    fi
  done

  if [ "$any_fail" -eq 1 ]; then
    exit 1
  fi
fi
