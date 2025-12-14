#!/bin/bash
# Lists persistent tracking files in the current project's .claude/ directory
# Used by SessionStart hook to inform Claude about cross-session tracking files

# CLAUDE_PROJECT_DIR is set by Claude Code during hook execution
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-.}"

# Look for tracking files
TRACKING_DIR="${PROJECT_DIR}/.claude"
TRACKING_FILES=$(ls -1 "${TRACKING_DIR}"/todo-*.md 2>/dev/null)

if [ -n "$TRACKING_FILES" ]; then
    echo ""
    echo "## Persistent Tracking Files"
    echo ""
    echo "The following tracking files exist in \`.claude/\` for this project."
    echo "Read relevant files when resuming work or after compaction:"
    echo ""
    echo "$TRACKING_FILES" | while read -r file; do
        basename "$file"
    done
    echo ""
    echo "Naming conventions:"
    echo "- \`todo-adr-NNN-*.md\` - ADR implementation tracking"
    echo "- \`todo-pr-NNN.md\` - PR work/review tracking"
    echo "- \`todo-issue-NNN.md\` - Issue resolution tracking"
    echo ""
fi
