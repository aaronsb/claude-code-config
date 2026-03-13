---
status: Draft
date: 2026-03-13
deciders:
  - aaronsb
  - claude
related:
  - ADR-103
  - ADR-004
---

# ADR-104: Token-Gated Way Re-Disclosure for Long Context Windows

## Context

Ways currently fire once per session, gated by a marker file (`/tmp/.claude-way-{name}-{session}`). This rule was designed for 200K context windows where the entire conversation fit within a single effective attention span.

With Opus 4.6's 1M context window, this assumption breaks. Empirical benchmarks show measurable degradation over long contexts:

- **Retrieval** (MRCR v2): Opus drops from 91.9% at 256K to 78.3% at 1M (~15% degradation)
- **Reasoning** (GraphWalks BFS): Opus drops from 72.8% at 256K to 68.4% at 1M (~6% degradation)
- **Sonnet 4.6** degrades much faster: retrieval 90.6% → 65.1%, reasoning 61.5% → 41.2%

(See `docs/reference/model-context-decay/` for benchmark charts and data tables.)

A way disclosed at token 50K is not gone at token 500K — but it's faded. The model can still retrieve the general concept but loses specificity. For guidance that depends on precise rules (security checks, commit conventions, architectural patterns), this degradation produces subtle failures: the model follows the spirit but misses the letter.

The current epoch counter (ADR-103) tracks **event distance** — how many tool actions have occurred since a way fired. This is the right metric for check decay (is the model still thinking about this domain?). But it's the wrong metric for re-disclosure (has the way faded from retrievable memory?). A session can have 200 epoch events in 50K tokens, or 10 epoch events in 500K tokens. Token distance is the signal that correlates with measured retrieval degradation.

## Decision

Replace the hard "once per session" marker with a **token-distance-gated re-eligibility window**. A way becomes eligible for re-disclosure when the token distance since its last disclosure exceeds a model-specific threshold.

### Token distance tracking

When a way fires, stamp the current token position alongside the existing epoch stamp:

```bash
# New: token position at disclosure time
# /tmp/.claude-way-tokens-{wayname}-{session} — token count when way last fired
```

Token position is read from the transcript using the same method as `context-usage.sh` — sum of `cache_read_input_tokens + cache_creation_input_tokens + input_tokens` from the most recent API usage record.

### Re-disclosure thresholds

Model-specific intervals based on empirical degradation curves:

| Model | Context window | Re-disclosure interval | Max re-disclosures |
|-------|---------------|----------------------|-------------------|
| Opus 4.6 | 1M | 250K tokens | ~3-4 per session |
| Sonnet 4.6 | 200K | 80K tokens | ~2 per session |
| Haiku 4.5 | 200K | 60K tokens | ~2-3 per session |

These intervals correspond to the point where retrieval accuracy has dropped ~10-15% from the disclosure point — enough to meaningfully affect rule compliance but not so aggressive that it wastes context budget.

### Marker file evolution

The current marker file (`/tmp/.claude-way-{name}-{session}`) becomes a **timestamp** file rather than a boolean:

```bash
# Before: touch creates empty file (boolean: exists = fired)
touch "$MARKER"

# After: write token position (numeric: enables distance check)
echo "$CURRENT_TOKENS" > "$MARKER"
```

The show-way.sh gate changes from:

```bash
# Before: fire if marker doesn't exist
if [[ ! -f "$MARKER" ]]; then

# After: fire if marker doesn't exist OR token distance exceeds threshold
if [[ ! -f "$MARKER" ]] || token_distance_exceeded "$MARKER" "$SESSION_ID"; then
```

### Model detection

The re-disclosure interval depends on the model. Detection uses the same approach as `context-usage.sh` — read the model field from the transcript:

```bash
MODEL=$(jq -r 'select(.type=="assistant" and .message.model) | .message.model' "$TRANSCRIPT" 2>/dev/null | tail -1)
case "$MODEL" in
  *opus-4-6*|*opus-4*)  REDISCLOSE_TOKENS=250000 ;;
  *sonnet*)             REDISCLOSE_TOKENS=80000 ;;
  *haiku*)              REDISCLOSE_TOKENS=60000 ;;
  *)                    REDISCLOSE_TOKENS=80000 ;;  # conservative default
esac
```

### Re-disclosure behavior

When a way re-discloses:

1. The way content is injected again (same as first disclosure)
2. The token stamp is updated to the current position
3. The epoch stamp is updated (checks reset their distance)
4. A `way_redisclosed` event is logged with the token distance that triggered it
5. The fire count is incremented (for stats, not for gating — re-disclosure doesn't decay)

### What re-disclosure is NOT

- **Not a timer.** It doesn't fire every N tokens regardless. The way must still be triggered by a matching prompt or tool action. Token distance only makes it *eligible* — it still needs a trigger to fire.
- **Not a check.** Checks (ADR-103) are pre-action verification sensors with decay curves. Re-disclosure is a periodic refresh of the full way guidance. Different purposes, different mechanics.
- **Not visible to the user.** This is internal bookkeeping. The user sees the same way content; they don't know it's a re-disclosure vs first disclosure.

### Interaction with checks (ADR-103)

When a way re-discloses, the epoch stamp resets. This means:

- Check distance drops to 0 (way is warm again)
- Check effective scores decrease (distance factor shrinks)
- Checks become less likely to fire immediately after re-disclosure

This is correct behavior — re-disclosure makes the check's re-anchor unnecessary because the full way content was just injected.

### Hidden implementation detail

Token-gated re-disclosure is invisible to the model. The model receives way content through the hook system's `additionalContext` field. Whether it's a first disclosure or a re-disclosure is indistinguishable from the model's perspective. This is intentional — the model should treat the guidance as fresh regardless.

## Consequences

### Positive

- Compensates for empirically measured retrieval degradation over long contexts
- Model-aware — adapts to each model's degradation curve
- Maintains the trigger requirement — ways only re-disclose when the domain is relevant
- Resets check distance — prevents stale checks from nagging when the way is freshly re-anchored
- Low token cost — ~200-500 tokens per re-disclosure, 3-4 times per session = <1% of 1M budget
- Invisible to the model — no behavioral change needed from the model's perspective

### Negative

- Adds token position reading to the hot path (one jq call per way evaluation)
- Model detection adds complexity to show-way.sh
- Thresholds are empirically derived but not session-specific — a session with dense tool use may need different intervals than a conversational session
- Requires transcript access (same as context-usage.sh — already validated)

### Neutral

- The epoch counter (ADR-103) remains unchanged — it tracks events, not tokens
- Check scoring (ADR-103) continues to use epoch distance — the two systems are complementary
- Stats logging gains a new event type (`way_redisclosed`) but uses the same infrastructure
- Opens the question of whether re-disclosure intervals should be tunable per way (we defer this — global model-based thresholds first)

## Alternatives Considered

- **Fixed epoch-based re-disclosure (every N events)** — Rejected because epoch count doesn't correlate with retrieval degradation. 100 quick edits in the same file (100 epochs) consume fewer tokens than 10 complex prompts with tool chains (10 epochs). Token distance is the right signal.

- **Percentage-of-window triggers (at 25%, 50%, 75%)** — Simpler but less nuanced. Doesn't account for when the way was first disclosed. A way first disclosed at 40% of the window should re-disclose at a different point than one disclosed at 5%.

- **Always re-disclose (remove the once-per-session gate entirely)** — Wasteful. Most hook events happen in quick succession during active work. Re-disclosing the same way 50 times in 10 minutes adds noise. The token distance gate ensures re-disclosure only happens when meaningful drift has occurred.

- **Decay the existing check system to handle re-anchoring** — Checks inject a short re-anchor (1-2 lines). Re-disclosure injects the full way content (~200-500 tokens). These serve different purposes: checks verify assumptions, re-disclosure refreshes the complete guidance. Using checks for re-disclosure would require making them much longer, defeating their "light sensor" design.

- **Let the user decide (manual re-disclosure command)** — Users shouldn't have to manage context decay. The whole point of the ways system is to provide guidance automatically. If the user has to remember "my security way has probably faded, I should re-trigger it," the system has failed.

## Implementation Plan

1. **Token position reader** — Extract from transcript (reuse context-usage.sh pattern)
2. **Model-to-threshold mapping** — In show-way.sh or a shared config
3. **Marker file evolution** — Write token position instead of empty touch
4. **Re-eligibility gate** — Replace boolean check with token distance check in show-way.sh
5. **Stats** — Add `way_redisclosed` event type to log-event.sh
6. **Observe** — Run for several sessions across Opus and Sonnet, compare way adherence before/after
