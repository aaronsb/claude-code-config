#!/bin/bash
# Check user prompts for keywords from way frontmatter
#
# TRIGGER FLOW:
# ┌──────────────────┐     ┌─────────────────┐     ┌──────────────┐
# │ UserPromptSubmit │────▶│ scan_ways()     │────▶│ show-way.sh  │
# │ (hook event)     │     │ for each way.md │     │ (idempotent) │
# └──────────────────┘     │  if pattern OR  │     └──────────────┘
#                          │  semantic match │
#                          └─────────────────┘
#
# Ways are nested: domain/wayname/way.md (e.g., softwaredev/delivery/github/way.md)
# Matching is ADDITIVE: pattern (regex/keyword) and semantic are OR'd.
# Semantic matching degrades: BM25 binary → gzip NCD → skip.
# Project-local ways are scanned first (and take precedence).

INPUT=$(cat)
PROMPT=$(echo "$INPUT" | jq -r '.prompt // empty' | tr '[:upper:]' '[:lower:]')
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // empty')
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(echo "$INPUT" | jq -r '.cwd // empty')}"
WAYS_DIR="${HOME}/.claude/hooks/ways"

# Shared matching logic (engine detection + additive match function)
source "${WAYS_DIR}/match-way.sh"
detect_semantic_engine

# Detect execution scope (agent vs teammate)
source "${WAYS_DIR}/detect-scope.sh"
CURRENT_SCOPE=$(detect_scope "$SESSION_ID")

# Read response topics from Stop hook (if available)
RESPONSE_STATE="/tmp/claude-response-topics-${SESSION_ID}"
RESPONSE_TOPICS=""
if [[ -f "$RESPONSE_STATE" ]]; then
  RESPONSE_TOPICS=$(jq -r '.topics // empty' "$RESPONSE_STATE" 2>/dev/null)
fi

# Combined context: user prompt + Claude's recent topics
COMBINED_CONTEXT="$PROMPT $RESPONSE_TOPICS"

# Scan ways in a directory for matches (recursive)
scan_ways() {
  local dir="$1"
  [[ ! -d "$dir" ]] && return

  # Find all way.md files recursively
  while IFS= read -r -d '' wayfile; do
    # Extract way path relative to ways dir (e.g., "softwaredev/delivery/github")
    waypath="${wayfile#$dir/}"
    waypath="${waypath%/way.md}"

    # Extract frontmatter fields
    frontmatter=$(awk 'NR==1 && /^---$/{p=1; next} p && /^---$/{exit} p{print}' "$wayfile")
    get_field() { echo "$frontmatter" | awk "/^$1:/"'{gsub(/^'"$1"': */, ""); print; exit}'; }

    # Core fields
    pattern=$(get_field "pattern")            # regex pattern
    description=$(get_field "description")    # reference text for semantic matching
    vocabulary=$(get_field "vocabulary")      # domain words for semantic matching
    threshold=$(get_field "threshold")        # score threshold for semantic matching

    # Check scope -- skip if current scope not in way's scope list
    scope_raw=$(get_field "scope")
    scope_raw="${scope_raw:-agent}"
    scope_matches "$scope_raw" "$CURRENT_SCOPE" || continue

    # Additive matching: pattern OR semantic (either channel can fire)
    matched=false
    if match_way_prompt "$PROMPT" "$pattern" "$description" "$vocabulary" "$threshold"; then
      matched=true
    fi

    if $matched; then
      ~/.claude/hooks/ways/show-way.sh "$waypath" "$SESSION_ID" "prompt"
    fi
  done < <(find "$dir" -name "way.md" -print0 2>/dev/null)
}

# Scan project-local first, then global
scan_ways "$PROJECT_DIR/.claude/ways"
scan_ways "${HOME}/.claude/hooks/ways"
