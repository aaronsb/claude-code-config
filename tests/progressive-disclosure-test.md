# Progressive Disclosure & Think Strategy Integration Test

## Instructions for Claude

**CRITICAL: DO NOT explore the codebase, read hook scripts, or investigate how things work. This is a BLACK BOX test. You are testing OBSERVABLE BEHAVIOR, not implementation details.**

**DO NOT**:
- Spawn Explore agents
- Read hook scripts or way files
- Search the codebase for implementation details
- Try to understand how hooks work before testing

**DO**:
- Follow each step EXACTLY in order
- Ask the user to type the specified prompt (steps marked USER)
- Observe what system-reminder content appears after each prompt
- Report PASS/FAIL based on what you see vs what was expected

You are a test executor, not a researcher. Begin with Step 1 immediately after reading this file.

**Format your reports as**:
```
Step N: [description]
Result: PASS / FAIL / UNEXPECTED
Detail: [what happened vs what was expected]
```

Begin Step 1 NOW.

---

## Part A: Progressive Disclosure Tree Activation

### Step 1 — Root way fires on broad prompt

> **USER**: Type exactly: `let's review the security of this codebase`

> **CLAUDE**: Check if you received the **Security Way** root content. Look for "Security Way" heading with defaults and review checklist. Report what fired.

**Expected**: The root security way fires (threshold 1.8, vocabulary: security, vulnerability, protect). You should see "## Defaults" and "## When Reviewing Existing Code" — NOT the injection detection table or secrets management (those are children).

---

### Step 2 — Child way fires on specific prompt

> **USER**: Type exactly: `check if there's any SQL injection in the user input handling`

> **CLAUDE**: Check if you received the **Injection Prevention Way** child content. Look for the detection/action table and the anti-rationalization table. Report what fired.

**Expected**: The injection child way fires (threshold 2.0, vocabulary: injection, sql, xss, parameterized, sanitize). You should see:
- "## Detection and Action Rules" table
- "## Common Rationalizations" table (anti-rationalization pattern)

The root security way should NOT re-fire (marker exists from Step 1).

---

### Step 3 — Verify threshold lowering

> **CLAUDE**: Check the tree disclosure metrics file at `/tmp/.claude-way-metrics-{session_id}.jsonl`. Read it and report:
1. Did the injection child record the security root as its parent?
2. What was the epoch distance from parent to child?
3. What is the sibling coverage (how many of security's 3 children have fired)?

**Expected**: The metrics should show:
- `parent: "softwaredev/code/security"`, `depth: 1`
- `epoch_distance` should be 1-2 (injection fired shortly after root)
- `sibling_fired: 1` out of `sibling_total: 3`

---

### Step 4 — Sibling fires independently

> **USER**: Type exactly: `we need to store user passwords securely, what hashing should we use`

> **CLAUDE**: Check if the **Secrets Way** fired. Report what content appeared.

**Expected**: The secrets child way fires. Check metrics again — sibling_fired should now be 2/3.

---

### Step 5 — Documentation tree test

> **USER**: Type exactly: `add a mermaid diagram showing the request flow`

> **CLAUDE**: Check what fired. Did you get the Mermaid Way child, the docs root, or both?

**Expected**: The docs root (threshold 1.8) may fire on "diagram". The mermaid child (threshold 2.0, vocabulary: mermaid, diagram, flowchart, sequence) should also fire. You should see the diagram type selection table and the styling palette. Report whether both fired or just the child.

---

### Step 6 — Anti-rationalization in TDD

> **USER**: Type exactly: `use tdd to write this feature, tests first`

> **CLAUDE**: Check if the TDD Way fired with its anti-rationalization table. Report whether you see the "Common Rationalizations" section.

**Expected**: The TDD child way fires (threshold 2.5, vocabulary: tdd, red, green, refactor, test first). You should see:
- "## The Cycle" (Red-Green-Refactor)
- "## Common Rationalizations" table with 6 entries

---

## Part B: Think Strategy Activation

### Step 7 — Tree of Thoughts auto-detection

> **USER**: Type exactly: `we need to explore different approaches for the caching layer, there are several options to consider`

> **CLAUDE**: Check if a think strategy activated. Look for "Tree of Thoughts" in the additional context. Report:
1. Did it activate?
2. What stage was injected?
3. Was a state file created?

**Expected**: Tree of Thoughts activates automatically (keywords: explore, options, approaches, different). Stage 1 (Problem Reception) guidance should be injected. State file at `/tmp/.claude-think-{session_id}.json`.

---

### Step 8 — Think strategy stage advancement

> **USER**: Type exactly: `here are the three approaches I see: redis, memcached, or in-process LRU`

> **CLAUDE**: Check what stage guidance you received on this turn. Read the state file to confirm the stage advanced.

**Expected**: After Step 7's response, the Stop hook should have advanced to stage 2. This turn should inject Stage 2 (Approach Exploration) guidance. After this response, it should advance to stage 3.

---

### Step 9 — Think strategy cancellation

> **USER**: Type exactly: `skip that, let's just go with redis`

> **CLAUDE**: Check if the strategy was cancelled. Look for "Think strategy cancelled" in the context. Verify the state file was removed.

**Expected**: The cancellation detection fires ("skip that" matches cancel patterns). State file removed. No more strategy guidance on subsequent turns.

---

## Part C: Negative Tests

### Step 10 — No false positive on unrelated prompt

> **USER**: Type exactly: `how many legs does an octopus have?`

> **CLAUDE**: Check if any NEW domain-specific content was injected. Report what you see.

**Expected**: Nothing fires. No way matches, no think strategy matches.

---

### Step 11 — Think strategy doesn't re-activate after completion

> **CLAUDE**: Check if the done marker exists at `/tmp/.claude-think-done-{session_id}`. If so, test that a strategy-matching prompt doesn't re-activate:

> **USER**: Type exactly: `let's explore multiple options for the database schema`

**Expected**: If the done marker exists, the think strategy should NOT re-activate this session. If it was cancelled (not completed), the marker may not exist — in that case, it MAY re-activate, which is acceptable (cancellation is not completion).

---

## Part D: Summary

### Step 12 — Compile results

> **CLAUDE**: Compile a summary table:
>
> | Step | Test | Expected | Result |
> |------|------|----------|--------|
> | 1 | Security root fires | Root content, no children | ? |
> | 2 | Injection child fires | Detection table + anti-rationalization | ? |
> | 3 | Metrics tracking | Parent recorded, epoch distance, coverage | ? |
> | 4 | Sibling fires | Secrets way, coverage 2/3 | ? |
> | 5 | Docs tree | Mermaid child fires | ? |
> | 6 | TDD anti-rationalization | Rationalizations table present | ? |
> | 7 | Think auto-detection | Tree of Thoughts stage 1 | ? |
> | 8 | Think advancement | Stage progresses | ? |
> | 9 | Think cancellation | Strategy cancelled, state removed | ? |
> | 10 | Negative test | Nothing fires | ? |
> | 11 | No re-activation | Done marker prevents repeat | ? |
>
> Report pass/fail count and observations about:
> - Whether progressive disclosure trees deliver the right content at the right depth
> - Whether anti-rationalization tables appear at the expected specificity level
> - Whether think strategies activate, advance, and cancel correctly
> - Whether tree disclosure metrics capture parent-child relationships
