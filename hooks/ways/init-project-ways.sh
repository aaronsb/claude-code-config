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
# Project Ways Template

Ways are contextual guidance that loads once per session when triggered.
Each way lives in its own directory: `{domain}/{wayname}/way.md`

## Creating a Way

1. Create a directory: `.claude/ways/{domain}/{wayname}/`
2. Add `way.md` with YAML frontmatter + guidance

### Pattern matching (for known keywords):

```yaml
---
pattern: component|hook|useState|useEffect
files: \.(jsx|tsx)$
commands: npm\ run\ build
---
# React Way
- Use functional components with hooks
```

### Semantic matching (for broad concepts):

```yaml
---
description: React component design, hooks, state management
vocabulary: component hook useState useEffect jsx props render state
threshold: 2.0
---
# React Way
- Use functional components with hooks
```

Matching is additive — a way can have both pattern and semantic triggers.

## Tips

- Keep guidance compact and actionable
- Include the *why* — agents apply better judgment when they understand the reason
- Use `/test-way score <way> "sample prompt"` to verify matching
- Use `/test-way suggest <way>` to find vocabulary gaps
EOF
    echo "Created project ways template: $TEMPLATE"
  fi
fi
