# Way Scoring and Testing

How we verify that ways trigger correctly — and only when they should.

## The Self-Validating Loop

The ways system doesn't just deliver guidance — it instructs its own quality assurance.

When Claude creates or modifies a way, the `meta/knowledge` way has already fired for that session, telling Claude how ways work — including that they use BM25 scoring with vocabulary and thresholds. The `/ways-tests` skill is listed in Claude's available tools. The memory system records "always verify new ways against sample prompts before shipping." The way-testing skill's own documentation includes scoring methodology, cross-way isolation checks, and vocabulary gap analysis.

So when Claude finishes writing a way and moves to testing it, that behavior isn't a separate QA step bolted on after the fact. It's the system telling Claude to validate itself, using tools the system provides, against criteria the system defines. The loop looks like this:

```
ways tell Claude how ways work
  → Claude creates a new way
    → ways (+ skills + memory) tell Claude to score it
      → Claude runs the scoring tool the system provides
        → scores reveal vocabulary gaps
          → Claude fixes the vocabulary
            → the improved way is now part of the system
              → that system tells Claude to score the next one
```

This is what makes the testing process reliable without a human manually running a test suite. Claude is both the author and the reviewer, but the *review criteria* come from the system itself — not from Claude's general training. The ways encode what "good" looks like for this specific project, and Claude applies those standards because the ways told it to.

The worked example below shows this loop in action during an actual way creation session.

## The Problem

Ways use BM25 scoring to decide whether a user's prompt is relevant to a particular domain of guidance. Each way has a vocabulary (terms it cares about), a description, and a threshold (minimum score to fire). Getting this right matters: a way that fires too eagerly drowns the user in irrelevant guidance; a way that never fires is dead weight.

With 50+ ways in the system, vocabulary space gets crowded. Adding terms to one way can accidentally create overlap with another. The only way to know is to test.

## How Test Prompts Get Written

The scoring process depends on realistic test prompts — but who writes them?

In this system, Claude generates test prompts by modeling how the human operator would naturally phrase their intent. This is the key mechanism: Claude knows what the way is *for* (from the description and the conversation that led to creating it), and translates that into the variety of ways a human might ask for that thing.

For example, the `meta/project-health` way exists so that when a user wonders about upstream Claude Code changes, the right guidance appears. Claude generates test prompts by thinking: "if I were a human who wanted to know what changed upstream, what would I actually type?"

That produces prompts like:
- "what's new in claude code recently" (casual, direct)
- "have we drifted from upstream claude code" (conceptual, uses domain language)
- "are our ADRs current with what we've shipped" (inward-facing, about self-assessment)
- "run project pulse" (direct tool invocation)

And negative prompts by thinking: "what would a human type that sounds vaguely related but should *not* trigger this way?"

- "how do I create a new way" (meta, but about authoring, not project health)
- "add error handling to the parser function" (code task, nothing to do with upstream)

This matters because **vocabulary gaps hide in the space between how the author thinks about the concept and how the user phrases their need**. The author writes `reconcile drift stale` thinking about ADR status. The user types "are our ADRs current with what we've shipped." Those are the same intent expressed in completely different words. Claude bridges this gap by generating prompts from the user's perspective, not the author's.

This is also why scoring is done iteratively during way creation rather than after the fact. The conversation that produces the way — where the human explains what they want and why — is exactly the context Claude needs to generate authentic test prompts. If scoring is deferred to a separate QA step, that conversational context is lost.

## The Tool

The `ways` binary includes BM25 scoring as a built-in subcommand (see [ADR-014](../architecture/legacy/ADR-014-tfidf-semantic-matcher.md) for the original design, [ADR-111](../architecture/system/ADR-111-unified-ways-cli-single-binary-tool-consolidation.md) for the consolidation). It scores a prompt against a way's description and vocabulary, returning a numeric score. If the score exceeds the way's threshold, the way would fire.

```bash
# Score a single prompt against a way
ways match \
  --description "Managing claude-code-config as a project..." \
  --vocabulary "upstream changelog release version..." \
  --query "what's new in claude code recently" \
  --threshold 2.5

# Output (stderr): match: score=7.0523 threshold=2.5000
# Exit code: 0 (match) or 1 (no match)
```

The `/ways-tests` skill wraps this with higher-level operations: scoring all ways against a prompt, analyzing vocabulary gaps, checking for cross-way overlap, and validating frontmatter.

## The Process: A Worked Example

This walkthrough shows the actual process used when creating the `meta/project-health` way (March 2026). The way provides guidance on managing claude-code-config's relationship to upstream Claude Code releases.

### Step 1: Write the way with initial vocabulary

The vocabulary was chosen by thinking about what a user would say when they want to check upstream changes or review project health:

```yaml
vocabulary: >
  upstream changelog release version claude-code update
  adr status reconcile drift stale dormant
  project pulse health review audit
  what's new recently changed since last
  relevance feature gap opportunity
threshold: 2.5
```

### Step 2: Score against target prompts

These are prompts that *should* trigger the way:

```
── Target Prompts (should match) ──────────────────────────────────

  "what's new in claude code recently"                      7.0523  YES
  "are our ADRs current with what we've shipped"            2.1322  NO ← problem
  "check if upstream features matter for our config"        4.2216  YES
  "run project pulse"                                       2.9856  YES
```

The second prompt — "are our ADRs current with what we've shipped" — missed. It scored 2.13 against a threshold of 2.5.

### Step 3: Diagnose the miss

BM25 scores based on term overlap weighted by rarity. The prompt uses "current" and "shipped" — neither appeared in the vocabulary. The only matching term was "adr" (from "ADRs" in the prompt), and a single term match can't carry the score past 2.5 alone.

This is the kind of gap that's invisible when you write the vocabulary by thinking about the *topic* — you think "ADR reconciliation" and write `reconcile drift stale`. But a user says "are our ADRs current with what we've shipped" using completely different words for the same concept.

### Step 4: Fix the vocabulary

Added four terms: `shipped`, `implemented`, `current`, `behind`.

### Step 5: Re-score and verify no regressions

```
── Target Prompts (should match) ──────────────────────────────────

  "what's new in claude code recently"                      7.0523  YES
  "are our ADRs current with what we've shipped"            4.9000  YES ← fixed
  "check if upstream features matter for our config"        4.0955  YES
  "run project pulse"                                       2.8966  YES
  "have we drifted from upstream claude code"               7.7195  YES
  "what claude code releases happened since our last commit" 9.5192  YES

── Negative Prompts (should NOT match) ─────────────────────────────

  "add error handling to the parser function"               0.0000  NO
  "write unit tests for the auth module"                    0.0000  NO
  "refactor the database connection pool"                   0.0000  NO
  "how do I create a new way"                               1.4109  NO
  "fix the CSS layout on mobile"                            0.0000  NO
```

The miss is fixed (2.13 → 4.90). All other target prompts still match. All negative prompts still correctly reject. The nearest false-positive candidate ("how do I create a new way" at 1.41) is well below threshold.

### Step 6: Check cross-way isolation

The final check: does this way compete with other ways for the same prompts?

```
=== Cross-Way Ranking: "what's new in claude code recently" ===

  Score   Thr   Match  Way
  ──────  ────  ─────  ───
  7.0523  2.5   YES    meta/project-health  ← target
  1.8705  2.5   no     softwaredev/docs/docstrings
  1.7988  2.0   no     softwaredev/code/quality
  1.7500  2.0   no     softwaredev/code/supplychain/sourceaudit
  1.4922  1.8   no     softwaredev/code/security
  1.3589  2.0   no     softwaredev/docs/standards
  1.3396  2.0   no     softwaredev/delivery/github
  ...
```

Clean win. The target way scores 7.05; the next closest way scores 1.87 (well below its own threshold). No overlap, no competition.

## What to Look For

### Good signs

- **Clean win**: Target way is the clear top scorer with daylight to the next.
- **Correct rejects**: Unrelated prompts score 0.00 or well below threshold.
- **Score headroom**: Target prompts score well above threshold, not just barely over.

### Warning signs

- **Narrow miss**: A target prompt scores within 0.5 of the threshold. It may fail on slightly different phrasing.
- **Overlap cluster**: Two ways both match the same prompt with scores within 20% of each other. They're competing for the same semantic space.
- **False dominance**: Another way scores higher than the target for a prompt the target should own.
- **Vocabulary bleed**: Adding terms to fix one gap creates unexpected matches elsewhere.

### The vocabulary authoring trap

When writing vocabulary, it's natural to think in *your* terms — the terms that describe the concept from the inside. But users don't think about the concept from the inside. They think about their problem:

| You write | User says |
|-----------|-----------|
| `reconcile drift stale` | "are our ADRs current" |
| `epoch mapping feathered window` | "what changed since last time" |
| `upstream tracking` | "what's new in claude code" |

The fix is always the same: write target prompts *before* you write the vocabulary, then add the terms the prompts actually use.

## Sparsity as the Guard Against Overfitting

The natural instinct when a way misses a prompt is to add more vocabulary. When it misses another, add more. This works locally — each fix raises the score for the target prompt — but globally it's overfitting. Every term you add to a vocabulary is a term that could match prompts meant for a *different* way.

The system's defense against this is **sparsity**: each way should occupy a narrow, distinct region of the scoring space with minimal overlap against other ways. The goal isn't to maximize any single way's score. It's to maximize the *distance between ways* — so that for any given prompt, at most one or two ways fire, and it's obvious which one is the right one.

This is why the cross-way ranking check (Step 6 in the worked example) matters more than the individual scores. A way that scores 3.0 on its target prompt and has clean separation from every other way is healthier than a way that scores 8.0 but overlaps with three neighbors.

Concretely:

- **Narrow vocabularies are better than broad ones.** 15 precise terms beat 40 general terms. "upstream", "changelog", "drift" are specific to project-health. "update", "check", "status" are shared by many domains.
- **Don't chase every synonym.** If "shipped" fixes a miss, add it. But don't then add "deployed", "released", "landed", "merged", "delivered" — each one increases the surface area for false matches against delivery/release or delivery/github.
- **Threshold is a second lever.** If a way fires correctly but also fires weakly on unrelated prompts, raising the threshold is often better than trimming vocabulary. It preserves the true positives while cutting the false positives.
- **Accept some misses.** A way that fires for 90% of relevant prompts with zero false positives is better than one that fires for 100% but also fires for 5% of irrelevant prompts. The 0 FP constraint is hard; recall is soft.

The test harness enforces this: it tracks false positive rate as a hard constraint (must be 0) while accuracy can vary. Sparsity is how you maintain 0 FP as the vocabulary grows.

### Intentional co-fire: sparsity's inverse

Sparsity is the default — keep ways apart. But sometimes you *want* two ways to fire together. A project-scoped way and a user-scoped way might both be relevant when someone says "create a PR." A GitHub way and a custom Jira way might both need to fire when someone says "ship this ticket."

Rather than writing a third way that combines both concerns (more content to maintain, more context consumed), you can plant shared vocabulary terms in both ways so that BM25 naturally co-fires them on the same prompt. Two small ways that each contribute their piece is lighter than one large way that tries to cover everything.

This is a deliberate vocabulary manipulation — the opposite of sharpening. You're *reducing* the distance between two ways for specific prompts where both are genuinely needed. The key discipline is that the shared terms should be narrow: "pull request", "ship", "PR" — not broad terms like "code" or "deploy" that would create accidental overlap on unrelated prompts.

The `/ways-tests crowding` command distinguishes these cases. When it reports two ways co-firing, it flags whether the overlap looks accidental (similar scores on a prompt neither should own) or intentional (both score well on a prompt both should serve). The worked example's cross-way ranking shows this: a "healthy co-fire" is when two ways both match but serve complementary purposes.

## Tools Reference

| Command | Purpose |
|---------|---------|
| `/ways-tests score <way> "prompt"` | Score one way, with automatic cross-way context |
| `/ways-tests score-all "prompt"` | Rank all ways against a prompt |
| `/ways-tests suggest <way>` | Analyze vocabulary gaps (body terms missing from vocabulary) |
| `/ways-tests suggest <way> --apply` | Auto-fix vocabulary gaps |
| `/ways-tests crowding "prompt"` | Detect vocabulary overlap across all ways |
| `/ways-tests lint --all` | Validate all way frontmatter |

See the [ways-tests skill](/skills/ways-tests/SKILL.md) for full documentation.
