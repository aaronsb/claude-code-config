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
rm -f /tmp/.claude-tasks-active-* 2>/dev/null

# Debug: uncomment to log
# echo "Cleared markers for session ${SESSION_ID:-unknown}" >> /tmp/claude-ways-debug.log
