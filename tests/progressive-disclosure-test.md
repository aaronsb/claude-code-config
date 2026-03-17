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

## Part B: Think Strategy Way

### Step 7 — Think Strategies way fires on reasoning prompt

> **USER**: Type exactly: `we need to explore different approaches for the caching layer, there are several options to consider`

> **CLAUDE**: Check if the Think Strategies way fired. Look for "# Think Strategies" heading with the strategy selection table. Report:
1. Did the way fire?
2. Is the strategy table present (tree-of-thoughts, trilemma, etc.)?

**Expected**: The Think Strategies way fires (vocabulary: explore, options, approaches, trade-off, balance, alternatives). You should see a table of available strategy skills and guidance on when to use each one. No auto-activation of a specific strategy — the way provides the menu, Claude or the user selects.

---

### Step 8 — Think strategy does NOT auto-activate

> **CLAUDE**: Verify that no think strategy state file was created. The way+skills architecture does not auto-activate — it presents options.

```bash
ls /tmp/.claude-think-*.json 2>/dev/null
```

**Expected**: No state file exists. The way fires as guidance; specific strategies are invoked via skill (e.g., `/think-tree`).

---

### Step 9 — Think strategy way is session-gated

> **USER**: Type exactly: `what are the trade-offs between the three options`

> **CLAUDE**: Check if the Think Strategies way fires again on this related prompt.

**Expected**: The way does NOT re-fire (marker exists from Step 7). This is correct — the way fires once per session. If the user wants a specific strategy, they invoke the skill directly.

---

## Part C: Negative Tests

### Step 10 — No false positive on unrelated prompt

> **USER**: Type exactly: `how many legs does an octopus have?`

> **CLAUDE**: Check if any NEW domain-specific content was injected. Report what you see.

**Expected**: Nothing fires. No way matches, no think strategy matches.

---

### Step 11 — Way does not re-fire on related prompt

> **USER**: Type exactly: `let's explore multiple options for the database schema`

> **CLAUDE**: Check if the Think Strategies way fires again.

**Expected**: The way does NOT re-fire (already fired in Step 7, marker exists). Other ways may fire (design, migrations) but the Think Strategies way should be silent.

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
> | 7 | Think way fires | Strategy menu injected | ? |
> | 8 | No auto-activation | No state file created | ? |
> | 9 | Think way session-gated | Way does not re-fire | ? |
> | 10 | Negative test | Nothing fires | ? |
> | 11 | Way does not re-fire | Marker prevents repeat | ? |
>
> Report pass/fail count and observations about:
> - Whether progressive disclosure trees deliver the right content at the right depth
> - Whether anti-rationalization tables appear at the expected specificity level
> - Whether the think strategies way fires and is session-gated correctly
> - Whether tree disclosure metrics capture parent-child relationships
