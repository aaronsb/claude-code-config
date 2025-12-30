#!/bin/bash
# PostToolUse: Check bash commands against way frontmatter
#
# TRIGGER FLOW:
# ┌──────────────────┐     ┌─────────────────┐     ┌──────────────┐
# │ PostToolUse:Bash │────▶│ scan_ways()     │────▶│ show-way.sh  │
# │ (hook event)     │     │ for each way.md │     │ (idempotent) │
# └──────────────────┘     │  if commands OR │     └──────────────┘
#                          │  keywords match │
#                          └─────────────────┘
#
# Ways are nested: domain/wayname/way.md (e.g., softwaredev/github/way.md)
# Multiple ways can match a single command - CONTEXT accumulates
# all matching way outputs. Markers prevent duplicate content.
# Output is returned as additionalContext JSON for Claude to see.

INPUT=$(cat)
CMD=$(echo "$INPUT" | jq -r '.tool_input.command // empty')
DESC=$(echo "$INPUT" | jq -r '.tool_input.description // empty' | tr '[:upper:]' '[:lower:]')
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // empty')
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(echo "$INPUT" | jq -r '.cwd // empty')}"

CONTEXT=""

# Scan ways in a directory (recursive)
scan_ways() {
  local dir="$1"
  [[ ! -d "$dir" ]] && return

  # Find all way.md files recursively
  while IFS= read -r -d '' wayfile; do
    # Extract way path relative to ways dir (e.g., "softwaredev/github")
    waypath="${wayfile#$dir/}"
    waypath="${waypath%/way.md}"

    # Extract frontmatter fields
    commands=$(awk '/^---$/{p=!p; next} p && /^commands:/' "$wayfile" | sed 's/^commands: *//')
    keywords=$(awk '/^---$/{p=!p; next} p && /^keywords:/' "$wayfile" | sed 's/^keywords: *//')

    # Check command patterns
    if [[ -n "$commands" && "$CMD" =~ $commands ]]; then
      CONTEXT+=$(~/.claude/hooks/ways/show-way.sh "$waypath" "$SESSION_ID")
    fi

    # Check description against keywords
    if [[ -n "$DESC" && -n "$keywords" && "$DESC" =~ $keywords ]]; then
      CONTEXT+=$(~/.claude/hooks/ways/show-way.sh "$waypath" "$SESSION_ID")
    fi
  done < <(find "$dir" -name "way.md" -print0 2>/dev/null)
}

# Scan project-local first, then global
scan_ways "$PROJECT_DIR/.claude/ways"
scan_ways "${HOME}/.claude/hooks/ways"

# Output JSON with additionalContext if we have any
if [[ -n "$CONTEXT" ]]; then
  jq -n --arg ctx "$CONTEXT" '{
    "hookSpecificOutput": {
      "hookEventName": "PostToolUse",
      "additionalContext": $ctx
    }
  }'
fi
