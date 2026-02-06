# Rationale

Why this system exists and how it's designed.

## The Problem

Claude Code sessions start with a blank slate. Project conventions, workflow standards, and operational guardrails need to reach the model at the right moment - not all upfront (wasting context), not too late (after mistakes are made).

Static instruction files (CLAUDE.md) solve the "always present" case but can't respond to what's actually happening in a session. A commit message reminder is useless during a debugging session. Security guidance matters when editing auth code, not when writing docs.

## Three-Layer Model

This system separates concerns into three layers, each serving a different audience and purpose:

| Layer | Files | Audience | Optimized For |
|-------|-------|----------|---------------|
| **Policy** | `docs/hooks-and-ways/` | Humans | Understanding, rationale, 5W1H |
| **Reference** | `docs/hooks-and-ways.md` | Human-machine bridge | How the system works, data flow |
| **Machine guidance** | `hooks/ways/*/way.md` | Claude (LLM) | Terse, directive, context-efficient |

**Policy** is where organizational opinions live in prose. "We use conventional commits because..." - the kind of thing a new team member reads to understand why things are done a certain way.

**Reference** documents the machinery: which hooks fire when, how matching works, what scripts do. It's the system manual.

**Machine guidance** is the actual content injected into Claude's context window. These read differently from normal documentation - they're short, imperative, and structured for a language model to act on. A human can read them but might find the style terse. That's by design: every token in the context window costs capacity.

## Design Principles

### Just-in-time over just-in-case

Ways inject guidance when it's relevant, not preemptively. This keeps the context window lean and the guidance actionable. A 50-line testing way that appears when you run `pytest` is more effective than 50 lines permanently occupying the system prompt.

### Once per session

Most guidance only needs to be seen once. The marker system ensures a way fires on first match and stays silent afterward. This prevents the same guidance from consuming context on every prompt.

The exception is the context-threshold nag, which repeats deliberately because its purpose is enforcement, not education.

### Trigger specificity

Ways can trigger on user prompts (what you ask for), tool use (what Claude is about to do), or session state (how full the context is). This means guidance arrives through the channel closest to the action:

- Prompt triggers catch intent ("I want to refactor this")
- Command triggers catch execution (`git commit`)
- File triggers catch targets (editing `.env`)
- State triggers catch conditions (context 75% full)

### Separation from Claude Code

The system is built entirely on Claude Code's hook API - shell scripts that receive JSON and return JSON. No patches, no forks, no internal modifications. This means it survives Claude Code updates and can be shared across machines by copying `~/.claude/hooks/`.

## "But Claude already knows how to do this"

A fair objection: Claude's training data covers most of these topics. Why inject guidance about commit conventions or error handling when the model already has strong opinions?

The answer is that ways aren't about filling knowledge gaps. They're about **encoding a specific person's developed opinions** about how work should be done. Claude knows many approaches to error handling. These ways encode *this* approach - one that was developed through actual use, refined through collaboration, and proven to work in this context.

A model's training gives it breadth. Ways give it a specific posture - the opinions that emerged from what worked and what didn't across real sessions. "Here's how to handle errors" is generic training data. "Catch at boundaries only, wrap with context at module crossings, let programmer errors crash" is a developed position.

This is also why ways evolve. They start as principles, get tested in practice, and get refined when they don't work. The governance docs capture the rationale so future refinements have context about why things are the way they are.

## What This Replaces

Without this system, the alternatives are:

- **Giant CLAUDE.md files** - Everything in one file, always in context, diluting attention
- **Manual reminders** - Relying on the user to tell Claude about conventions
- **Post-hoc fixes** - Catching problems in code review instead of preventing them
- **Nothing** - Accepting inconsistency across sessions

The ways system is a middle ground: automated enough to be reliable, transparent enough to be understood, and lightweight enough to not get in the way.

## The Cost of Bad Instructions

Every interaction with a language model has a real cost — compute, energy, money. These costs are easy to ignore because they're distributed and invisible at the individual level, but they're there.

A vague instruction that takes three retries to get right costs three times what a clear one does. A 200-line CLAUDE.md that's always in context burns tokens on every single prompt, whether relevant or not. A way that fires at the wrong time wastes context capacity that could have been used for the actual work. A team of five agents given conflicting guidance will thrash, retry, and duplicate effort — multiplying the waste.

This isn't hypothetical. If you've ever watched an agent go in circles because the instructions were ambiguous, or retry a task because it lacked context that could have been provided upfront, you've seen the cost. You just didn't see the meter running.

Good governance is resource efficiency:

- **Just-in-time delivery** means tokens aren't spent until they're needed
- **Once-per-session gating** means guidance doesn't repeat wastefully
- **Clear framing** means fewer misunderstandings, fewer retries, fewer wasted cycles
- **The "we" pattern** means alignment on the first attempt, not correction on the third

None of this is precisely measurable at the individual session level. But across thousands of sessions, millions of prompts, and an industry of AI-assisted work, the difference between thoughtful guidance and careless instruction is real — economically and environmentally. Writing well for your agents isn't just good practice. It's good stewardship.
