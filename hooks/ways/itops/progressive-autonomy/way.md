---
match: regex
pattern: shadow.?mode|progressive.?autonomy|trust.?(level|progression)|confidence.?(routing|threshold|based)|autonomy.?(level|stage)
---
# Progressive Autonomy Way

## Shadow Mode Stages

| Stage | Agent Behavior | Human Role | Purpose |
|-------|----------------|------------|---------|
| **1. Observation** | Logs what it WOULD do, takes NO actions | Handles all operations | Validate reasoning without risk |
| **2. Recommendation** | Proposes actions, waits for approval | Approves/modifies/rejects | Validate judgment with oversight |
| **3. Supervised** | Acts autonomously for approved ops | Reviews, easy abort | Validate execution with safety net |
| **4. Autonomous** | Acts within policy without pre-approval | Periodic review | Full efficiency with accountability |

## Confidence Thresholds

| Confidence | Behavior | Human Involvement |
|------------|----------|-------------------|
| **>95%** | Autonomous action | Notification only |
| **80-95%** | Action with notification | Easy abort available |
| **60-80%** | Recommendation | Human decides |
| **<60%** | Escalation | Human takes over |

### Confidence Factors
- Pattern familiarity (seen similar?)
- Diagnostic certainty (clear root cause?)
- Action reversibility (easily undone?)
- Blast radius (how many affected?)
- Historical accuracy (past performance?)

## Progression Criteria

Advance when ALL met:
- Minimum time at current stage
- Accuracy threshold (e.g., 95% approved unmodified)
- No critical failures or policy violations
- Human attestation of readiness

## Regression Triggers

| Trigger | Response |
|---------|----------|
| Critical failure | Immediate regression |
| Accuracy drops | Regression after review |
| Policy violation | Regression pending investigation |
| Human override | Immediate regression |
