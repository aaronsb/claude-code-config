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
WAY_DESC[softwaredev-code-testing]="writing unit tests, test coverage, mocking dependencies, test-driven development"
WAY_VOCAB[softwaredev-code-testing]="unittest coverage mock tdd assertion jest pytest rspec testcase spec fixture describe expect verify"
WAY_THRESH[softwaredev-code-testing]="2.0"

WAY_DESC[softwaredev-docs-api]="designing REST APIs, HTTP endpoints, API versioning, request response structure"
WAY_VOCAB[softwaredev-docs-api]="endpoint api rest route http status pagination versioning graphql request response header payload crud webhook"
WAY_THRESH[softwaredev-docs-api]="2.0"

WAY_DESC[softwaredev-environment-debugging]="debugging code issues, troubleshooting failures, investigating broken behavior, fixing bugs"
WAY_VOCAB[softwaredev-environment-debugging]="debug breakpoint stacktrace investigate troubleshoot regression bisect crash error fail bug log trace exception segfault hang timeout"
WAY_THRESH[softwaredev-environment-debugging]="2.0"

WAY_DESC[softwaredev-code-security]="application security, authentication, secrets management, input validation, vulnerability prevention"
WAY_VOCAB[softwaredev-code-security]="authentication secrets password credentials owasp injection xss sql sanitize vulnerability bcrypt hash encrypt token cert ssl tls csrf cors rotate login expose"
WAY_THRESH[softwaredev-code-security]="2.0"

WAY_DESC[softwaredev-architecture-design]="software system design architecture patterns database schema component modeling"
WAY_VOCAB[softwaredev-architecture-design]="architecture pattern database schema modeling interface component modules factory observer strategy monolith microservice domain layer coupling cohesion abstraction singleton proposal rfc sketch deliberation whiteboard"
WAY_THRESH[softwaredev-architecture-design]="2.0"

WAY_DESC[softwaredev-environment-config]="application configuration, environment variables, dotenv files, config file management"
WAY_VOCAB[softwaredev-environment-config]="dotenv environment configuration envvar config.json config.yaml connection port host url setting variable"
WAY_THRESH[softwaredev-environment-config]="2.0"

WAY_DESC[softwaredev-architecture-adr-context]="planning how to implement a feature, deciding an approach, understanding existing project decisions, starting work on an item, investigating why something was built a certain way"
WAY_VOCAB[softwaredev-architecture-adr-context]="plan approach debate implement build work pick understand investigate why how decision context tradeoff evaluate option consider scope"
WAY_THRESH[softwaredev-architecture-adr-context]="2.0"

WAY_DESC[softwaredev-delivery-commits]="git commit messages, branch naming, conventional commits, atomic changes"
WAY_VOCAB[softwaredev-delivery-commits]="commit message branch conventional feat fix refactor scope atomic squash amend stash rebase cherry"
WAY_THRESH[softwaredev-delivery-commits]="2.0"

WAY_DESC[softwaredev-delivery-github]="GitHub pull requests, issues, code review, CI checks, repository management"
WAY_VOCAB[softwaredev-delivery-github]="pr pullrequest issue review checks ci label milestone fork repository upstream draft"
WAY_THRESH[softwaredev-delivery-github]="2.0"

WAY_DESC[softwaredev-delivery-patches]="creating and applying patch files, git diff generation, patch series management"
WAY_VOCAB[softwaredev-delivery-patches]="patch diff apply hunk unified series format-patch"
WAY_THRESH[softwaredev-delivery-patches]="2.0"

WAY_DESC[softwaredev-delivery-release]="software releases, changelog generation, version bumping, semantic versioning, tagging"
WAY_VOCAB[softwaredev-delivery-release]="release changelog version bump semver tag publish ship major minor breaking"
WAY_THRESH[softwaredev-delivery-release]="2.0"

WAY_DESC[softwaredev-delivery-migrations]="database migrations, schema changes, table alterations, rollback procedures"
WAY_VOCAB[softwaredev-delivery-migrations]="migration schema alter table column index rollback seed ddl prisma alembic knex flyway"
WAY_THRESH[softwaredev-delivery-migrations]="2.0"

WAY_DESC[softwaredev-code-errors]="error handling patterns, exception management, try-catch boundaries, error wrapping and propagation"
WAY_VOCAB[softwaredev-code-errors]="exception handling catch throw boundary wrap rethrow fallback graceful recovery propagate unhandled"
WAY_THRESH[softwaredev-code-errors]="2.0"

WAY_DESC[softwaredev-code-quality]="code quality, refactoring, SOLID principles, code review standards, technical debt, maintainability"
WAY_VOCAB[softwaredev-code-quality]="refactor quality solid principle decompose extract method responsibility coupling cohesion maintainability readability"
WAY_THRESH[softwaredev-code-quality]="2.0"

WAY_DESC[softwaredev-code-performance]="performance optimization, profiling, benchmarking, latency reduction, memory efficiency"
WAY_VOCAB[softwaredev-code-performance]="optimize profile benchmark latency throughput memory cache bottleneck flamegraph allocation heap"
WAY_THRESH[softwaredev-code-performance]="2.0"

WAY_DESC[softwaredev-environment-deps]="dependency management, package installation, library evaluation, security auditing of third-party code"
WAY_VOCAB[softwaredev-environment-deps]="dependency package library install upgrade outdated audit vulnerability license bundle npm pip cargo"
WAY_THRESH[softwaredev-environment-deps]="2.0"

WAY_DESC[softwaredev-environment-ssh]="SSH remote access, key management, secure file transfer, non-interactive authentication"
WAY_VOCAB[softwaredev-environment-ssh]="ssh remote key agent scp rsync bastion jumphost tunnel forwarding batchmode noninteractive"
WAY_THRESH[softwaredev-environment-ssh]="2.0"

WAY_DESC[softwaredev-docs]="README authoring, docstrings, technical prose, Mermaid diagrams, project guides"
WAY_VOCAB[softwaredev-docs]="readme docstring technical writing mermaid diagram flowchart sequence onboarding"
WAY_THRESH[softwaredev-docs]="2.0"

WAY_DESC[softwaredev-architecture-threat-modeling]="threat modeling, STRIDE analysis, trust boundaries, attack surface assessment, security design review"
WAY_VOCAB[softwaredev-architecture-threat-modeling]="threat model stride attack surface trust boundary mitigation adversary dread spoofing tampering repudiation elevation"
WAY_THRESH[softwaredev-architecture-threat-modeling]="2.0"

WAY_DESC[softwaredev-docs-standards]="establishing team norms, coding conventions, testing philosophy, dependency policy, accessibility requirements"
WAY_VOCAB[softwaredev-docs-standards]="convention norm guideline accessibility style guide linting rule agreement philosophy"
WAY_THRESH[softwaredev-docs-standards]="2.0"

WAY_IDS=(softwaredev-code-testing softwaredev-docs-api softwaredev-environment-debugging softwaredev-code-security softwaredev-architecture-design softwaredev-environment-config softwaredev-architecture-adr-context softwaredev-delivery-commits softwaredev-delivery-github softwaredev-delivery-patches softwaredev-delivery-release softwaredev-delivery-migrations softwaredev-code-errors softwaredev-code-quality softwaredev-code-performance softwaredev-environment-deps softwaredev-environment-ssh softwaredev-docs softwaredev-architecture-threat-modeling softwaredev-docs-standards)

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
coact_full=0 coact_partial=0 coact_miss=0 coact_total=0
total=0

# --- NCD scorer ---
ncd_matches_way() {
  local prompt="$1" way_id="$2"
  local desc="${WAY_DESC[$way_id]}"
  local vocab="${WAY_VOCAB[$way_id]}"
  # NCD uses distance metric (0-1), not BM25 score threshold
  # Must match check-prompt.sh hardcoded value (0.58)
  local ncd_thresh="0.58"

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
  category=$(echo "$line" | jq -r '.category')
  note=$(echo "$line" | jq -r '.note // ""')

  # Parse expected: null → negative, string → single, array → co-activation
  expected_type=$(echo "$line" | jq -r '.expected | type')
  expected_list=()
  is_negative=false
  is_coact=false

  case "$expected_type" in
    null)   is_negative=true ;;
    string) expected_list=("$(echo "$line" | jq -r '.expected')") ;;
    array)  mapfile -t expected_list < <(echo "$line" | jq -r '.expected[]')
            [[ ${#expected_list[@]} -gt 1 ]] && is_coact=true ;;
  esac

  total=$((total + 1))
  $is_coact && coact_total=$((coact_total + 1))

  ncd_result="skip"
  bm25_result="skip"

  # --- Scorer evaluation function ---
  # Usage: eval_scorer <scorer_name> <prompt> <expected_list...>
  # Sets: ${scorer}_result variable
  eval_scorer() {
    local scorer="$1" prompt="$2"
    shift 2
    local exp_list=("$@")
    local result=""

    if $is_negative; then
      # Negative test: check no way matches
      local any_match=false
      for way_id in "${WAY_IDS[@]}"; do
        if "${scorer}_matches_way" "$prompt" "$way_id"; then
          any_match=true
          result="FP:$way_id"
          break
        fi
      done
      if [[ "$any_match" == false ]]; then
        result="TN"
      fi
    elif $is_coact; then
      # Co-activation: check ALL expected ways match
      local matched=0
      local missed=""
      for exp in "${exp_list[@]}"; do
        if "${scorer}_matches_way" "$prompt" "$exp"; then
          matched=$((matched + 1))
        else
          missed+="${exp##*-} "
        fi
      done
      if [[ $matched -eq ${#exp_list[@]} ]]; then
        result="FULL"
      elif [[ $matched -gt 0 ]]; then
        result="PARTIAL:${missed% }"
      else
        result="MISS"
      fi
    else
      # Single-expected: check the one expected way matches
      if "${scorer}_matches_way" "$prompt" "${exp_list[0]}"; then
        result="TP"
      else
        result="FN"
      fi
    fi

    echo "$result"
  }

  # NCD scoring
  if [[ "$RUN_NCD" == true ]]; then
    ncd_result=$(eval_scorer "ncd" "$prompt" "${expected_list[@]+"${expected_list[@]}"}")
    case "$ncd_result" in
      TP|FULL) ncd_tp=$((ncd_tp + 1)) ;;
      TN)      ncd_tn=$((ncd_tn + 1)) ;;
      FN|MISS) ncd_fn=$((ncd_fn + 1)) ;;
      FP:*)      ncd_fp=$((ncd_fp + 1)) ;;
      PARTIAL:*) ncd_fn=$((ncd_fn + 1)) ;;
    esac
  fi

  # BM25 scoring
  if [[ "$RUN_BM25" == true ]]; then
    bm25_result=$(eval_scorer "bm25" "$prompt" "${expected_list[@]+"${expected_list[@]}"}")
    case "$bm25_result" in
      TP|FULL) bm25_tp=$((bm25_tp + 1)) ;;
      TN)      bm25_tn=$((bm25_tn + 1)) ;;
      FN|MISS) bm25_fn=$((bm25_fn + 1)) ;;
      FP:*)      bm25_fp=$((bm25_fp + 1)) ;;
      PARTIAL:*) bm25_fn=$((bm25_fn + 1)) ;;
    esac
    # Track co-activation detail for BM25
    if $is_coact; then
      case "$bm25_result" in
        FULL)      coact_full=$((coact_full + 1)) ;;
        PARTIAL:*) coact_partial=$((coact_partial + 1)) ;;
        MISS)      coact_miss=$((coact_miss + 1)) ;;
      esac
    fi
  fi

  # Head-to-head
  if [[ "$RUN_NCD" == true ]] && [[ "$RUN_BM25" == true ]]; then
    ncd_correct=false
    bm25_correct=false
    [[ "$ncd_result" == "TP" || "$ncd_result" == "TN" || "$ncd_result" == "FULL" ]] && ncd_correct=true
    [[ "$bm25_result" == "TP" || "$bm25_result" == "TN" || "$bm25_result" == "FULL" ]] && bm25_correct=true

    if [[ "$bm25_correct" == true ]] && [[ "$ncd_correct" == false ]]; then
      bm25_wins=$((bm25_wins + 1))
    elif [[ "$ncd_correct" == true ]] && [[ "$bm25_correct" == false ]]; then
      ncd_wins=$((ncd_wins + 1))
    else
      ties=$((ties + 1))
    fi
  fi

  # Output — show failures always, everything in verbose
  show=false
  if [[ "$VERBOSE" == true ]]; then show=true; fi
  case "$ncd_result" in FN|MISS|FP:*|PARTIAL:*) show=true ;; esac
  case "$bm25_result" in FN|MISS|FP:*|PARTIAL:*) show=true ;; esac

  if $show; then
    printf "%-3s " "$total"
    printf "[%-12s] " "$category"

    # NCD result
    if [[ "$RUN_NCD" == true ]]; then
      case "$ncd_result" in
        TP|TN|FULL)       printf "${GREEN}NCD:%-10s${NC} " "$ncd_result" ;;
        FN|MISS)           printf "${RED}NCD:%-10s${NC} " "$ncd_result" ;;
        FP:*|PARTIAL:*)    printf "${YELLOW}NCD:%-10s${NC} " "$ncd_result" ;;
      esac
    fi

    # BM25 result
    if [[ "$RUN_BM25" == true ]]; then
      case "$bm25_result" in
        TP|TN|FULL)       printf "${GREEN}BM25:%-10s${NC} " "$bm25_result" ;;
        FN|MISS)           printf "${RED}BM25:%-10s${NC} " "$bm25_result" ;;
        FP:*|PARTIAL:*)    printf "${YELLOW}BM25:%-10s${NC} " "$bm25_result" ;;
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

if [[ $coact_total -gt 0 ]]; then
  echo ""
  echo "Co-activation ($coact_total tests):  full=$coact_full  partial=$coact_partial  miss=$coact_miss"
fi
