#!/bin/bash
# PreToolUse:Task - Stash subagent-scoped ways for SubagentStart
#
# TRIGGER FLOW:
# ┌─────────────────┐     ┌──────────────────┐     ┌───────────────┐
# │ PreToolUse:Task │────▶│ scan_ways()      │────▶│ write stash   │
# │ (hook event)    │     │ scope: subagent  │     │ for injection │
# └─────────────────┘     └──────────────────┘     └───────────────┘
#
# Phase 1 of two-phase subagent injection:
# 1. PreToolUse:Task scans Task prompt against ways with subagent scope
# 2. SubagentStart (inject-subagent.sh) reads stash and emits content
#
# Stash: {SESSIONS_ROOT}/{session_id}/subagent-stash/{timestamp}.json

INPUT=$(cat)
TASK_PROMPT=$(echo "$INPUT" | jq -r '.tool_input.prompt // empty' | tr '[:upper:]' '[:lower:]')
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // empty')
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(echo "$INPUT" | jq -r '.cwd // empty')}"
WAYS_DIR="${HOME}/.claude/hooks/ways"

# Ways binary for matching
WAYS_BIN="${HOME}/.claude/bin/ways"

# File discovery (inline)
find_way_files() {
  local dir="$1"
  find -L "$dir" -name "*.md" ! -name "*.check.md" -print0 2>/dev/null | while IFS= read -r -d '' f; do
    head -1 "$f" 2>/dev/null | grep -q '^---$' && printf '%s\0' "$f"
  done
}
way_id_from_path() {
  local filepath="$1" basedir="$2"
  local rel="${filepath#$basedir/}"
  echo "${rel%/*}"
}

# BM25 batch cache (one call scores all)
BM25_CACHE=""
_get_bm25_cache() {
  if [[ -z "$BM25_CACHE" && -x "$WAYS_BIN" ]]; then
    BM25_CACHE=$("$WAYS_BIN" match "$TASK_PROMPT" 2>/dev/null || true)
  fi
}
# Simple prompt matching: pattern OR BM25
match_way_prompt() {
  local prompt="$1" pattern="$2" desc="$3" vocab="$4" threshold="$5" way_id="$6"
  MATCH_CHANNEL=""
  if [[ -n "$pattern" && "$prompt" =~ $pattern ]]; then
    MATCH_CHANNEL="keyword"; return 0
  fi
  _get_bm25_cache
  if [[ -n "$BM25_CACHE" ]] && echo "$BM25_CACHE" | grep -qF "${way_id}	"; then
    MATCH_CHANNEL="semantic:bm25"; return 0
  fi
  return 1
}

# Detect teammate spawn (Task tool with team_name parameter)
TEAM_NAME=$(echo "$INPUT" | jq -r '.tool_input.team_name // empty')
IS_TEAMMATE=false
[[ -n "$TEAM_NAME" ]] && IS_TEAMMATE=true

[[ -z "$TASK_PROMPT" ]] && exit 0
[[ -z "$SESSION_ID" ]] && exit 0

source "$(dirname "$0")/sessions-root.sh"
STASH_DIR="${SESSIONS_ROOT}/${SESSION_ID}/subagent-stash"
mkdir -p "$STASH_DIR"

MATCHED_WAYS=()

scan_ways_for_subagent() {
  local dir="$1"
  [[ ! -d "$dir" ]] && return

  while IFS= read -r -d '' wayfile; do
    waypath="${wayfile#$dir/}"
    waypath="$(way_id_from_path "$wayfile" "$dir")"

    # Extract frontmatter
    frontmatter=$(awk 'NR==1 && /^---$/{p=1; next} p && /^---$/{exit} p{print}' "$wayfile")
    get_field() { echo "$frontmatter" | awk "/^$1:/"'{gsub(/^'"$1"': */, ""); print; exit}'; }

    # Must have subagent or teammate scope
    local scope_raw=$(get_field "scope")
    scope_raw="${scope_raw:-agent}"
    if $IS_TEAMMATE; then
      # Teammates match ways with scope: teammate OR subagent
      echo "$scope_raw" | grep -qwE "subagent|teammate" || continue
    else
      echo "$scope_raw" | grep -qw "subagent" || continue
    fi

    # Skip state-triggered ways (they don't match on content)
    local trigger=$(get_field "trigger")
    [[ -n "$trigger" ]] && continue

    # Additive matching: pattern OR semantic (shared with check-prompt.sh)
    local pattern=$(get_field "pattern")
    local description=$(get_field "description")
    local vocabulary=$(get_field "vocabulary")
    local threshold=$(get_field "threshold")

    if match_way_prompt "$TASK_PROMPT" "$pattern" "$description" "$vocabulary" "$threshold" "$waypath"; then
      MATCHED_WAYS+=("$waypath|${MATCH_CHANNEL:-prompt}")
    fi
  done < <(find_way_files "$dir")
}

# Scan project-local first, then global
scan_ways_for_subagent "$PROJECT_DIR/.claude/ways"
scan_ways_for_subagent "${WAYS_DIR}"

# Write stash if any ways matched
if [[ ${#MATCHED_WAYS[@]} -gt 0 ]]; then
  TIMESTAMP=$(date +%s%N)
  STASH_FILE="${STASH_DIR}/${TIMESTAMP}.json"

  # Each entry is "waypath|channel" — split into parallel arrays
  WAYS_JSON=$(printf '%s\n' "${MATCHED_WAYS[@]}" | cut -d'|' -f1 | jq -R . | jq -s .)
  CHANNELS_JSON=$(printf '%s\n' "${MATCHED_WAYS[@]}" | cut -d'|' -f2 | jq -R . | jq -s .)
  jq -n --argjson ways "$WAYS_JSON" --argjson channels "$CHANNELS_JSON" \
    --argjson teammate "$IS_TEAMMATE" --arg team "$TEAM_NAME" \
    '{ways: $ways, channels: $channels, is_teammate: $teammate, team_name: $team}' > "$STASH_FILE"
fi

# Never block Task creation
exit 0
