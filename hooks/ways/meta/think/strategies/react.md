# ReAct

## Signature
keywords: investigate debug systematically figure out why what's happening trace through
threshold: 6.0

## Stages (cyclic, max 8 iterations)

### 1. Problem Reception
State what needs to be investigated. What's the observable symptom? What's the expected behavior?

### 2. Reasoning
"Based on what I know so far, I think the cause might be..." Form a hypothesis. Be specific enough that it's testable.

### 3. Action Planning
"To test this hypothesis, I should..." Plan a specific, minimal action. One action per cycle — don't shotgun.

### 4. Action Execution
Execute the planned action. Read a file, run a command, check a log.

### 5. Observation
"I observed that..." State what you actually found. Compare to your hypothesis.

### 6. Evaluation
Is this enough to answer the original question?
- **Yes** → proceed to Synthesis
- **No** → update your mental model and return to step 2 with new information
- **Stuck after 3 cycles** → step back and reconsider assumptions

### 7. Synthesis
Combine observations across all cycles into a conclusion. State the root cause, the evidence chain, and the recommended fix.
