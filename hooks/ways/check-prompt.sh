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
    keywords=$(echo "$frontmatter" | awk '/^keywords:/{gsub(/^keywords: */, ""); print}')
    semantic=$(echo "$frontmatter" | awk '/^semantic:/{gsub(/^semantic: */, ""); print}')
    description=$(echo "$frontmatter" | awk '/^description:/{gsub(/^description: */, ""); print}')
    semantic_keywords=$(echo "$frontmatter" | awk '/^semantic_keywords:/{gsub(/^semantic_keywords: */, ""); print}')
    ncd_threshold=$(echo "$frontmatter" | awk '/^ncd_threshold:/{gsub(/^ncd_threshold: */, ""); print}')

    # Check for match
    matched=false

    # Semantic matching (if enabled)
    if [[ "$semantic" == "true" && -n "$description" && -n "$semantic_keywords" ]]; then
      if "${WAYS_DIR}/semantic-match.sh" "$PROMPT" "$description" "$semantic_keywords" "$ncd_threshold" 2>/dev/null; then
        matched=true
      fi
    # Regex matching (fallback)
    elif [[ -n "$keywords" && "$PROMPT" =~ $keywords ]]; then
      matched=true
    fi

    if $matched; then
      ~/.claude/hooks/ways/show-way.sh "$waypath" "$SESSION_ID"
    fi
  done < <(find "$dir" -name "way.md" -print0 2>/dev/null)
}

# Scan project-local first, then global
scan_ways "$PROJECT_DIR/.claude/ways"
scan_ways "${HOME}/.claude/hooks/ways"
