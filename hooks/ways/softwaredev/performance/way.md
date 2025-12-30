---
keywords: slow|optimi[sz]|latency|profile|performance|speed.?up
---
# Performance Way

## Golden Rule
Measure before optimizing. Intuition about bottlenecks is often wrong.

## Approach
1. Profile to find actual bottleneck
2. Measure current performance (baseline)
3. Make one change
4. Measure again (compare)
5. Repeat

## Common Wins
- N+1 queries → batch/join
- Unnecessary re-renders → memoization
- Large payloads → pagination, lazy loading
- Repeated work → caching

## Common Traps
- Premature optimization
- Optimizing cold paths
- Micro-optimizations that hurt readability
- Caching without invalidation strategy
