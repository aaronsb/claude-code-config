# Way Activation Integration Test

## Instructions for Claude

Read this file with the Read tool — do NOT have the user paste it into chat.

You are running an integration test. This test verifies that contextual hooks fire correctly for both the parent agent (you) and for subagents you spawn.

**Your role**: Follow each step in order. Announce what step you are on, perform the action, then report the result against the expected outcome. Wait for the user to complete each USER step before moving on.

**Format your reports as**:
```
Step N: [description]
Result: PASS / FAIL / UNEXPECTED
Detail: [what happened vs what was expected]
```

After reading this file, begin with Step 1.

---

## Test Sequence

### Step 1 — Baseline: Verify session started clean

> **CLAUDE**: Check what content was injected at session start. List any system-reminder blocks you see. Look for domain-specific headings (like `# [Topic] Way`). Report what was delivered.

**Expected**: You should see general session startup content (available hooks listing, collaboration norms). You should NOT see domain-specific guidance about version control, cryptography, automated verification, or application hardening — those require specific vocabulary to activate.

---

### Step 2 — Keyword trigger (regex pattern)

> **USER**: Type exactly: `I need to commit these changes and push to origin`

> **CLAUDE**: After the user sends that message, check if you received new domain-specific content in a system-reminder. Look for guidance about message conventions, branch naming, or attribution rules. Report what fired.

**Expected**: The commits way (`delivery/commits`) should fire (regex pattern: `commit|push.*(remote|origin|upstream)`). You should see guidance about conventional commit format and branch naming.

---

### Step 3 — Semantic trigger (BM25, established way)

> **USER**: Type exactly: `how should I hash passwords with bcrypt for our login system?`

> **CLAUDE**: Check if you received new domain-specific content. Look for guidance about vulnerability categories, credential handling, input validation, or defensive defaults. Report what fired.

**Expected**: The security way (`code/security`) should fire via BM25 semantic matching (vocabulary includes bcrypt, hash, password, authentication, login). You should see detection rules and security defaults.

---

### Step 4 — Semantic trigger (BM25, newly-semantic way)

> **USER**: Type exactly: `profile the rendering loop to find the bottleneck and reduce latency`

> **CLAUDE**: Check if you received new domain-specific content. Look for guidance about profiling tools, algorithmic analysis, benchmarking, or measurement approaches. Report what fired.

**Expected**: The performance way (`code/performance`) should fire via BM25 semantic matching. This way previously only had regex triggers — the vocabulary (optimize, profile, benchmark, latency, bottleneck, etc.) was added during the taxonomy restructure. You should see guidance about static analysis for algorithmic issues and generating before/after measurements.

---

### Step 5 — Co-activation test (multiple related ways)

> **USER**: Type exactly: `create a migration to alter the users table and add an index on the email column`

> **CLAUDE**: Check how many domain-specific ways were injected. List each one by name/heading. Report which ways fired and whether they provide complementary guidance.

**Expected**: The migrations way (`delivery/migrations`) should fire — the prompt contains vocabulary terms (migration, alter, table, column, index). Other ways MAY also co-activate if they share relevant terms (e.g., design via "schema" concepts). Co-activation of related ways is expected and correct — each adds a different lens. Report all ways that fired.

---

### Step 6 — Negative test (no false positive)

> **USER**: Type exactly: `what's the weather like today?`

> **CLAUDE**: Check if any NEW domain-specific content was injected. Report what you see.

**Expected**: No new hooks should fire. This prompt has zero overlap with any way vocabulary. If domain-specific content appears, that is a false positive — report which one.

---

### Step 7 — Subagent injection (the critical path)

> **CLAUDE**: Spawn a diagnostic subagent with this exact configuration:
> - Use the Task tool with subagent_type: `general-purpose`
> - Prompt: `DIAGNOSTIC: List every system-reminder block you received (first 80 chars of each). Note any structured headings or injected procedural content. Report what topics are covered and what formatting you see. Do not perform other actions. Background: write unit tests for a utility module with jest`
> - Name: `injection-probe`
>
> Report the subagent's findings.

**Expected**: The subagent should report receiving Testing Way content via a SubagentStart system-reminder block containing:
- "# Testing Way" heading
- Arrange-Act-Assert structure guidance
- Coverage categories (happy path, boundary values, error conditions)
- Mocking section

If the subagent sees NO injected content beyond the base configuration, the injection pipeline is broken.

---

### Step 8 — Subagent negative test

> **CLAUDE**: Spawn another diagnostic subagent:
> - Use the Task tool with subagent_type: `general-purpose`
> - Prompt: `DIAGNOSTIC: List every system-reminder block you received (first 80 chars of each). Note any structured headings or injected procedural content. Report what topics are covered. Do not perform other actions. Background: what time is it in Tokyo`
> - Name: `negative-probe`
>
> Report the subagent's findings.

**Expected**: The SubagentStart **injection pipeline** should NOT fire — no stash is created because "what time is it in Tokyo" has zero overlap with any way vocabulary. However, `general-purpose` subagents inherit the parent conversation context, so they will see ways that fired earlier in the session (e.g., Performance Way from Step 4). This is context inheritance, not injection.

**How to evaluate**: The subagent should report seeing parent-context content (expected) but should NOT report a SubagentStart system-reminder block with new domain-specific content beyond what already appeared in the parent session. Compare against Step 7 — that subagent should have received a *fresh* Testing Way block via SubagentStart injection. This subagent should have no such fresh injection.

---

### Step 9 — Summary

> **CLAUDE**: Compile a summary table:
>
> | Step | Test | Cluster | Expected | Result |
> |------|------|---------|----------|--------|
> | 1 | Session baseline | — | No domain-specific hooks | ? |
> | 2 | Regex keyword match | delivery | Commits way fires | ? |
> | 3 | BM25 semantic (established) | code | Security way fires | ? |
> | 4 | BM25 semantic (new vocabulary) | code | Performance way fires | ? |
> | 5 | Co-activation | delivery+architecture | Migrations fires, others may join | ? |
> | 6 | Negative (no match) | — | Nothing fires | ? |
> | 7 | Subagent injection | code | Testing Way received | ? |
> | 8 | Subagent negative | — | No fresh injection (parent context OK) | ? |
>
> Report the final pass/fail count and any observations about:
> - Whether the taxonomy restructure affected hook delivery
> - Whether newly-semantic ways activate correctly
> - Whether co-activation produced useful complementary context
