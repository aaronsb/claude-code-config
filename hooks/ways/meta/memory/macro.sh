#!/usr/bin/env bash
# Check MEMORY.md state for the current project's auto memory directory

# Find the memory directory from the system prompt pattern
# ~/.claude/projects/<project-path>/memory/
PROJECT_DIR="${PROJECT_DIR:-.}"
# Normalize project path the way Claude Code does it
NORMALIZED=$(echo "$PROJECT_DIR" | sed 's|^/||; s|/|-|g')
MEMORY_DIR="$HOME/.claude/projects/-${NORMALIZED}/memory"
MEMORY_FILE="$MEMORY_DIR/MEMORY.md"

if [ ! -f "$MEMORY_FILE" ]; then
    echo "**MEMORY.md does not exist yet for this project.** This is a fresh start — create it now."
elif [ ! -s "$MEMORY_FILE" ]; then
    echo "**MEMORY.md exists but is empty.** Seed it with learnings from this session."
else
    LINES=$(wc -l < "$MEMORY_FILE")
    echo "**MEMORY.md has ${LINES} lines.** Review and update with new insights from this session."
fi
