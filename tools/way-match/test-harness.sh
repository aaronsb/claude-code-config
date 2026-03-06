#!/bin/bash
# Test harness for way-match: compares BM25 binary vs gzip NCD baseline
# Usage: ./test-harness.sh [--ncd-only] [--bm25-only] [--verbose]
#
# Runs test fixtures against both scorers and reports:
# - Per-test pass/fail
# - Match matrix (TP, FP, TN, FN per scorer)
# - Head-to-head comparison (BM25 wins, NCD wins, ties)
#
# Compatible with bash 3.2+ (macOS default)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
FIXTURES="$SCRIPT_DIR/test-fixtures.jsonl"
NCD_SCRIPT="$SCRIPT_DIR/../../hooks/ways/semantic-match.sh"
BM25_BINARY="$SCRIPT_DIR/../../bin/way-match"

# Way corpus: parallel arrays (bash 3.2 compatible — no associative arrays)
WAY_IDS=()
WAY_DESCS=()
WAY_VOCABS=()
WAY_THRESHS=()

add_way() {
  WAY_IDS+=("$1")
  WAY_DESCS+=("$2")
  WAY_VOCABS+=("$3")
  WAY_THRESHS+=("$4")
}

# Lookup index by way ID; returns via global __idx (-1 if not found)
__idx=-1
way_index() {
  local target="$1"
  local i
  for (( i=0; i<${#WAY_IDS[@]}; i++ )); do
    if [[ "${WAY_IDS[$i]}" == "$target" ]]; then
      __idx=$i; return 0
    fi
  done
  __idx=-1; return 1
}

add_way "softwaredev-code-testing" \
  "writing unit tests, test coverage, mocking dependencies, test-driven development" \
  "unittest coverage mock tdd assertion jest pytest rspec testcase spec fixture describe expect verify" \
  "2.0"

add_way "softwaredev-docs-api" \
  "designing REST APIs, HTTP endpoints, API versioning, request response structure" \
  "endpoint api rest route http status pagination versioning graphql request response header payload crud webhook" \
  "2.0"

add_way "softwaredev-environment-debugging" \
  "debugging, troubleshooting failures, investigating broken behavior" \
  "debug breakpoint stacktrace investigate troubleshoot regression bisect crash crashes crashing error fail bug log trace exception segfault hang timeout step broken" \
  "2.0"

add_way "softwaredev-code-security" \
  "security, authentication, secrets management, input validation" \
  "authentication secrets password credentials owasp injection xss sql sanitize vulnerability bcrypt hash encrypt token cert ssl tls csrf cors rotate login expose exposed harden" \
  "2.0"

add_way "softwaredev-architecture-design" \
  "software system design, architecture patterns, database schema, component modeling, proposals, RFCs, design deliberation" \
  "architecture pattern database schema modeling interface component modules factory observer strategy monolith microservice microservices domain layer coupling cohesion abstraction singleton proposal rfc sketch deliberation whiteboard" \
  "2.0"

add_way "softwaredev-environment-config" \
  "configuration, environment variables, dotenv files, connection settings" \
  "dotenv environment configuration envvar config.json config.yaml connection port host url setting variable string" \
  "2.0"

add_way "softwaredev-architecture-adr-context" \
  "planning how to implement a feature, deciding an approach, understanding existing project decisions, starting work on an item, investigating why something was built a certain way" \
  "plan approach debate implement build work pick understand investigate why how decision context tradeoff evaluate option consider scope" \
  "2.0"

add_way "softwaredev-delivery-commits" \
  "git commit messages, branch naming, conventional commits, atomic changes" \
  "commit message branch conventional feat fix refactor scope atomic squash amend stash rebase cherry" \
  "2.0"

add_way "softwaredev-delivery-github" \
  "GitHub pull requests, issues, code review, CI checks, repository management" \
  "pr pullrequest issue review checks ci label milestone fork repository upstream draft" \
  "2.0"

add_way "softwaredev-delivery-patches" \
  "creating and applying patch files, git diff generation, patch series management" \
  "patch diff apply hunk unified series format-patch" \
  "2.0"

add_way "softwaredev-delivery-release" \
  "software releases, changelog generation, version bumping, semantic versioning, tagging" \
  "release changelog version bump semver tag publish ship major minor breaking" \
  "2.0"

add_way "softwaredev-delivery-migrations" \
  "database migrations, schema changes, table alterations, rollback procedures" \
  "migration schema alter table column index rollback seed ddl prisma alembic knex flyway" \
  "2.0"

add_way "softwaredev-code-errors" \
  "error handling patterns, exception management, try-catch boundaries, error wrapping and propagation" \
  "exception handling catch throw boundary wrap rethrow fallback graceful recovery propagate unhandled" \
  "2.0"

add_way "softwaredev-code-quality" \
  "code quality, refactoring, SOLID principles, code review standards, technical debt, maintainability" \
  "refactor quality solid principle decompose extract method responsibility coupling cohesion maintainability readability" \
  "2.0"

add_way "softwaredev-code-performance" \
  "performance optimization, profiling, benchmarking, latency" \
  "optimize profile benchmark latency throughput memory cache bottleneck flamegraph allocation heap speed slow" \
  "2.0"

add_way "softwaredev-environment-deps" \
  "dependency management, package installation, library evaluation, security auditing of third-party code" \
  "dependency package library install upgrade outdated audit vulnerability license bundle npm pip cargo" \
  "2.0"

add_way "softwaredev-environment-ssh" \
  "SSH remote access, key management, secure file transfer, non-interactive authentication" \
  "ssh remote key agent scp rsync bastion jumphost tunnel forwarding batchmode noninteractive" \
  "2.0"

add_way "softwaredev-docs" \
  "README authoring, docstrings, technical prose, Mermaid diagrams, project guides" \
  "readme docstring technical writing mermaid diagram flowchart sequence onboarding" \
  "2.0"

add_way "softwaredev-architecture-threat-modeling" \
  "threat modeling, STRIDE analysis, trust boundaries, attack surface assessment, security design review" \
  "threat model stride attack surface trust boundary mitigation adversary dread spoofing tampering repudiation elevation" \
  "2.0"

add_way "softwaredev-docs-standards" \
  "establishing team norms, coding conventions, testing philosophy, dependency policy, accessibility requirements" \
  "convention norm guideline accessibility style guide linting rule agreement philosophy" \
  "2.0"

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
  way_index "$way_id" || return 1
  local desc="${WAY_DESCS[$__idx]}"
  local vocab="${WAY_VOCABS[$__idx]}"
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
  way_index "$way_id" || return 1
  local desc="${WAY_DESCS[$__idx]}"
  local vocab="${WAY_VOCABS[$__idx]}"
  local thresh="${WAY_THRESHS[$__idx]}"

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

  # Parse expected: null -> negative, string -> single, array -> co-activation
  expected_type=$(echo "$line" | jq -r '.expected | type')
  expected_list=()
  is_negative=false
  is_coact=false

  case "$expected_type" in
    null)   is_negative=true ;;
    string) expected_list=("$(echo "$line" | jq -r '.expected')") ;;
    array)
      while IFS= read -r item; do
        expected_list+=("$item")
      done < <(echo "$line" | jq -r '.expected[]')
      [[ ${#expected_list[@]} -gt 1 ]] && is_coact=true
      ;;
  esac

  total=$((total + 1))
  $is_coact && coact_total=$((coact_total + 1))

  ncd_result="skip"
  bm25_result="skip"

  # --- Scorer evaluation function ---
  eval_scorer() {
    local scorer="$1" prompt="$2"
    shift 2
    local exp_list=("$@")
    local result=""

    if $is_negative; then
      local any_match=false
      local i
      for (( i=0; i<${#WAY_IDS[@]}; i++ )); do
        if "${scorer}_matches_way" "$prompt" "${WAY_IDS[$i]}"; then
          any_match=true
          result="FP:${WAY_IDS[$i]}"
          break
        fi
      done
      if [[ "$any_match" == false ]]; then
        result="TN"
      fi
    elif $is_coact; then
      local matched=0
      local missed=""
      local exp
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
