#!/bin/bash
# SubagentStart - Inject subagent-scoped ways from stash
#
# TRIGGER FLOW:
# ┌────────────────┐     ┌──────────────────┐     ┌──────────────────┐
# │ SubagentStart  │────▶│ read stash file  │────▶│ emit way content │
# │ (hook event)   │     │ (oldest first)   │     │ (bypass markers) │
# └────────────────┘     └──────────────────┘     └──────────────────┘
#
# Phase 2 of two-phase subagent injection:
# 1. PreToolUse:Task (check-task-pre.sh) stashed matched way paths
# 2. This script reads the stash, emits way content as additionalContext
#
# Way content is emitted WITHOUT marker checks - subagents get fresh
# context regardless of what the parent already triggered.

INPUT=$(cat)
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // empty')
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(echo "$INPUT" | jq -r '.cwd // empty')}"

[[ -z "$SESSION_ID" ]] && exit 0

STASH_DIR="/tmp/.claude-subagent-stash-${SESSION_ID}"
[[ ! -d "$STASH_DIR" ]] && exit 0

# Claim the oldest stash file (FIFO for parallel Task invocations)
OLDEST=$(ls "$STASH_DIR"/*.json 2>/dev/null | sort | head -1)
[[ -z "$OLDEST" ]] && exit 0

# Atomic claim: rename so no other SubagentStart grabs it
CLAIMED="${OLDEST}.claimed"
mv "$OLDEST" "$CLAIMED" 2>/dev/null || exit 0

# Read matched way paths
WAYS=$(jq -r '.ways[]' "$CLAIMED" 2>/dev/null)
rm -f "$CLAIMED"

[[ -z "$WAYS" ]] && exit 0

# Emit way content for each matched way (bypassing markers)
CONTEXT=""

while IFS= read -r waypath; do
  [[ -z "$waypath" ]] && continue

  # Resolve way file (project-local > global)
  WAY_FILE=""
  WAY_DIR=""
  if [[ -f "$PROJECT_DIR/.claude/ways/${waypath}/way.md" ]]; then
    WAY_FILE="$PROJECT_DIR/.claude/ways/${waypath}/way.md"
    WAY_DIR="$PROJECT_DIR/.claude/ways/${waypath}"
  elif [[ -f "${HOME}/.claude/hooks/ways/${waypath}/way.md" ]]; then
    WAY_FILE="${HOME}/.claude/hooks/ways/${waypath}/way.md"
    WAY_DIR="${HOME}/.claude/hooks/ways/${waypath}"
  fi
  [[ -z "$WAY_FILE" ]] && continue

  # Check domain disabled
  DOMAIN="${waypath%%/*}"
  WAYS_CONFIG="${HOME}/.claude/ways.json"
  if [[ -f "$WAYS_CONFIG" ]]; then
    if jq -e --arg d "$DOMAIN" '.disabled | index($d) != null' "$WAYS_CONFIG" >/dev/null 2>&1; then
      continue
    fi
  fi

  # Extract macro position
  MACRO_POS=$(awk '/^---$/{p=!p; next} p && /^macro:/{gsub(/^macro: */, ""); print; exit}' "$WAY_FILE")
  MACRO_FILE="${WAY_DIR}/macro.sh"
  MACRO_OUT=""

  if [[ -n "$MACRO_POS" && -x "$MACRO_FILE" ]]; then
    # Project-local macros need trust check
    if [[ "$WAY_FILE" == "${HOME}/.claude/hooks/ways/"* ]]; then
      MACRO_OUT=$("$MACRO_FILE" 2>/dev/null)
    else
      # Check project trust for project-local macros
      trust_file="${HOME}/.claude/trusted-project-macros"
      if [[ -f "$trust_file" ]] && grep -qxF "$PROJECT_DIR" "$trust_file"; then
        MACRO_OUT=$("$MACRO_FILE" 2>/dev/null)
      fi
    fi
  fi

  # Build way output
  WAY_CONTENT=""
  if [[ "$MACRO_POS" == "prepend" && -n "$MACRO_OUT" ]]; then
    WAY_CONTENT+="$MACRO_OUT"$'\n'
  fi

  WAY_CONTENT+=$(awk 'BEGIN{fm=0} /^---$/{fm++; next} fm!=1' "$WAY_FILE")

  if [[ "$MACRO_POS" == "append" && -n "$MACRO_OUT" ]]; then
    WAY_CONTENT+=$'\n'"$MACRO_OUT"
  fi

  if [[ -n "$WAY_CONTENT" ]]; then
    CONTEXT+="$WAY_CONTENT"$'\n\n'
    "${HOME}/.claude/hooks/ways/log-event.sh" \
      event=way_fired way="$waypath" domain="$DOMAIN" \
      trigger="subagent" scope=subagent project="$PROJECT_DIR" session="$SESSION_ID"
  fi
done <<< "$WAYS"

# Output for SubagentStart
if [[ -n "$CONTEXT" ]]; then
  echo "${CONTEXT%$'\n\n'}"
fi
