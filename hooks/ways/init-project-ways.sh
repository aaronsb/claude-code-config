#!/bin/bash
# SessionStart: Initialize project .claude/ directory structure
# Creates ways template and .gitignore so ways get committed
# but developer-local files stay out of version control.

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$PWD}"
CLAUDE_DIR="$PROJECT_DIR/.claude"
WAYS_DIR="$CLAUDE_DIR/ways"
TEMPLATE="$WAYS_DIR/_template.md"
GITIGNORE="$CLAUDE_DIR/.gitignore"

# Only create if .claude exists (respect projects that don't use it)
# Or create both if this looks like a git repo
if [[ -d "$CLAUDE_DIR" ]] || [[ -d "$PROJECT_DIR/.git" ]]; then
  if [[ ! -d "$WAYS_DIR" ]]; then
    mkdir -p "$WAYS_DIR"
  fi

  # Ensure .gitignore exists — commit ways, ignore local state
  if [[ ! -f "$GITIGNORE" ]]; then
    cat > "$GITIGNORE" << 'GIEOF'
# Developer-local files (not committed)
settings.local.json
todo-*.md
memory/
projects/
plans/

# Ways and CLAUDE.md ARE committed (shared team knowledge)
GIEOF
    echo "Created .claude/.gitignore"
  fi

  if [[ ! -f "$TEMPLATE" ]]; then
    cat > "$TEMPLATE" << 'EOF'
---
keywords: your|trigger|patterns
files: optional\.file\.pattern$
commands: optional\ command\ pattern
---
# Way Name

A "way" is contextual guidance that loads once per session when triggered.

## Creating This Way

1. Copy this template to `your-way-name.md`
2. Update the frontmatter:
   - `keywords:` - regex patterns for user prompts
   - `files:` - regex patterns for file paths (Edit/Write)
   - `commands:` - regex patterns for bash commands
3. Replace content with your guidance

## Example

For a React project, you might create `react.md`:

```yaml
---
keywords: component|hook|useState|useEffect|jsx
files: \.(jsx|tsx)$
---
```

## Guidance Section

- Keep it compact and actionable
- Bullet points work well
- Link to detailed docs if needed
EOF
    echo "Created project ways template: $TEMPLATE"
  fi
fi
