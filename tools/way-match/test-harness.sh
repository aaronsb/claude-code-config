#!/bin/bash
# Test harness for way-match: compares BM25 binary vs gzip NCD baseline
# Usage: ./test-harness.sh [--ncd-only] [--bm25-only] [--verbose]
#
# Runs test fixtures against both scorers and reports:
# - Per-test pass/fail
# - Match matrix (TP, FP, TN, FN per scorer)
# - Head-to-head comparison (BM25 wins, NCD wins, ties)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
FIXTURES="$SCRIPT_DIR/test-fixtures.jsonl"
NCD_SCRIPT="$SCRIPT_DIR/../../hooks/ways/semantic-match.sh"
BM25_BINARY="$SCRIPT_DIR/../../bin/way-match"

# Way corpus: id|description|vocabulary|threshold
declare -A WAY_DESC WAY_VOCAB WAY_THRESH
WAY_DESC[softwaredev-testing]="writing unit tests, test coverage, mocking dependencies, test-driven development"
WAY_VOCAB[softwaredev-testing]="unittest coverage mock tdd assertion jest pytest rspec testcase spec fixture describe expect verify"
WAY_THRESH[softwaredev-testing]="2.0"

WAY_DESC[softwaredev-api]="designing REST APIs, HTTP endpoints, API versioning, request response structure"
WAY_VOCAB[softwaredev-api]="endpoint api rest route http status pagination versioning graphql request response header payload crud webhook"
WAY_THRESH[softwaredev-api]="2.0"

WAY_DESC[softwaredev-debugging]="debugging code issues, troubleshooting errors, investigating broken behavior, fixing bugs"
WAY_VOCAB[softwaredev-debugging]="debug breakpoint stacktrace investigate troubleshoot regression bisect crash error fail bug log trace exception segfault hang timeout"
WAY_THRESH[softwaredev-debugging]="2.0"

WAY_DESC[softwaredev-security]="application security, authentication, secrets management, input validation, vulnerability prevention"
WAY_VOCAB[softwaredev-security]="authentication secrets password credentials owasp injection xss sql sanitize vulnerability bcrypt hash encrypt token cert ssl tls csrf cors rotate login expose"
WAY_THRESH[softwaredev-security]="2.0"

WAY_DESC[softwaredev-design]="software system design architecture patterns database schema component modeling"
WAY_VOCAB[softwaredev-design]="architecture pattern database schema modeling interface component modules factory observer strategy monolith microservice domain layer coupling cohesion abstraction singleton"
WAY_THRESH[softwaredev-design]="2.0"

WAY_DESC[softwaredev-config]="application configuration, environment variables, dotenv files, config file management"
WAY_VOCAB[softwaredev-config]="dotenv environment configuration envvar config.json config.yaml connection port host url setting variable"
WAY_THRESH[softwaredev-config]="2.0"

WAY_DESC[softwaredev-adr-context]="planning how to implement a feature, deciding an approach, understanding existing project decisions, starting work on an item, investigating why something was built a certain way"
WAY_VOCAB[softwaredev-adr-context]="plan approach debate implement build work pick understand investigate why how decision context tradeoff evaluate option consider scope"
WAY_THRESH[softwaredev-adr-context]="2.0"

WAY_IDS=(softwaredev-testing softwaredev-api softwaredev-debugging softwaredev-security softwaredev-design softwaredev-config softwaredev-adr-context)

# --- Options ---
RUN_NCD=true
RUN_BM25=true
VERBOSE=false

for arg in "$@"; do
  case "$arg" in
    --ncd-only)  RUN_BM25=false ;;
    --bm25-only) RUN_NCD=false ;;
    --verbose)   VERBOSE=true ;;
  esac
done

if [[ "$RUN_BM25" == true ]] && [[ ! -x "$BM25_BINARY" ]]; then
  echo "note: bin/way-match not found, running NCD only"
  RUN_BM25=false
fi

if [[ ! -f "$FIXTURES" ]]; then
  echo "error: test fixtures not found at $FIXTURES" >&2
  exit 1
fi

# --- Counters ---
ncd_tp=0 ncd_fp=0 ncd_tn=0 ncd_fn=0
bm25_tp=0 bm25_fp=0 bm25_tn=0 bm25_fn=0
bm25_wins=0 ncd_wins=0 ties=0
total=0

# --- NCD scorer ---
ncd_matches_way() {
  local prompt="$1" way_id="$2"
  local desc="${WAY_DESC[$way_id]}"
  local vocab="${WAY_VOCAB[$way_id]}"
  # NCD uses distance metric (0-1), not BM25 score threshold
  local ncd_thresh="0.55"

  if bash "$NCD_SCRIPT" "$prompt" "$desc" "$vocab" "$ncd_thresh" 2>/dev/null; then
    return 0
  else
    return 1
  fi
}

# --- BM25 scorer ---
bm25_matches_way() {
  local prompt="$1" way_id="$2"
  local desc="${WAY_DESC[$way_id]}"
  local vocab="${WAY_VOCAB[$way_id]}"
  local thresh="${WAY_THRESH[$way_id]}"

  if "$BM25_BINARY" pair \
    --description "$desc" \
    --vocabulary "$vocab" \
    --query "$prompt" \
    --threshold "$thresh" 2>/dev/null; then
    return 0
  else
    return 1
  fi
}

# --- Score a prompt against all ways, return best match ---
# For BM25: scores all ways, returns highest-scoring match.
# For NCD: binary scorer (no score output), returns first match.
find_best_match() {
  local scorer="$1" prompt="$2"

  if [[ "$scorer" == "bm25" ]]; then
    local best_way="none" best_score="0"
    for way_id in "${WAY_IDS[@]}"; do
      local stderr_out
      stderr_out=$("$BM25_BINARY" pair \
        --description "${WAY_DESC[$way_id]}" \
        --vocabulary "${WAY_VOCAB[$way_id]}" \
        --query "$prompt" \
        --threshold "0" 2>&1 >/dev/null)
      local score
      score=$(echo "$stderr_out" | sed -n 's/match: score=\([0-9.]*\).*/\1/p')
      if [[ -n "$score" ]] && command -v bc >/dev/null 2>&1; then
        if (( $(echo "$score > $best_score" | bc -l) )); then
          best_score="$score"
          best_way="$way_id"
        fi
      fi
    done
    # Verify best actually meets its threshold
    if [[ "$best_way" != "none" ]]; then
      local thresh="${WAY_THRESH[$best_way]}"
      if command -v bc >/dev/null 2>&1 && (( $(echo "$best_score < $thresh" | bc -l) )); then
        best_way="none"
      fi
    fi
    echo "$best_way"
    return 0
  fi

  # NCD fallback: binary match, return first
  for way_id in "${WAY_IDS[@]}"; do
    if "${scorer}_matches_way" "$prompt" "$way_id"; then
      echo "$way_id"
      return 0
    fi
  done
  echo "none"
  return 0
}

# --- Colors ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
NC='\033[0m'

# --- Run tests ---
echo "=== Way-Match Test Harness ==="
echo "Fixtures: $FIXTURES"
echo "Scorers:  $([ "$RUN_NCD" == true ] && echo "NCD") $([ "$RUN_BM25" == true ] && echo "BM25")"
echo ""

while IFS= read -r line; do
  prompt=$(echo "$line" | jq -r '.prompt')
  expected=$(echo "$line" | jq -r '.expected // "none"')
  should_match=$(echo "$line" | jq -r '.match')
  category=$(echo "$line" | jq -r '.category')
  note=$(echo "$line" | jq -r '.note // ""')

  total=$((total + 1))

  ncd_result="skip"
  bm25_result="skip"

  # NCD scoring
  if [[ "$RUN_NCD" == true ]]; then
    if [[ "$expected" == "none" ]]; then
      # Negative test: check no way matches
      any_match=false
      for way_id in "${WAY_IDS[@]}"; do
        if ncd_matches_way "$prompt" "$way_id"; then
          any_match=true
          ncd_result="FP:$way_id"
          break
        fi
      done
      if [[ "$any_match" == false ]]; then
        ncd_result="TN"
        ncd_tn=$((ncd_tn + 1))
      else
        ncd_fp=$((ncd_fp + 1))
      fi
    else
      # Positive test: check expected way matches
      if ncd_matches_way "$prompt" "$expected"; then
        ncd_result="TP"
        ncd_tp=$((ncd_tp + 1))
      else
        ncd_result="FN"
        ncd_fn=$((ncd_fn + 1))
      fi
    fi
  fi

  # BM25 scoring
  if [[ "$RUN_BM25" == true ]]; then
    if [[ "$expected" == "none" ]]; then
      any_match=false
      for way_id in "${WAY_IDS[@]}"; do
        if bm25_matches_way "$prompt" "$way_id"; then
          any_match=true
          bm25_result="FP:$way_id"
          break
        fi
      done
      if [[ "$any_match" == false ]]; then
        bm25_result="TN"
        bm25_tn=$((bm25_tn + 1))
      else
        bm25_fp=$((bm25_fp + 1))
      fi
    else
      if bm25_matches_way "$prompt" "$expected"; then
        bm25_result="TP"
        bm25_tp=$((bm25_tp + 1))
      else
        bm25_result="FN"
        bm25_fn=$((bm25_fn + 1))
      fi
    fi
  fi

  # Head-to-head
  if [[ "$RUN_NCD" == true ]] && [[ "$RUN_BM25" == true ]]; then
    ncd_correct=false
    bm25_correct=false
    [[ "$ncd_result" == "TP" || "$ncd_result" == "TN" ]] && ncd_correct=true
    [[ "$bm25_result" == "TP" || "$bm25_result" == "TN" ]] && bm25_correct=true

    if [[ "$bm25_correct" == true ]] && [[ "$ncd_correct" == false ]]; then
      bm25_wins=$((bm25_wins + 1))
    elif [[ "$ncd_correct" == true ]] && [[ "$bm25_correct" == false ]]; then
      ncd_wins=$((ncd_wins + 1))
    else
      ties=$((ties + 1))
    fi
  fi

  # Output
  if [[ "$VERBOSE" == true ]] || [[ "$ncd_result" == "FN" ]] || [[ "$ncd_result" == FP:* ]] || [[ "$bm25_result" == "FN" ]] || [[ "$bm25_result" == FP:* ]]; then
    printf "%-3s " "$total"
    printf "[%-7s] " "$category"

    # NCD result
    if [[ "$RUN_NCD" == true ]]; then
      case "$ncd_result" in
        TP|TN) printf "${GREEN}NCD:%-6s${NC} " "$ncd_result" ;;
        FN)    printf "${RED}NCD:%-6s${NC} " "$ncd_result" ;;
        FP:*)  printf "${YELLOW}NCD:%-6s${NC} " "$ncd_result" ;;
      esac
    fi

    # BM25 result
    if [[ "$RUN_BM25" == true ]]; then
      case "$bm25_result" in
        TP|TN) printf "${GREEN}BM25:%-6s${NC} " "$bm25_result" ;;
        FN)    printf "${RED}BM25:%-6s${NC} " "$bm25_result" ;;
        FP:*)  printf "${YELLOW}BM25:%-6s${NC} " "$bm25_result" ;;
      esac
    fi

    printf "%s" "$prompt"
    [[ -n "$note" ]] && printf " ${CYAN}(%s)${NC}" "$note"
    echo ""
  fi

done < "$FIXTURES"

# --- Summary ---
echo ""
echo "=== Results ($total tests) ==="
echo ""

if [[ "$RUN_NCD" == true ]]; then
  ncd_correct=$((ncd_tp + ncd_tn))
  ncd_total=$((ncd_tp + ncd_fp + ncd_tn + ncd_fn))
  echo "NCD (gzip):  TP=$ncd_tp FP=$ncd_fp TN=$ncd_tn FN=$ncd_fn  accuracy=$ncd_correct/$ncd_total"
fi

if [[ "$RUN_BM25" == true ]]; then
  bm25_correct=$((bm25_tp + bm25_tn))
  bm25_total=$((bm25_tp + bm25_fp + bm25_tn + bm25_fn))
  echo "BM25:        TP=$bm25_tp FP=$bm25_fp TN=$bm25_tn FN=$bm25_fn  accuracy=$bm25_correct/$bm25_total"
fi

if [[ "$RUN_NCD" == true ]] && [[ "$RUN_BM25" == true ]]; then
  echo ""
  echo "Head-to-head: BM25 wins=$bm25_wins  NCD wins=$ncd_wins  ties=$ties"
fi
