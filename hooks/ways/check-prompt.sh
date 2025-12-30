#!/bin/bash
# Check user prompts for keywords from way frontmatter
#
# TRIGGER FLOW:
# ┌──────────────────┐     ┌─────────────────┐     ┌──────────────┐
# │ UserPromptSubmit │────▶│ scan_ways()     │────▶│ show-way.sh  │
# │ (hook event)     │     │ for each way.md │     │ (idempotent) │
# └──────────────────┘     │  if keywords    │     └──────────────┘
#                          │  match prompt   │
#                          └─────────────────┘
#
# Ways are nested: domain/wayname/way.md (e.g., softwaredev/github/way.md)
# Multiple ways can match a single prompt - each way's show-way.sh
# is called, but markers prevent duplicate output within session.
# Project-local ways are scanned first (and take precedence).

INPUT=$(cat)
PROMPT=$(echo "$INPUT" | jq -r '.prompt // empty' | tr '[:upper:]' '[:lower:]')
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // empty')
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(echo "$INPUT" | jq -r '.cwd // empty')}"

# Scan ways in a directory for keyword matches (recursive)
scan_ways() {
  local dir="$1"
  [[ ! -d "$dir" ]] && return

  # Find all way.md files recursively
  while IFS= read -r -d '' wayfile; do
    # Extract way path relative to ways dir (e.g., "softwaredev/github")
    waypath="${wayfile#$dir/}"
    waypath="${waypath%/way.md}"

    # Extract keywords from frontmatter
    keywords=$(awk '/^---$/{p=!p; next} p && /^keywords:/' "$wayfile" | sed 's/^keywords: *//')
    [[ -z "$keywords" ]] && continue

    # Check if prompt matches keywords
    if [[ "$PROMPT" =~ $keywords ]]; then
      ~/.claude/hooks/ways/show-way.sh "$waypath" "$SESSION_ID"
    fi
  done < <(find "$dir" -name "way.md" -print0 2>/dev/null)
}

# Scan project-local first, then global
scan_ways "$PROJECT_DIR/.claude/ways"
scan_ways "${HOME}/.claude/hooks/ways"
