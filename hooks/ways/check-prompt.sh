#!/bin/bash
# Check user prompts for keywords from way frontmatter
#
# TRIGGER FLOW:
# ┌──────────────────┐     ┌─────────────────┐     ┌──────────────┐
# │ UserPromptSubmit │────▶│ scan_ways()     │────▶│ show-way.sh  │
# │ (hook event)     │     │ for each way.md │     │ (idempotent) │
# └──────────────────┘     │  if keywords OR │     └──────────────┘
#                          │  semantic match │
#                          └─────────────────┘
#
# Ways are nested: domain/wayname/way.md (e.g., softwaredev/github/way.md)
# Ways can use regex (keywords:) or semantic matching (semantic: true)
# Semantic matching uses keyword counting + gzip NCD for better accuracy.
# Project-local ways are scanned first (and take precedence).

INPUT=$(cat)
PROMPT=$(echo "$INPUT" | jq -r '.prompt // empty' | tr '[:upper:]' '[:lower:]')
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // empty')
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(echo "$INPUT" | jq -r '.cwd // empty')}"
WAYS_DIR="${HOME}/.claude/hooks/ways"

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
    # Extract way path relative to ways dir (e.g., "softwaredev/github")
    waypath="${wayfile#$dir/}"
    waypath="${waypath%/way.md}"

    # Extract frontmatter fields
    frontmatter=$(awk 'NR==1 && /^---$/{p=1; next} p && /^---$/{exit} p{print}' "$wayfile")
    get_field() { echo "$frontmatter" | awk "/^$1:/"'{gsub(/^'"$1"': */, ""); print; exit}'; }

    # Core fields
    match_mode=$(get_field "match")           # "regex" or "semantic"
    pattern=$(get_field "pattern")            # regex pattern (for match: regex)
    description=$(get_field "description")    # reference text (for match: semantic)
    vocabulary=$(get_field "vocabulary")      # domain words (for match: semantic)
    threshold=$(get_field "threshold")        # NCD threshold (for match: semantic)

    # Check scope -- skip if not agent-scoped
    scope_raw=$(get_field "scope")
    scope_raw="${scope_raw:-agent}"
    echo "$scope_raw" | grep -qw "agent" || continue

    # Check for match based on mode
    matched=false

    if [[ "$match_mode" == "model" && -n "$description" ]]; then
      # Model-based classification: uses Haiku for accurate decisions
      if "${WAYS_DIR}/model-match.sh" "$PROMPT" "$description" 2>/dev/null; then
        matched=true
      fi
    elif [[ "$match_mode" == "semantic" && -n "$description" && -n "$vocabulary" ]]; then
      # Semantic matching: gzip NCD + keyword counting
      if "${WAYS_DIR}/semantic-match.sh" "$PROMPT" "$description" "$vocabulary" "$threshold" 2>/dev/null; then
        matched=true
      fi
    elif [[ -n "$pattern" && "$PROMPT" =~ $pattern ]]; then
      # Regex matching (default)
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
