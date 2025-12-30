---
keywords: subagent|delegat|spawn.*agent
---
# Sub-Agents Way

Main Claude handles most work. Use sub-agents for specialized, token-intensive tasks:

| Agent | Use For |
|-------|---------|
| **requirements-analyst** | Capture complex requirements as GitHub issues |
| **system-architect** | Draft ADRs, evaluate SOLID principles |
| **task-planner** | Plan complex multi-branch implementations |
| **code-reviewer** | Review large PRs, SOLID compliance checks |
| **workflow-orchestrator** | Project status, phase coordination |
| **workspace-curator** | Organize docs/, manage .claude/ directory |

## When NOT to Use
- Routine tasks you can handle directly
- Simple file searches or edits
- Quick questions or clarifications

Sub-agents are for delegation, not every action.
