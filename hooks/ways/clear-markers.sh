#!/bin/bash
# Clear way markers for fresh session
# Called on SessionStart and after compaction
#
# Reads session_id from stdin JSON input (Claude Code hook format)
# Clears ALL markers so guidance can trigger fresh in the new session

INPUT=$(cat)
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // empty' 2>/dev/null)

# Clear all markers (session IDs change on restart anyway)
rm -f /tmp/.claude-way-* 2>/dev/null
rm -f /tmp/.claude-core-* 2>/dev/null
rm -f /tmp/.claude-tasks-active-* 2>/dev/null
rm -rf /tmp/.claude-subagent-stash-* 2>/dev/null

# Log session event
"${HOME}/.claude/hooks/ways/log-event.sh" \
  event=session_start project="${CLAUDE_PROJECT_DIR:-$PWD}" session="${SESSION_ID:-unknown}"
