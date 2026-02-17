#!/bin/bash
# Run BM25 vs NCD scorer tests from the tests/ directory.
# Wraps tools/way-match/test-harness.sh and test-integration.sh.
#
# Usage: tests/way-match/run-tests.sh [fixture|integration|all] [--verbose]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$SCRIPT_DIR/../.."
HARNESS="$REPO_ROOT/tools/way-match/test-harness.sh"
INTEGRATION="$REPO_ROOT/tools/way-match/test-integration.sh"

MODE="${1:-all}"
shift 2>/dev/null || true
EXTRA_ARGS="$*"

case "$MODE" in
  fixture|fixtures)
    bash "$HARNESS" $EXTRA_ARGS
    ;;
  integration)
    bash "$INTEGRATION" $EXTRA_ARGS
    ;;
  all)
    echo "=== Fixture Tests (BM25 vs NCD, synthetic corpus) ==="
    echo ""
    bash "$HARNESS" --verbose $EXTRA_ARGS
    echo ""
    echo "=== Integration Tests (real way files) ==="
    echo ""
    bash "$INTEGRATION" $EXTRA_ARGS
    ;;
  *)
    echo "Usage: $0 [fixture|integration|all] [--verbose]" >&2
    exit 1
    ;;
esac
