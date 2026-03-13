---
description: performance optimization, query optimization, caching, reducing latency, memory usage
vocabulary: optimize performance latency cache slow query index bottleneck throughput memory profile benchmark
threshold: 2.0
scope: agent
---

## anchor

You are optimizing for performance. Measure first — optimizing the wrong thing is worse than not optimizing.

## check

Before making this optimization:
- Have you **measured** the actual bottleneck, or are you assuming where the slowness is?
- Is there an existing benchmark or profile you can reference?
- Does this optimization trade **readability or correctness** for speed? Is that trade-off justified?
- Could this change make things **worse** under different load patterns (e.g., cache that helps reads but hurts writes)?
- Is this premature — does this code path actually need to be faster right now?
