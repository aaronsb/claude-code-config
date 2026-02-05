#!/bin/bash
# Ways of Working - Usage Statistics
# Reads ~/.claude/stats/events.jsonl and Claude project metadata
#
# Usage: stats.sh [--days N] [--project PATH] [--projects] [--json]
#
# Modes:
#   (default)    Aggregated way firing stats
#   --projects   Per-project dashboard (sessions, memory, way fires)
#   --json       Machine-readable output

STATS_FILE="${HOME}/.claude/stats/events.jsonl"
PROJECTS_DIR="${HOME}/.claude/projects"

# Normalize a filesystem path to Claude project directory name
# /home/aaron/.claude → -home-aaron--claude
normalize_path() {
  echo "$1" | sed 's|[/.]|-|g'
}

# Reverse: project dir name → display path (best effort, lossy)
# Uses sessions-index.json projectPath if available, falls back to shortened dir name
display_name() {
  local dir_name="$1"
  local idx="${PROJECTS_DIR}/${dir_name}/sessions-index.json"
  if [[ -f "$idx" ]]; then
    local pp=$(jq -r '.entries[0].projectPath // empty' "$idx" 2>/dev/null)
    if [[ -n "$pp" ]]; then
      echo "${pp/#$HOME/~}"
      return
    fi
  fi
  # Fallback: strip leading dash, replace - with /
  echo "~/${dir_name#-home-*-}"
}

# Parse args
DAYS=""
PROJECT_FILTER=""
JSON_OUT=false
PROJECTS_MODE=false
while [[ $# -gt 0 ]]; do
  case "$1" in
    --days)     DAYS="$2"; shift 2 ;;
    --project)  PROJECT_FILTER="$2"; shift 2 ;;
    --projects) PROJECTS_MODE=true; shift ;;
    --json)     JSON_OUT=true; shift ;;
    *)          shift ;;
  esac
done

# ============================================================
# Projects mode: per-project dashboard from Claude's project dirs
# ============================================================
if $PROJECTS_MODE; then
  echo "Claude Projects Overview"
  echo "========================"
  echo ""

  # Collect events if available
  EVENTS=""
  [[ -f "$STATS_FILE" ]] && EVENTS=$(cat "$STATS_FILE")

  # Apply time filter
  if [[ -n "$DAYS" && -n "$EVENTS" ]]; then
    CUTOFF=$(date -u -d "${DAYS} days ago" +%Y-%m-%dT%H:%M:%SZ 2>/dev/null \
          || date -u -v-${DAYS}d +%Y-%m-%dT%H:%M:%SZ 2>/dev/null)
    EVENTS=$(echo "$EVENTS" | jq -c "select(.ts >= \"$CUTOFF\")")
  fi

  # Iterate over project directories, sorted by most recently modified
  for dir in $(ls -dt "${PROJECTS_DIR}"/*/); do
    dir_name=$(basename "$dir")
    [[ "$dir_name" == "." || "$dir_name" == ".." ]] && continue

    # Get display name from sessions-index
    name=$(display_name "$dir_name")

    # Session count and last active
    idx="${dir}sessions-index.json"
    sessions="-"
    last_active="-"
    if [[ -f "$idx" ]]; then
      sessions=$(jq '.entries | length' "$idx" 2>/dev/null || echo "-")
      last_active=$(jq -r '[.entries[].modified] | sort | last[:10] // "-"' "$idx" 2>/dev/null || echo "-")
    fi

    # Memory status
    mem_file="${dir}memory/MEMORY.md"
    memory="-"
    if [[ -f "$mem_file" ]] && [[ -s "$mem_file" ]]; then
      memory="$(wc -l < "$mem_file")L"
    elif [[ -f "$mem_file" ]]; then
      memory="empty"
    fi

    # Way fires for this project (match by original project path from events)
    fires=0
    top_ways=""
    if [[ -n "$EVENTS" ]]; then
      # Get the original project path from sessions-index
      orig_path=$(jq -r '.entries[0].projectPath // empty' "$idx" 2>/dev/null)
      if [[ -n "$orig_path" ]]; then
        fires=$(echo "$EVENTS" | jq -r "select(.event == \"way_fired\" and .project == \"$orig_path\") | .way" | wc -l)
        if [[ $fires -gt 0 ]]; then
          top_ways=$(echo "$EVENTS" | jq -r "select(.event == \"way_fired\" and .project == \"$orig_path\") | .way" \
            | sort | uniq -c | sort -rn | head -3 | awk '{printf "%s(%d) ", $2, $1}')
        fi
      fi
    fi

    # Skip inactive projects with no sessions unless showing all
    [[ "$sessions" == "-" || "$sessions" == "0" ]] && [[ $fires -eq 0 ]] && continue

    # Output
    printf "  %-45s" "$name"
    printf "  %3s sessions" "$sessions"
    printf "  │ memory: %-6s" "$memory"
    printf "  │ %3d fires" "$fires"
    echo ""
    if [[ -n "$top_ways" ]]; then
      printf "  %-45s  top: %s\n" "" "$top_ways"
    fi
  done

  echo ""

  # Summary
  total_projects=$(ls -d "${PROJECTS_DIR}"/*/ 2>/dev/null | wc -l)
  with_sessions=0
  for idx in "${PROJECTS_DIR}"/*/sessions-index.json; do
    [[ -f "$idx" ]] && n=$(jq '.entries | length' "$idx" 2>/dev/null) && [[ "$n" -gt 0 ]] && ((with_sessions++))
  done
  with_memory=$(find "${PROJECTS_DIR}" -path "*/memory/MEMORY.md" -size +0c 2>/dev/null | wc -l)

  echo "Total: ${total_projects} projects, ${with_sessions} with sessions, ${with_memory} with memory"
  exit 0
fi

# ============================================================
# Default mode: aggregated way firing stats
# ============================================================

if [[ ! -f "$STATS_FILE" ]]; then
  echo "No events recorded yet. Stats will appear after ways start firing."
  echo "Run with --projects to see Claude project overview."
  exit 0
fi

# Load and filter events
if [[ -n "$DAYS" ]]; then
  CUTOFF=$(date -u -d "${DAYS} days ago" +%Y-%m-%dT%H:%M:%SZ 2>/dev/null \
        || date -u -v-${DAYS}d +%Y-%m-%dT%H:%M:%SZ 2>/dev/null)
  EVENTS=$(jq -c "select(.ts >= \"$CUTOFF\")" "$STATS_FILE")
else
  EVENTS=$(cat "$STATS_FILE")
fi

if [[ -n "$PROJECT_FILTER" ]]; then
  EVENTS=$(echo "$EVENTS" | jq -c "select(.project | contains(\"$PROJECT_FILTER\"))")
fi

# JSON output mode
if $JSON_OUT; then
  echo "$EVENTS" | jq -sc '{
    total_events: length,
    sessions: [.[] | select(.event == "session_start")] | length,
    way_fires: [.[] | select(.event == "way_fired")] | length,
    by_way: ([.[] | select(.event == "way_fired") | .way] | group_by(.) | map({(.[0]): length}) | add // {}),
    by_trigger: ([.[] | select(.event == "way_fired") | .trigger] | group_by(.) | map({(.[0]): length}) | add // {}),
    by_project: ([.[] | select(.event != null) | .project] | group_by(.) | map({(.[0]): length}) | add // {})
  }'
  exit 0
fi

# --- Human-readable output ---

TOTAL=$(echo "$EVENTS" | wc -l)
SESSIONS=$(echo "$EVENTS" | jq -r 'select(.event == "session_start") | .session' | sort -u | wc -l)
FIRES=$(echo "$EVENTS" | jq -r 'select(.event == "way_fired") | .way' | wc -l)

# Date range
FIRST=$(echo "$EVENTS" | head -1 | jq -r '.ts[:10]')
LAST=$(echo "$EVENTS" | tail -1 | jq -r '.ts[:10]')

echo "Ways of Working - Usage Stats"
echo "=============================="
if [[ -n "$DAYS" ]]; then
  echo "Period: last ${DAYS} days"
elif [[ "$FIRST" != "$LAST" ]]; then
  echo "Period: ${FIRST} → ${LAST}"
else
  echo "Date: ${FIRST}"
fi
if [[ -n "$PROJECT_FILTER" ]]; then
  echo "Project: ${PROJECT_FILTER}"
fi
echo ""
echo "Sessions: ${SESSIONS}  |  Way fires: ${FIRES}"
echo ""

# Top ways
echo "Top ways:"
WAY_COUNTS=$(echo "$EVENTS" | jq -r 'select(.event == "way_fired") | .way' | sort | uniq -c | sort -rn | head -10)
if [[ -z "$WAY_COUNTS" ]]; then
  echo "  (none yet)"
else
  MAX=$(echo "$WAY_COUNTS" | head -1 | awk '{print $1}')
  echo "$WAY_COUNTS" | while read count way; do
    bar_len=$((count * 20 / (MAX > 0 ? MAX : 1)))
    bar=$(printf '█%.0s' $(seq 1 $bar_len 2>/dev/null) || echo "█")
    printf "  %-30s %3d  %s\n" "$way" "$count" "$bar"
  done
fi
echo ""

# By trigger
echo "By trigger:"
echo "$EVENTS" | jq -r 'select(.event == "way_fired") | .trigger' | sort | uniq -c | sort -rn | while read count trigger; do
  [[ -z "$trigger" ]] && continue
  pct=$((count * 100 / (FIRES > 0 ? FIRES : 1)))
  printf "  %-10s %3d (%d%%)\n" "$trigger" "$count" "$pct"
done
echo ""

# By project (use display names)
echo "By project:"
echo "$EVENTS" | jq -r 'select(.event == "way_fired") | .project' | sort | uniq -c | sort -rn | head -5 | while read count project; do
  [[ -z "$project" ]] && continue
  display="${project/#$HOME/~}"
  # Try to get project session count
  norm=$(normalize_path "$project")
  idx="${PROJECTS_DIR}/${norm}/sessions-index.json"
  sess=""
  if [[ -f "$idx" ]]; then
    sess=" ($(jq '.entries | length' "$idx" 2>/dev/null) sessions)"
  fi
  printf "  %-40s %3d fires%s\n" "$display" "$count" "$sess"
done
echo ""

# Recent activity
YESTERDAY=$(date -u -d "1 day ago" +%Y-%m-%dT%H:%M:%SZ 2>/dev/null \
         || date -u -v-1d +%Y-%m-%dT%H:%M:%SZ 2>/dev/null)
if [[ -n "$YESTERDAY" ]]; then
  RECENT_SESSIONS=$(echo "$EVENTS" | jq -r "select(.ts >= \"$YESTERDAY\" and .event == \"session_start\") | .session" | sort -u | wc -l)
  RECENT_FIRES=$(echo "$EVENTS" | jq -r "select(.ts >= \"$YESTERDAY\" and .event == \"way_fired\") | .way" | wc -l)
  echo "Last 24h: ${RECENT_SESSIONS} sessions, ${RECENT_FIRES} way fires"
fi
