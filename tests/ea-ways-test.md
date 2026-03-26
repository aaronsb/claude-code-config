# Executive Assistant Ways Integration Test

## Instructions for Claude

Read this file with the Read tool — do NOT have the user paste it into chat.

You are running an integration test for the EA progressive disclosure tree. This test verifies that the correct EA ways fire for typical executive assistant prompts, that progressive disclosure works (parent before child), and that sibling ways don't crowd each other.

**Your role**: Follow each step in order. Announce what step you are on, perform the action, then report the result against the expected outcome. Wait for the user to complete each USER step before moving on.

**Format your reports as**:
```
Step N: [description]
Result: PASS / FAIL / UNEXPECTED
Detail: [what happened vs what was expected]
```

After reading this file, begin with Step 1.

---

## Part A: Root and Direct Children

### Step 1 — Root EA way fires on broad prompt

> **USER**: Type exactly: `I need help managing my workspace today`

> **CLAUDE**: Check if you received EA root content in a system-reminder. Look for safety rules table, account iteration pattern, and core principles (autonomy with guardrails, read-only by default, suggest never auto-execute). Report what fired.

**Expected**: The root EA way fires (threshold 1.8, vocabulary includes: assistant, workspace, manage). You should see the safety rules table and core principles — NOT email triage structure, drafting style guide, or calendar workflow specifics (those are children). Note: the prompt intentionally avoids mentioning specific domains (email, calendar) to prevent pre-firing child ways.

---

### Step 2 — Email triage child fires on triage prompt

> **USER**: Type exactly: `triage my email from the last 24 hours`

> **CLAUDE**: Check if you received email triage content. Look for the presentation structure table (Action Required, Already Addressed, Calendar Cross-Reference, etc.) and filtering rules. Report what fired.

**Expected**: The email triage way fires (threshold 2.0, vocabulary: triage, email, inbox, scan). You should see:
- "## Presentation Structure" table with section descriptions
- "## Filtering Rules" with filter-in and filter-out lists

The root EA way should NOT re-fire (marker exists from Step 1).

---

### Step 3 — Calendar fires on scheduling (not briefing)

> **USER**: Type exactly: `schedule a meeting with the team for tomorrow afternoon`

> **CLAUDE**: Check what fired. Did you get calendar content (scheduling workflow, availability checking, timezone defaults) or briefing content (morning summary, agent team coordination)? Report which way(s) fired.

**Expected**: The calendar way fires (threshold 2.0, vocabulary: schedule, meeting, calendar). You should see availability-check-first workflow and timezone guidance. The briefing way should NOT fire for a scheduling request — if it does, that's a vocabulary overlap issue.

---

### Step 4 — Comms fires on chat prompt

> **USER**: Type exactly: `check my teams chat for any unread messages`

> **CLAUDE**: Check if you received communications content. Look for the "Reading is Safe, Sending Requires Approval" section and chat triage guidance. Report what fired.

**Expected**: The comms way fires (threshold 2.0, vocabulary: teams, chat, unread, message). You should see the read-safe/send-approval distinction and the "As a Context Layer" section.

---

### Step 5 — Tasks fires on task management prompt

> **USER**: Type exactly: `what tasks are overdue and what should I prioritize`

> **CLAUDE**: Check if you received task lifecycle content. Look for the suggest-first patterns (creation, update, completion, cleanup) and cross-reference guidance. Report what fired.

**Expected**: The tasks way fires (threshold 2.0, vocabulary: task, overdue, priority, pending). You should see the four lifecycle patterns with example suggestion formats.

---

## Part B: Leaf Ways (Depth 2)

### Step 6 — Email drafting grandchild fires

> **USER**: Type exactly: `draft a reply to that email from the client`

> **CLAUDE**: Check if you received drafting-specific content. Look for style calibration guidance, anti-patterns list, and threading instructions. Report what fired.

**Expected**: The email/drafting way fires (threshold 2.5, vocabulary: draft, reply, compose, style, tone). You should see:
- "## Style Calibration" with observation checklist
- "## Anti-Patterns to Avoid" with AI-generated tells
- "## Iteration Rule" (don't re-create draft on every revision)

The email triage parent may or may not re-fire (depends on marker state). The drafting content is the important signal.

---

### Step 7 — Meeting recap fires on transcript prompt

> **USER**: Type exactly: `pull the transcript from yesterday's standup meeting`

> **CLAUDE**: Check if you received recap content. Look for the available content table (AI Summary, Transcripts, Notes, etc.) and cross-referencing guidance. Report what fired.

**Expected**: The comms/recap way fires (threshold 2.5, vocabulary: recap, transcript, summary, meeting). You should see:
- "## What's Available" table
- "## Using Transcripts" section
- "## Meeting Continuity" for recurring meetings

---

### Step 8 — Time tracking fires on EOD prompt

> **USER**: Type exactly: `log my time for today, I'm wrapping up`

> **CLAUDE**: Check if you received time tracking content. Look for the logging workflow steps and weekly time review section. Report what fired.

**Expected**: The tasks/time way fires (threshold 2.5, vocabulary: time, log, hours, billable, EOD, wrap up). You should see the 4-step logging workflow (review work → match clients → propose entries → log on approval).

---

## Part C: Differentiation Tests

These test that semantically close ways fire the RIGHT one, not the wrong sibling.

### Step 9 — Intelligence wins on meeting prep (not briefing)

> **USER**: Type exactly: `prepare me for my 2pm meeting with the client`

> **CLAUDE**: Check which way(s) fired. Did you get intelligence content (meeting prep workflow, cross-service data gathering) or briefing content (morning summary, agent team coordination)? Report which fired.

**Expected**: The intelligence way fires (description includes "prepare me for a meeting"). You should see the meeting prep checklist (calendar details, recent email threads, chat history, previous occurrence, shared documents, open tasks). The briefing way may also fire — if so, check whether intelligence scored higher (it should).

---

### Step 10 — Briefing wins on catch-me-up (not email triage)

> **USER**: Type exactly: `what does my day look like, catch me up`

> **CLAUDE**: Check which way(s) fired. Did you get briefing content (agent team coordination, scout roles, briefing structure) or email triage content? Report which fired.

**Expected**: The briefing way fires (description includes "catch me up", "what does my day look like"). You should see:
- "## Standard Roles" table (inbox-scout, ops-scout, lead)
- "## Briefing Structure" priority-ordered sections
- "## After the Briefing" task mutation suggestions

Email triage should NOT be the primary way for this prompt.

---

## Part D: Negative and Crowding Tests

### Step 11 — No false positive on unrelated prompt

> **USER**: Type exactly: `explain how the Rust borrow checker works`

> **CLAUDE**: Check if any EA ways fired. Report what you see.

**Expected**: No EA ways fire. This prompt has zero overlap with EA vocabulary. If an EA way fires, that's a false positive — report which one and its score.

---

### Step 12 — No cross-domain crowding with softwaredev

> **USER**: Type exactly: `review the code quality and refactor the authentication module`

> **CLAUDE**: Check if any EA ways fired alongside the expected softwaredev ways. Report all ways that fired.

**Expected**: Softwaredev ways should fire (code quality, possibly security). NO EA ways should fire — "review", "authentication", and "module" should not pull EA ways into a code review context.

---

## Part E: Summary

### Step 13 — Compile results

> **CLAUDE**: Compile a summary table:
>
> | Step | Test | Expected Winner | Result |
> |------|------|----------------|--------|
> | 1 | Root fires on broad prompt | ea/ (root) | ? |
> | 2 | Email triage child fires | ea/email | ? |
> | 3 | Calendar fires (not briefing) | ea/calendar | ? |
> | 4 | Comms fires on chat | ea/comms | ? |
> | 5 | Tasks fires on overdue | ea/tasks | ? |
> | 6 | Drafting grandchild fires | ea/email/drafting | ? |
> | 7 | Recap fires on transcript | ea/comms/recap | ? |
> | 8 | Time tracking fires on EOD | ea/tasks/time | ? |
> | 9 | Intelligence wins over briefing | ea/intelligence | ? |
> | 10 | Briefing wins on catch-me-up | ea/briefing | ? |
> | 11 | No false positive | Nothing fires | ? |
> | 12 | No cross-domain crowding | Softwaredev only | ? |
>
> Report pass/fail count and observations about:
> - Whether progressive disclosure delivers parent content before child content
> - Whether semantically close siblings (briefing vs calendar, briefing vs intelligence) differentiate correctly
> - Whether leaf ways (depth 2) fire at appropriate specificity without crowding parents
> - Whether EA ways stay silent during unrelated softwaredev workflows
