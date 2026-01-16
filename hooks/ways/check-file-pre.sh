#!/bin/bash
# PreToolUse: Check file operations against way frontmatter
#
# TRIGGER FLOW:
# ┌───────────────────────┐     ┌─────────────────┐     ┌──────────────┐
# │ PreToolUse:Edit/Write │────▶│ scan_ways()     │────▶│ show-way.sh  │
# │ (hook event)          │     │ for each way.md │     │ (idempotent) │
# └───────────────────────┘     │  if files match │     └──────────────┘
#                               └─────────────────┘
#
# Ways are nested: domain/wayname/way.md (e.g., softwaredev/github/way.md)
# Multiple ways can match a single file path - CONTEXT accumulates
# all matching way outputs. Markers prevent duplicate content.
# Output is returned as additionalContext JSON for Claude to see.

INPUT=$(cat)
FP=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')
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

    # Extract files pattern from frontmatter
    files=$(awk '/^---$/{p=!p; next} p && /^files:/' "$wayfile" | sed 's/^files: *//')

    # Check file path against pattern
    if [[ -n "$files" && "$FP" =~ $files ]]; then
      CONTEXT+=$(~/.claude/hooks/ways/show-way.sh "$waypath" "$SESSION_ID")
    fi
  done < <(find "$dir" -name "way.md" -print0 2>/dev/null)
}

# Scan project-local first, then global
scan_ways "$PROJECT_DIR/.claude/ways"
scan_ways "${HOME}/.claude/hooks/ways"

# Output JSON - PreToolUse format with decision + additionalContext
if [[ -n "$CONTEXT" ]]; then
  jq -n --arg ctx "$CONTEXT" '{
    "decision": "approve",
    "additionalContext": $ctx
  }'
fi
