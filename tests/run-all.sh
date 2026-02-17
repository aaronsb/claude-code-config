#!/bin/bash
# Run all automated tests. Exit non-zero if any fail.
#
# Usage: tests/run-all.sh [--verbose]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$SCRIPT_DIR/.."
VERBOSE="${1:-}"

PASS=0
FAIL=0

run_suite() {
  local name="$1"
  shift
  echo ""
  echo "=== $name ==="
  echo ""
  if "$@" 2>&1; then
    PASS=$((PASS + 1))
  else
    FAIL=$((FAIL + 1))
    echo "^^^ FAILED: $name"
  fi
}

# Way-match fixture tests (BM25 vs NCD)
run_suite "Way-Match Fixture Tests" bash "$REPO_ROOT/tools/way-match/test-harness.sh" ${VERBOSE:+--verbose}

# Way-match integration tests (real way files)
if [[ -x "$REPO_ROOT/bin/way-match" ]]; then
  run_suite "Way-Match Integration Tests" bash "$REPO_ROOT/tools/way-match/test-integration.sh"
else
  echo ""
  echo "=== Way-Match Integration Tests ==="
  echo "SKIP: bin/way-match not found (build with 'make local')"
fi

# Doc-graph link integrity
run_suite "Doc-Graph Link Integrity" bash "$REPO_ROOT/scripts/doc-graph.sh" --stats

# Governance provenance verification
if command -v python3 &>/dev/null; then
  run_suite "Governance Provenance Verification" bash "$REPO_ROOT/governance/provenance-verify.sh"
else
  echo ""
  echo "=== Governance Provenance Verification ==="
  echo "SKIP: python3 not found"
fi

echo ""
echo "=== Summary ==="
echo "Passed: $PASS  Failed: $FAIL"
[[ $FAIL -eq 0 ]]
