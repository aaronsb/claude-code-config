#!/bin/bash
# Integration test: run way-match against actual way.md files
# Reads frontmatter from real semantic ways and scores test prompts
#
# This tests the real pipeline: way files → frontmatter extraction → BM25 scoring

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
WAYS_DIR="$SCRIPT_DIR/../../hooks/ways"
BM25_BINARY="$SCRIPT_DIR/../../bin/way-match"
NCD_SCRIPT="$SCRIPT_DIR/../../hooks/ways/semantic-match.sh"

if [[ ! -x "$BM25_BINARY" ]]; then
  echo "error: bin/way-match not found" >&2
  exit 1
fi

# --- Colors ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# --- Extract frontmatter from actual way files ---
declare -A WAY_DESC WAY_VOCAB WAY_THRESH WAY_PATH

echo -e "${BOLD}=== Integration Test: Real Way Files ===${NC}"
echo ""
echo "Scanning for semantic ways..."
echo ""

while IFS= read -r wayfile; do
  # Derive way ID from path
  rel=$(echo "$wayfile" | sed "s|$WAYS_DIR/||;s|/way\.md$||")
  way_id=$(echo "$rel" | tr '/' '-')

  desc=$(sed -n 's/^description: *//p' "$wayfile")
  vocab=$(sed -n 's/^vocabulary: *//p' "$wayfile")
  thresh=$(sed -n 's/^threshold: *//p' "$wayfile")

  # Skip ways without semantic matching fields
  [[ -z "$desc" || -z "$vocab" ]] && continue

  WAY_DESC[$way_id]="$desc"
  WAY_VOCAB[$way_id]="$vocab"
  WAY_THRESH[$way_id]="${thresh:-2.0}"
  WAY_PATH[$way_id]="$wayfile"

  printf "  %-30s thresh=%-5s  %s\n" "$way_id" "${thresh:-2.0}" "$(echo "$desc" | cut -c1-60)"
done < <(find "$WAYS_DIR" -name "way.md" -type f | sort)

echo ""
echo "Found ${#WAY_DESC[@]} semantic ways"
echo ""

# --- Test prompts with expected matches ---
# Format: "expected_way_id|prompt"
# Use "NONE" for prompts that shouldn't match anything
TEST_CASES=(
  # Direct matches — vocabulary terms present
  "softwaredev-code-testing|write some unit tests for this module"
  "softwaredev-code-testing|run pytest with coverage"
  "softwaredev-code-testing|mock the database connection in tests"
  "softwaredev-docs-api|design the REST API for user management"
  "softwaredev-docs-api|what status code should this endpoint return"
  "softwaredev-docs-api|add versioning to the API"
  "softwaredev-environment-debugging|debug why this function returns null"
  "softwaredev-environment-debugging|troubleshoot the failing deployment"
  "softwaredev-environment-debugging|bisect to find which commit broke it"
  "softwaredev-code-security|fix the SQL injection vulnerability"
  "softwaredev-code-security|store passwords with bcrypt"
  "softwaredev-code-security|sanitize the form input"
  "softwaredev-architecture-design|design the database schema"
  "softwaredev-architecture-design|use the factory pattern here"
  "softwaredev-architecture-design|model the component interfaces"
  "softwaredev-environment-config|set up the .env file for production"
  "softwaredev-environment-config|manage environment variables"
  "softwaredev-environment-config|configure the yaml settings"
  "softwaredev-architecture-adr-context|plan how to build the notification system"
  "softwaredev-architecture-adr-context|why was this feature designed this way"
  "softwaredev-architecture-adr-context|pick up work on the auth implementation"
  # Negative cases — should not trigger any semantic way
  "NONE|what is the capital of France"
  "NONE|tell me about photosynthesis"
  "NONE|how tall is Mount Everest"
  "NONE|write a haiku about rain"
  # Realistic prompts that are borderline
  "softwaredev-code-testing|does this code have enough test coverage"
  "softwaredev-docs-api|the endpoint is returning 500 errors"
  "softwaredev-environment-debugging|the app keeps crashing on startup"
  "softwaredev-code-security|are our API keys exposed anywhere"
  "softwaredev-architecture-design|should we use a monolith or microservices architecture"
  "softwaredev-environment-config|the database connection string needs updating"
)

# --- Run tests ---
bm25_tp=0 bm25_fp=0 bm25_tn=0 bm25_fn=0
ncd_tp=0 ncd_fp=0 ncd_tn=0 ncd_fn=0
total=0

echo -e "${BOLD}--- Scoring each prompt against all semantic ways ---${NC}"
echo ""

for test_case in "${TEST_CASES[@]}"; do
  expected="${test_case%%|*}"
  prompt="${test_case#*|}"
  total=$((total + 1))

  # Score against all ways with BM25
  bm25_matches=()
  bm25_scores=""
  for way_id in "${!WAY_DESC[@]}"; do
    score=$("$BM25_BINARY" pair \
      --description "${WAY_DESC[$way_id]}" \
      --vocabulary "${WAY_VOCAB[$way_id]}" \
      --query "$prompt" \
      --threshold 0.0 2>&1 | grep -oP 'score=\K[0-9.]+')
    if (( $(echo "$score > 0" | bc -l 2>/dev/null || echo 0) )); then
      bm25_scores="$bm25_scores $way_id=$score"
      # Check against per-way threshold from way.md
      thresh="${WAY_THRESH[$way_id]}"
      if (( $(echo "$score >= $thresh" | bc -l 2>/dev/null || echo 0) )); then
        bm25_matches+=("$way_id")
      fi
    fi
  done

  # Score against all ways with NCD (uses fixed NCD threshold, not BM25 threshold)
  ncd_matches=()
  for way_id in "${!WAY_DESC[@]}"; do
    if bash "$NCD_SCRIPT" "$prompt" "${WAY_DESC[$way_id]}" "${WAY_VOCAB[$way_id]}" "0.55" 2>/dev/null; then
      ncd_matches+=("$way_id")
    fi
  done

  # Evaluate BM25
  bm25_ok=false
  if [[ "$expected" == "NONE" ]]; then
    if [[ ${#bm25_matches[@]} -eq 0 ]]; then
      bm25_tn=$((bm25_tn + 1)); bm25_ok=true
    else
      bm25_fp=$((bm25_fp + 1))
    fi
  else
    found=false
    for m in "${bm25_matches[@]}"; do
      [[ "$m" == "$expected" ]] && found=true
    done
    if [[ "$found" == true ]]; then
      bm25_tp=$((bm25_tp + 1)); bm25_ok=true
    else
      bm25_fn=$((bm25_fn + 1))
    fi
  fi

  # Evaluate NCD
  ncd_ok=false
  if [[ "$expected" == "NONE" ]]; then
    if [[ ${#ncd_matches[@]} -eq 0 ]]; then
      ncd_tn=$((ncd_tn + 1)); ncd_ok=true
    else
      ncd_fp=$((ncd_fp + 1))
    fi
  else
    found=false
    for m in "${ncd_matches[@]}"; do
      [[ "$m" == "$expected" ]] && found=true
    done
    if [[ "$found" == true ]]; then
      ncd_tp=$((ncd_tp + 1)); ncd_ok=true
    else
      ncd_fn=$((ncd_fn + 1))
    fi
  fi

  # Output
  printf "%-3d " "$total"

  if [[ "$ncd_ok" == true ]]; then
    printf "${GREEN}NCD:OK  ${NC} "
  else
    printf "${RED}NCD:FAIL${NC} "
  fi

  if [[ "$bm25_ok" == true ]]; then
    printf "${GREEN}BM25:OK  ${NC} "
  else
    printf "${RED}BM25:FAIL${NC} "
  fi

  if [[ "$expected" == "NONE" ]]; then
    printf "expect=NONE "
  else
    printf "expect=%-28s " "$(echo "$expected" | sed 's/softwaredev-//')"
  fi

  # Show what matched
  if [[ ${#bm25_matches[@]} -gt 0 ]]; then
    printf "got=[%s] " "$(IFS=,; echo "${bm25_matches[*]}" | sed 's/softwaredev-//g')"
  fi

  printf "%s" "$prompt"

  # Show scores for misses
  if [[ "$bm25_ok" == false ]] && [[ -n "$bm25_scores" ]]; then
    printf " ${CYAN}(scores:%s)${NC}" "$bm25_scores"
  fi

  echo ""
done

# --- Summary ---
echo ""
echo -e "${BOLD}=== Integration Results ($total tests) ===${NC}"
echo ""

ncd_correct=$((ncd_tp + ncd_tn))
bm25_correct=$((bm25_tp + bm25_tn))

echo "NCD (gzip):  TP=$ncd_tp FP=$ncd_fp TN=$ncd_tn FN=$ncd_fn  accuracy=$ncd_correct/$total"
echo "BM25:        TP=$bm25_tp FP=$bm25_fp TN=$bm25_tn FN=$bm25_fn  accuracy=$bm25_correct/$total"
echo ""

if [[ $bm25_correct -gt $ncd_correct ]]; then
  echo -e "${GREEN}BM25 wins: +$((bm25_correct - ncd_correct)) correct${NC}"
elif [[ $ncd_correct -gt $bm25_correct ]]; then
  echo -e "${RED}NCD wins: +$((ncd_correct - bm25_correct)) correct${NC}"
else
  echo "Tie"
fi
