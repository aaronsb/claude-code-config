#!/bin/bash
# Show core.md with dynamic table from macro
# Runs macro.sh first, then outputs static content from core.md
#
# Creates a core marker so check-state.sh can detect if core guidance
# was lost (e.g., plan mode context clear) and re-inject it.

INPUT=$(cat)
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // empty' 2>/dev/null)
WAYS_DIR="${HOME}/.claude/hooks/ways"

# Run macro to generate dynamic table
"${WAYS_DIR}/macro.sh"

# Output static content (skip frontmatter)
awk 'BEGIN{fm=0} /^---$/{fm++; next} fm!=1' "${WAYS_DIR}/core.md"

# Append ways version (short commit hash from the config repo)
WAYS_VERSION=$(git -C "${HOME}/.claude" rev-parse --short HEAD 2>/dev/null || echo "unknown")
echo ""
echo "---"
echo "_Ways version: ${WAYS_VERSION}_"

# Mark core as injected for this session
if [[ -n "$SESSION_ID" ]]; then
  date +%s > "/tmp/.claude-core-${SESSION_ID}"
fi
