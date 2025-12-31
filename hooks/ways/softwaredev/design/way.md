---
description: software system design architecture patterns database schema api modeling component
semantic_keywords: software system design architecture pattern patterns database schema modeling api endpoint interface component modules factory observer strategy behavioral data structure
semantic: true
ncd_threshold: 0.55
---
# Design Way

## When This Triggers

This way uses **semantic matching** (keyword counting + gzip NCD) to detect software design discussions:
- System architecture and component design
- Design patterns (factory, observer, strategy, etc.)
- API design and data modeling
- Trade-off discussions

**Not for**: UI/UX design, graphic design, casual "design" usage.

## Design Discussion Framework

1. **Context**: What problem are we solving?
2. **Constraints**: What limits our options?
3. **Options**: What approaches could work?
4. **Trade-offs**: What does each option cost/gain?
5. **Decision**: What do we choose and why?

## Common Patterns

| Pattern | When to Use |
|---------|-------------|
| Factory | Object creation complexity |
| Strategy | Swappable algorithms |
| Observer | Event-driven decoupling |
| Repository | Data access abstraction |
| Adapter | Interface compatibility |

## Questions to Ask

- "What changes most frequently?"
- "What needs to be independently deployable?"
- "Where are the natural boundaries?"
- "What would make this testable?"
