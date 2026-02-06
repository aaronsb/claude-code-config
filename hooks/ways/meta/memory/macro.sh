#!/usr/bin/env bash
# Check MEMORY.md state and inject context budget for the current project

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-${PROJECT_DIR:-.}}"

# Context budget
SCRIPT="${HOME}/.claude/scripts/context-usage.sh"
if [[ -x "$SCRIPT" ]]; then
  JSON=$("$SCRIPT" --json "$PROJECT_DIR" 2>/dev/null)
  if [[ -n "$JSON" ]]; then
    REMAINING=$(echo "$JSON" | jq -r '.tokens_remaining')
    PCT=$(echo "$JSON" | jq -r '.pct_remaining')
    echo "**Context budget: ~${REMAINING} tokens remaining (${PCT}% of window).** After compaction, session details are summarized and specifics are lost. Anything not saved to MEMORY.md or captured as a way will not carry forward."
    echo ""
  fi
fi

# MEMORY.md state
NORMALIZED=$(echo "$PROJECT_DIR" | sed 's|[/.]|-|g')
MEMORY_DIR="$HOME/.claude/projects/${NORMALIZED}/memory"
MEMORY_FILE="$MEMORY_DIR/MEMORY.md"

if [ ! -f "$MEMORY_FILE" ]; then
    echo "**MEMORY.md does not exist yet for this project.** This is a fresh start — create it now."
elif [ ! -s "$MEMORY_FILE" ]; then
    echo "**MEMORY.md exists but is empty.** Seed it with learnings from this session."
else
    LINES=$(wc -l < "$MEMORY_FILE")
    echo "**MEMORY.md has ${LINES} lines.** Review and update with new insights from this session."
fi
