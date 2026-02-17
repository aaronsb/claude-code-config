# AI coding agent steering systems in 2026

**The field of AI coding agent configuration has undergone a dramatic evolution from static instruction files to modular, event-driven, semantically-matched systems — but no single tool has unified all the emerging paradigms yet.** Across Claude Code, Cursor, GitHub Copilot, Windsurf, and a dozen open-source alternatives, a clear architectural trajectory has emerged: away from monolithic "system prompt dumps" toward context-efficient, just-in-time guidance that respects the finite context window. The aaronsb/claude-code-config "ways" system, with its BM25 semantic matching, event-driven triggers, and once-per-session gating, represents a genuinely novel point on this spectrum — pushing further toward dynamic, intelligent context management than anything publicly available. This report maps the full landscape, compares architectural approaches, and positions the "ways" system within the field.

## The five-layer architecture now standard in Claude Code

Claude Code has matured into the most configurable AI coding assistant on the market, with a **six-surface configuration stack** that other tools are beginning to emulate. The hierarchy runs from always-on context to event-driven automation:

**CLAUDE.md** sits at the base — a persistent markdown file loaded at session start that acts as the agent's "constitution." Best practices have converged around keeping it under **200 lines**, using `@file` references instead of inline code, and treating it like reviewed source code. Anthropic's `/init` command auto-generates a starter. Enterprise teams like Trail of Bits maintain manually curated 13KB+ files. **Rules** (`.claude/rules/`) provide filtered domain knowledge auto-loaded by scope. **Skills** (`.claude/skills/`) are the biggest recent innovation: reusable workflows with YAML frontmatter where Claude uses **semantic matching on descriptions** to decide what to activate. Skills consume only ~**100 tokens for metadata scanning** and under 5K tokens when fully activated — a progressive disclosure model that directly addresses context efficiency. **Agents** (`.claude/agents/`) define specialized subagents with isolated context windows, restricted tools, and per-agent model selection. **Hooks** (`.claude/settings.json`) provide deterministic lifecycle automation across 12+ event types including PreToolUse, PostToolUse, UserPromptSubmit, Stop, SubagentStop, and the newer TeammateIdle and TaskCompleted events. **Commands** (`.claude/commands/`) complete the picture with user-invoked slash commands. A **plugin system** bundles all of these into distributable, toggleable packages with decentralized marketplaces.

The community ecosystem is massive. The **awesome-claude-code** list has **23,500 GitHub stars**. ChrisWiles/claude-code-showcase (**3,800 stars**) demonstrates the full configuration surface. disler/claude-code-hooks-mastery (**3,000 stars**) provides a comprehensive hooks reference. Anthropic's own skills repo has **37,500 stars**. The Trail of Bits claude-code-config represents the highest-quality enterprise deployment, with security-focused skills, sandboxed devcontainers, and commands like `/review-pr` that coordinate parallel agents across multiple models.

## Cursor evolved from monolith to modular semantic rules

Cursor's configuration journey mirrors the broader field's trajectory. The original `.cursorrules` was a single monolithic text file in the project root — a flat system prompt injection. This gave way to `.cursor/rules/*.mdc` files (Markdown Cursor format), and most recently in Cursor 2.2 to **folder-based rules** with `RULE.md` files containing YAML frontmatter.

The key architectural innovation is Cursor's **four rule types with semantic selection**: "Always" rules load unconditionally; "Auto Attached" rules activate based on **glob patterns** matching referenced files; "Agent Requested" rules let the AI read the description and autonomously decide whether to include the rule; "Manual" rules require explicit `@ruleName` invocation. This "Agent Requested" type is the closest mainstream parallel to semantic matching for rule selection — the AI evaluates rule descriptions against the current task context. Community consensus, led by developers like Elie Steinbock, is that **Agent Requested should be the default type**, letting Claude decide what's relevant.

Cursor introduced **hooks in version 1.7** (September 2025) with six lifecycle events: beforeSubmitPrompt, beforeShellExecution, beforeMCPExecution, beforeReadFile, afterFileEdit, and stop. Hooks are configured in `.cursor/hooks.json` and run external scripts receiving JSON via stdin, structurally similar to Claude Code's system. The community ecosystem is anchored by **PatrickJS/awesome-cursorrules** with a staggering **~35,000-38,000 stars**, cursor.directory (**~3,800 stars**) hosting 800+ rule templates, and sanjeed5/awesome-cursor-rules-mdc (**~3,000 stars**) that auto-generates MDC files using semantic search. Cursor now supports four rule layers — Project, User, Team, and Agent (via AGENTS.md) — at a **$500M ARR** scale serving **50%+ of Fortune 500 companies**.

## AGENTS.md is becoming the universal standard, with holdouts

**AGENTS.md**, released by OpenAI in August 2025 and now stewarded by the **Agentic AI Foundation** under the Linux Foundation, has emerged as the leading cross-tool standard for agent steering. The specification is deliberately simple: plain markdown files placed at the repository root or in subdirectories, with the closest file to edited code taking precedence. The GitHub repo has **17,200 stars** and the format is used in **60,000+ open-source projects**.

Native support spans an impressive roster: OpenAI Codex CLI, Google Jules, Gemini CLI, GitHub Copilot coding agent, VS Code, Cursor, Windsurf, Aider, Roo Code, and dozens more. The most notable holdout is **Anthropic's Claude Code**, which still uses its proprietary CLAUDE.md format. Community pressure is mounting — issue #6235 on anthropics/claude-code requests AGENTS.md support — and workarounds exist (symlinking CLAUDE.md to AGENTS.md, or having CLAUDE.md reference AGENTS.md). The **Agentic AI Foundation** (formed December 9, 2025) brings together AWS, Anthropic, Block, Bloomberg, Cloudflare, Google, Microsoft, and OpenAI as platinum members, suggesting eventual convergence.

GitHub Copilot supports both its legacy `.github/copilot-instructions.md` and AGENTS.md, with path-specific instruction files in `.github/instructions/`. The Copilot coding agent (4.7 million paid users as of January 2026) can be configured through custom agents (`.github/agents/`), skills (`.github/skills/`), and hooks. Windsurf uses `.windsurf/rules/` with four activation modes (Always On, Manual, Model Decision, Glob-based), though with a restrictive **6,000-character limit** per rule file and **12,000 total**. OpenAI's Codex CLI uses `config.toml` for technical settings and AGENTS.md for behavioral steering, with a trust model that blocks project-scoped configs for untrusted repos.

## Cline, Roo Code, and aider take distinct approaches

The VS Code extension ecosystem has developed its own rich steering vocabulary. **Cline** (39K+ GitHub stars, 5M+ VS Code installations) uses `.clinerules` files or a `.clinerules/` directory with alphabetical loading and numeric prefix ordering. Its most notable feature is **conditional rules via YAML frontmatter** with `paths:` globs — rules only activate when working with matching files. Cline v3.13+ added a toggleable rules popover, and the system supports self-editing rules (Cline can modify its own `.clinerules`).

**Roo Code** (22K+ stars, 1.2M+ VS Code installations), forked from Cline, has built the most sophisticated mode-based steering system. It offers built-in modes (Code, Architect, Ask, Debug, Orchestrator) plus fully custom modes, each with independent role definitions, tool access permissions, model selection, and rules. Rules follow a hierarchical directory structure: global `~/.roo/rules/` and `~/.roo/rules-{mode}/` for mode-specific global rules, plus workspace-level `.roo/rules/` and `.roo/rules-{mode}/`. An experimental **"Power Steering"** feature constantly reinforces the LLM's role definition in every message. The community **Roo Commander** project implements a sophisticated orchestration system with TOML+MD formatted rules containing metadata (id, title, scope, status).

**Aider** takes the simplest approach: a `.aider.conf.yml` YAML file with a `read:` key pointing to convention files (typically `CONVENTIONS.md`). All conventions load statically at startup with no conditional activation, glob matching, or scoping. Despite this simplicity, aider remains highly regarded for precision in existing codebases.

**Continue.dev** (20-26K+ stars) offers a Hub-based rules ecosystem at hub.continue.dev, a `rules` CLI for managing rules across AI assistants, and a `.continue/rules/` directory structure with YAML frontmatter similar to Cursor's.

## The architectural spectrum from static to dynamic

Across all tools, six key architectural patterns define the state of the art:

**Static monolithic** (legacy .cursorrules, .windsurfrules, CONVENTIONS.md): A single file loaded entirely at session start. Simple but wastes context tokens on irrelevant guidance. Now universally considered the floor, not the ceiling.

**Modular file-scoped** (Cursor .mdc, Windsurf .windsurf/rules/, Cline .clinerules/): Rules split across files with glob-based activation. The mainstream standard. Efficient when file patterns correlate with needed guidance, but requires manual maintenance of glob patterns and doesn't handle cross-cutting concerns well.

**Semantic matching** (Claude Code skills, Cursor "Agent Requested" rules): The model reads rule/skill descriptions and decides what to activate based on the current context. Progressive disclosure minimizes context consumption. Claude's skill system loads ~30-50 tokens per skill for metadata, enabling 100+ skills before context becomes an issue. This is where the mainstream leading edge sits.

**Event-driven hooks** (Claude Code hooks, Cursor hooks, Copilot hooks): Deterministic shell scripts triggered at lifecycle points. The consensus pattern is **"block-at-submit, not block-at-write"** — let the agent finish its plan, then validate the final result. Claude Code leads with 12+ hook events and three handler types (command, prompt, agent hooks), versus Cursor's 6 events.

**Dynamic context engines** (Augment Code Context Engine, kontext-engine, grepai): External systems providing deep semantic codebase understanding via MCP servers. Augment claims **30-80% quality improvements** on real-world benchmarks. These combine vector similarity, full-text search, AST symbol lookup, path matching, and dependency tracing.

**Environment-reactive** (dave1010/agent-situations): The most experimental approach — rules that activate based on runtime environment checks (git branch, framework detection, build status). Context is ephemeral: if a check passes, guidance appears; if not, it vanishes. This addresses the fundamental drift problem where static rules become outdated.

## Where the "ways" system sits in the landscape

The aaronsb/claude-code-config "ways" system, as described, combines elements from multiple architectural layers into something that doesn't exist elsewhere in the public ecosystem. Its position relative to the field can be mapped precisely across each claimed feature:

**Event-driven triggers with semantic matching** is the system's most distinctive combination. While Claude Code hooks provide the event infrastructure (UserPromptSubmit, PreToolUse, SubagentStart), and Claude's skill system provides semantic matching, no public system combines both: using hooks as the trigger mechanism and then performing **BM25 semantic matching with gzip NCD fallback** to decide which guidance to inject. Claude's built-in skill system relies on the model itself to evaluate descriptions — a softer, probabilistic approach. The "ways" system would be performing matching in external code (the hook script), giving deterministic control over what enters the context. This is architecturally novel.

**Once-per-session firing with marker-based gating** solves a problem that no other public system addresses explicitly. Hooks fire every time their event occurs. Without deduplication, a PreToolUse hook that injects guidance would fire repeatedly, wasting context. Marker-based gating (presumably tracking which "ways" have already been injected in a session) is an elegant context-efficiency mechanism. The closest parallel is Claude's skill system, where skills "remain installed but don't carry conversation state" and trigger independently per request — but without explicit deduplication.

**Subagent injection** addresses a known gap in the ecosystem. As noted in community documentation, "subagents don't inherit skills automatically — must explicitly list which skills a subagent can use." A system that automatically carries relevant guidance into spawned subagents via SubagentStart hooks fills a real architectural hole.

**The macro system for dynamic context** resembles the environment-reactive pattern of agent-situations but with richer capabilities. Querying the GitHub API at trigger time to inject current issue context, branch status, or repository metadata is more powerful than static files or simple environment checks.

**Domain-based organization with enable/disable** parallels Claude's plugin system (which bundles skills, commands, agents, and hooks into toggleable packages) but operates at the guidance level rather than the tool level.

**Governance/provenance traceability** is genuinely unique. No public Claude Code configuration system provides formal traceability of which guidance was injected, when, and why. The closest parallel is enterprise audit logging via PostToolUse hooks (as in disler's hooks-mastery repo), but tracing guidance provenance is a step beyond tracing tool execution.

**Context budget efficiency** is the philosophical core. Every system in the ecosystem is converging on this problem — the context window is finite, and dumping everything into it is wasteful. Skills use progressive disclosure (~100 tokens for scanning, <5K for activation). Cursor's Agent Requested rules let the model decide. The "ways" system's approach — external BM25/NCD matching to select only relevant guidance before injection — is the most aggressive optimization in the described landscape.

## What other systems do that "ways" doesn't

Several capabilities present in the broader ecosystem appear absent from the described "ways" system:

**Cross-tool portability**: AGENTS.md works across 20+ tools. The "ways" system is Claude Code-specific, built on Claude's hook infrastructure. In a world converging on AGENTS.md and the Agentic AI Foundation, tool-specific systems face adoption headwinds.

**Plugin marketplace distribution**: Claude Code's plugin ecosystem (SkillsMP.com catalogs 200,000+ skills) provides distribution at scale. A custom steering system requires manual installation and maintenance.

**Model-evaluated relevance**: Claude's built-in skill system uses the model's own reasoning to decide relevance — potentially more nuanced than BM25/NCD string matching for complex, abstract tasks where lexical similarity doesn't capture semantic relevance.

**Formal permission control**: Claude Code's built-in permission system (allow/deny rules for tools, files, and paths) provides security boundaries that hooks can supplement but not replace.

**Team-level governance**: Cursor's team rules, Copilot's organization-level instructions, and Claude Code's managed settings provide centralized policy enforcement. The "ways" system appears focused on individual/project use.

## The field is converging on three principles

Three clear trends define where this space is heading. First, **progressive disclosure is the winning context strategy** — load metadata cheaply, activate full content only when relevant. Claude's skills, Cursor's Agent Requested rules, and the "ways" system's BM25 matching all embody this principle, just with different matching mechanisms. Second, **hooks are becoming universal infrastructure** — Claude Code (12+ events), Cursor (6 events), and Copilot all now support lifecycle hooks, making event-driven systems portable across platforms. Third, **standardization is inevitable but incomplete** — AGENTS.md and the Agent Skill Standard (agentskills.io) are converging the instruction format, but the *execution* layer (hooks, semantic matching, context management) remains fragmented and proprietary.

## Conclusion

The AI coding agent steering landscape in early 2026 is a Cambrian explosion. The **mainstream** sits at modular rules with glob-based scoping and model-evaluated semantic matching (Claude skills, Cursor Agent Requested rules). The **leading edge** includes event-driven hook systems, dynamic context engines (Augment, kontext-engine), and environment-reactive approaches (agent-situations). The "ways" system described in aaronsb/claude-code-config would sit at or beyond this leading edge — its combination of BM25/NCD semantic matching inside hook scripts, once-per-session gating, subagent injection, dynamic macros, and governance traceability constitutes a genuinely novel architecture. Its closest relatives are Claude's built-in skill system (for semantic matching), agent-situations (for dynamic context), and enterprise hook patterns (for event-driven execution), but nothing public combines all of these into a single coherent system. The key risk for any tool-specific system is the steamroller of standardization: AGENTS.md, the Agentic AI Foundation, and the Agent Skill Standard are rapidly establishing cross-platform conventions that may make proprietary steering systems technically orphaned — even if architecturally superior. The open question is whether the ecosystem will converge on a standard execution layer to match its converging instruction format, or whether hook-level customization will remain the domain of power users building exactly the kind of system "ways" represents.