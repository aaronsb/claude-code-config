# Long-Context Performance: Model Compatibility Reference

Empirical benchmarks for context degradation across models. These numbers inform the ways system's token-gated re-disclosure intervals.

## Source Data

Benchmarks from Anthropic's Claude 4.6 model card (March 2026).

- **GraphWalks BFS** — Long-context reasoning (multi-hop graph traversal)
- **MRCR v2, 8-needle** — Long-context retrieval (find 8 specific facts in a long context)

## Retrieval Degradation (MRCR v2, 8-needle)

![MRCR v2 Retrieval](mrcr-v2-retrieval.png)

| Model | 128K | 256K | 512K | 1M | Drop (256K→1M) |
|-------|------|------|------|-----|-----------------|
| **Opus 4.6** | — | 91.9% | ~85% | 78.3% | **-14.8%** |
| **Sonnet 4.6** | — | 90.6% | ~75% | 65.1% | **-28.1%** |
| Sonnet 4.5 | — | 10.8% | — | 18.5% | n/a (poor baseline) |
| GPT-5.4 | 79.3 | — | ~40% | 36.6% | — |
| Gemini 3.1 Pro | 71.9 | 59.1% | 39.4% | 25.9% | — |

**Key takeaway**: Opus retains ~78% retrieval accuracy at 1M — strong but not lossless. Sonnet degrades to 65%, making re-disclosure more critical.

## Reasoning Degradation (GraphWalks BFS)

![GraphWalks BFS Reasoning](graphwalks-bfs-reasoning.png)

| Model | 256K | 1M | Drop |
|-------|------|-----|------|
| **Opus 4.6** | 72.8% | 68.4% | **-6.0%** |
| **Sonnet 4.6** | 61.5% | 41.2% | **-33.0%** |
| Sonnet 4.5 | 44.9% | 25.6% | -43.0% |

**Key takeaway**: Opus reasoning is remarkably stable across context length. Sonnet's reasoning degrades sharply — by 1M it's lost a third of its reasoning capacity.

## Implications for Ways System

### The Problem

The current "disclose once per session" rule was designed for 200K context windows where the entire conversation was within a single effective attention span. At 1M tokens:

- A way disclosed at token 50K has measurably degraded influence at token 500K
- Retrieval accuracy for that disclosure drops ~15-20% (Opus) or ~30%+ (Sonnet)
- Reasoning quality about that domain's rules degrades further
- The guidance is not *gone* — it's *faded*

### The Model

Ways system behavior should adapt to empirically measured context degradation:

```
Token position →   50K          250K          500K          750K          1M
                    │             │             │             │             │
Opus retrieval:   ~92%          ~87%          ~83%          ~80%          ~78%
Sonnet retrieval: ~91%          ~82%          ~73%          ~69%          ~65%
                    │             │             │             │             │
Way influence:    STRONG ────── WARM ────────── COOL ──────── COLD ──────── FADED
```

### Recommended Re-Disclosure Intervals

Based on the degradation curves, ways should become re-eligible when retrieval accuracy has dropped enough to meaningfully affect behavior:

| Model | Re-disclosure interval | Rationale |
|-------|----------------------|-----------|
| **Opus 4.6 (1M)** | ~250K tokens | Retrieval drops ~10% per 250K; reasoning stays stable. Re-disclose when the way has lost meaningful retrieval fidelity but before it's forgotten. |
| **Sonnet 4.6 (200K)** | ~80K tokens | Steeper degradation curve. At 200K window this means ~2 re-disclosures max per session. |
| **Haiku 4.5 (200K)** | ~60K tokens | Assumed steeper degradation (no benchmark data). Conservative interval. |

### Token Budget Consideration

Re-disclosure has a cost: each way injection is ~200-500 tokens. At 250K intervals on a 1M window, that's ~3-4 re-disclosures per way per session. For a session that triggers 5 ways, that's ~6-10K tokens total — well under 1% of the budget.

## How This Connects to Epochs

The current epoch counter tracks **events** (hook firings). Token distance is a different axis:

| Metric | What it measures | Good for |
|--------|-----------------|----------|
| **Epoch distance** | How many tool actions since way fired | Check decay (is the model still thinking about this domain?) |
| **Token distance** | How much context has accumulated since way fired | Re-disclosure (has the way faded from retrievable memory?) |

Both are useful. Epoch distance drives check scoring (ADR-103). Token distance drives way re-disclosure. They complement each other.
