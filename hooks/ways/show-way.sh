#!/bin/bash
# Show a "way" once per session (strips frontmatter, runs macro if configured)
# Usage: show-way.sh <way-path> <session-id>
#
# Way paths can be nested: "softwaredev/delivery/github", "awsops/iam", etc.
# Looks for: {way-path}/way.md and optionally {way-path}/macro.sh
#
# STATE MACHINE (ADR-104: token-gated re-disclosure):
# ┌─────────────────────────────┬────────────────────────────────────┐
# │ Marker State                │ Action                             │
# ├─────────────────────────────┼────────────────────────────────────┤
# │ not exists                  │ output way, create marker          │
# │ exists, token dist < thresh │ no-op (way still warm)             │
# │ exists, token dist >= thresh│ re-disclose, update marker         │
# └─────────────────────────────┴────────────────────────────────────┘
#
# MACRO SUPPORT:
# If frontmatter contains `macro: prepend` or `macro: append`,
# runs {way-path}/macro.sh and combines output with static content.
#
# Marker: /tmp/.claude-way-{wayname-sanitized}-{session_id}

WAY="$1"
SESSION_ID="$2"
TRIGGER="${3:-unknown}"
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$PWD}"

# Detect execution scope and team
source "${HOME}/.claude/hooks/ways/detect-scope.sh"
SCOPE=$(detect_scope "$SESSION_ID")
TEAM=$(detect_team "$SESSION_ID")

[[ -z "$WAY" ]] && exit 1

# Check if domain is disabled via ~/.claude/ways.json
# Example: { "disabled": ["itops", "softwaredev"] }
WAYS_CONFIG="${HOME}/.claude/ways.json"
DOMAIN="${WAY%%/*}"  # First path component (e.g., "softwaredev" from "softwaredev/delivery/github")
if [[ -f "$WAYS_CONFIG" ]]; then
  if jq -e --arg d "$DOMAIN" '.disabled | index($d) != null' "$WAYS_CONFIG" >/dev/null 2>&1; then
    exit 0
  fi
fi

# Sanitize way path for marker filename (replace / with -)
WAY_MARKER_NAME=$(echo "$WAY" | tr '/' '-')

# Project-local takes precedence over global
# SECURITY: Project-local macros only run if project is in trusted list
WAY_DIR=""
IS_PROJECT_LOCAL=false
if [[ -f "$PROJECT_DIR/.claude/ways/${WAY}/way.md" ]]; then
  WAY_FILE="$PROJECT_DIR/.claude/ways/${WAY}/way.md"
  WAY_DIR="$PROJECT_DIR/.claude/ways/${WAY}"
  IS_PROJECT_LOCAL=true
elif [[ -f "${HOME}/.claude/hooks/ways/${WAY}/way.md" ]]; then
  WAY_FILE="${HOME}/.claude/hooks/ways/${WAY}/way.md"
  WAY_DIR="${HOME}/.claude/hooks/ways/${WAY}"
else
  exit 0
fi

# Check if project is trusted for macro execution
# Add trusted project paths (one per line) to ~/.claude/trusted-project-macros
is_project_trusted() {
  local trust_file="${HOME}/.claude/trusted-project-macros"
  [[ -f "$trust_file" ]] && grep -qxF "$PROJECT_DIR" "$trust_file"
}

# Marker: scoped to session_id
MARKER="/tmp/.claude-way-${WAY_MARKER_NAME}-${SESSION_ID:-$(date +%Y%m%d)}"

# Token-gated re-disclosure (ADR-104)
source "${HOME}/.claude/hooks/ways/token-position.sh"
IS_REDISCLOSURE=false

if [[ -f "$MARKER" ]]; then
  # Marker exists — check if token distance exceeds re-disclosure threshold
  if token_distance_exceeded "$WAY_MARKER_NAME" "$SESSION_ID"; then
    IS_REDISCLOSURE=true
  else
    exit 0  # Way is still warm, no-op
  fi
fi

# First disclosure or re-disclosure — output the way content

# Extract macro field from frontmatter (prepend or append)
MACRO_POS=$(awk '/^---$/{p=!p; next} p && /^macro:/{gsub(/^macro: */, ""); print; exit}' "$WAY_FILE")

# Check for macro script (same directory as way file)
MACRO_FILE="${WAY_DIR}/macro.sh"
MACRO_OUT=""

if [[ -n "$MACRO_POS" && -x "$MACRO_FILE" ]]; then
  # SECURITY: Skip project-local macros unless project is explicitly trusted
  if $IS_PROJECT_LOCAL && ! is_project_trusted; then
    echo "**Note**: Project-local macro skipped (add $PROJECT_DIR to ~/.claude/trusted-project-macros to enable)"
  else
    # Run macro, capture output
    MACRO_OUT=$("$MACRO_FILE" 2>/dev/null)
  fi
fi

# Output based on macro position
if [[ "$MACRO_POS" == "prepend" && -n "$MACRO_OUT" ]]; then
  echo "$MACRO_OUT"
  echo ""
fi

# Output static content, stripping YAML frontmatter
awk 'BEGIN{fm=0} /^---$/{fm++; next} fm!=1' "$WAY_FILE"

if [[ "$MACRO_POS" == "append" && -n "$MACRO_OUT" ]]; then
  echo ""
  echo "$MACRO_OUT"
fi

# Write marker with token position (replaces boolean touch)
get_token_position "$SESSION_ID"
echo "$TOKEN_POSITION" > "$MARKER"

# Stamp token position for distance tracking
stamp_way_tokens "$WAY_MARKER_NAME" "$SESSION_ID"

# Stamp epoch for check distance tracking
source "${HOME}/.claude/hooks/ways/epoch.sh"
CURRENT_EPOCH=$(cat "/tmp/.claude-epoch-${SESSION_ID}" 2>/dev/null || echo 0)
EPOCH="$CURRENT_EPOCH"  # stamp_way_epoch uses $EPOCH
stamp_way_epoch "$WAY_MARKER_NAME" "$SESSION_ID"

# --- Tree disclosure tracking ---
# When a child way fires, check if its parent has already fired this session.
# Records: depth in tree, parent epoch, epoch distance from parent.
TREE_DEPTH=0
PARENT_MARKER=""
PARENT_EPOCH=""
EPOCH_FROM_PARENT=""

# Walk up the directory tree looking for ancestor markers
# Count all fired ancestors for depth; record nearest for parent info
_tree_path="$WAY"
while [[ "$_tree_path" == */* ]]; do
  _tree_path="${_tree_path%/*}"  # strip last component
  _parent_marker_name=$(echo "$_tree_path" | tr '/' '-')
  _parent_marker="/tmp/.claude-way-${_parent_marker_name}-${SESSION_ID:-$(date +%Y%m%d)}"
  if [[ -f "$_parent_marker" ]]; then
    TREE_DEPTH=$((TREE_DEPTH + 1))
    # Record nearest parent only (first ancestor found)
    if [[ -z "$PARENT_MARKER" ]]; then
      PARENT_MARKER="$_tree_path"
      PARENT_EPOCH=$(cat "/tmp/.claude-way-epoch-${_parent_marker_name}-${SESSION_ID}" 2>/dev/null || echo 0)
      EPOCH_FROM_PARENT=$((CURRENT_EPOCH - PARENT_EPOCH))
    fi
  fi
done

# Count sibling disclosure coverage (how many siblings of this way have fired?)
_parent_dir="${WAY%/*}"
if [[ "$_parent_dir" != "$WAY" ]]; then
  _sibling_total=0
  _sibling_fired=0
  # Check both project-local and global ways for siblings
  for _ways_base in "$PROJECT_DIR/.claude/ways" "${HOME}/.claude/hooks/ways"; do
    [[ -d "${_ways_base}/${_parent_dir}" ]] || continue
    for _sib_dir in "${_ways_base}/${_parent_dir}"/*/; do
      [[ -f "${_sib_dir}way.md" ]] || continue
      _sibling_total=$((_sibling_total + 1))
      _sib_name="${_sib_dir#${_ways_base}/}"
      _sib_name="${_sib_name%/}"
      _sib_marker_name=$(echo "$_sib_name" | tr '/' '-')
      [[ -f "/tmp/.claude-way-${_sib_marker_name}-${SESSION_ID:-$(date +%Y%m%d)}" ]] && _sibling_fired=$((_sibling_fired + 1))
    done
  done
fi

# Write tree metrics file (append, one JSON line per disclosure event)
METRICS_FILE="/tmp/.claude-way-metrics-${SESSION_ID:-$(date +%Y%m%d)}.jsonl"
jq -n -c \
  --arg way "$WAY" \
  --arg parent "${PARENT_MARKER:-none}" \
  --argjson depth "$TREE_DEPTH" \
  --argjson epoch "$CURRENT_EPOCH" \
  --arg parent_epoch "${PARENT_EPOCH:-}" \
  --arg epoch_distance "${EPOCH_FROM_PARENT:-}" \
  --argjson sibling_total "${_sibling_total:-0}" \
  --argjson sibling_fired "${_sibling_fired:-0}" \
  --arg trigger "$TRIGGER" \
  '{way: $way, parent: $parent, depth: $depth, epoch: $epoch,
    parent_epoch: (if $parent_epoch == "" then null else ($parent_epoch | tonumber) end),
    epoch_distance: (if $epoch_distance == "" then null else ($epoch_distance | tonumber) end),
    sibling_total: $sibling_total, sibling_fired: $sibling_fired,
    trigger: $trigger}' \
  >> "$METRICS_FILE" 2>/dev/null || true

# Log event
if $IS_REDISCLOSURE; then
  LOG_ARGS=(event=way_redisclosed way="$WAY" domain="$DOMAIN"
    trigger="$TRIGGER" scope="$SCOPE" project="$PROJECT_DIR" session="$SESSION_ID"
    token_distance="$TOKEN_DISTANCE" token_position="$TOKEN_POSITION"
    redisclose_threshold="$REDISCLOSE_TOKENS")
else
  LOG_ARGS=(event=way_fired way="$WAY" domain="$DOMAIN"
    trigger="$TRIGGER" scope="$SCOPE" project="$PROJECT_DIR" session="$SESSION_ID")
fi
[[ -n "$PARENT_MARKER" ]] && LOG_ARGS+=(parent="$PARENT_MARKER" tree_depth="$TREE_DEPTH" epoch_distance="$EPOCH_FROM_PARENT")
[[ -n "$TEAM" ]] && LOG_ARGS+=(team="$TEAM")
"${HOME}/.claude/hooks/ways/log-event.sh" "${LOG_ARGS[@]}"
