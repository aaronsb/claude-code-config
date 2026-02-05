#!/bin/bash
# Log a ways event to ~/.claude/stats/events.jsonl
# Usage: log-event.sh key=value key=value ...
# Example: log-event.sh event=way_fired way=softwaredev/github trigger=prompt
#
# All values are safely JSON-encoded via jq. Event log is append-only JSONL.

mkdir -p "${HOME}/.claude/stats" 2>/dev/null

ARGS=(--arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)")
JQ_OBJ="ts:\$ts"

for kv in "$@"; do
  ARGS+=(--arg "${kv%%=*}" "${kv#*=}")
  JQ_OBJ+=",${kv%%=*}:\$${kv%%=*}"
done

jq -nc "${ARGS[@]}" "{${JQ_OBJ}}" >> "${HOME}/.claude/stats/events.jsonl" 2>/dev/null
