---
name: think-react
description: ReAct reasoning — explicit reason-act-observe cycle for investigation and debugging. Use when you need to interleave reasoning with tool actions systematically.
allowed-tools: Read, Bash, Glob, Grep
---

# ReAct

Read the strategy definition and follow its stages in order:

```bash
cat ~/.claude/hooks/ways/meta/think/strategies/react.md
```

This strategy is cyclic (max 8 iterations). Work through the reason-act-observe loop until you have enough evidence to synthesize a conclusion.
