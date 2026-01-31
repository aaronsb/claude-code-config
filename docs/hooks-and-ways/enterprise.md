# Enterprise Operating Model Ways

Guidance for working with enterprise platforms as projections of operating models.

## Domain Scope

This covers the relationship between operating models and the platforms that implement them. Jira, Azure DevOps, Targetprocess, Confluence, SharePoint, ServiceNow, SAP - these are not the operating model. They are *projections* of it. The operating model is the source of truth: the structure of work, the flow of decisions, the boundaries of autonomy, the feedback loops. Platforms receive a mapping of that model into their own ontology.

This matters because consulting work crosses organizational boundaries. Every client has a different toolchain but the underlying operating model patterns repeat. When you understand the model, the tools become interchangeable projections.

## Theoretical Foundation

This domain draws from the Enterprise as Code framework, which treats operating models as versioned, executable artifacts rather than static documentation:

- **The operating model is the source of truth.** Everything else - org charts, process diagrams, tool configurations, reports - is a generated projection from that model.
- **Platforms impose their own ontology.** Jira thinks in issues and workflows. ADO thinks in work items and boards. Targetprocess thinks in entities and states. Each platform captures some of the operating model and loses some. The gap (the *kernel*, in mathematical terms) is what matters.
- **The quality of a projection is measurable.** Three properties: *signal* (how much strategic intent survives from leadership to execution), *autonomy* (whether units can operate or just take orders), and *latency* (speed of the friction-to-improvement feedback loop).
- **Frameworks are dependencies, not religions.** SAFe, ITIL, TBM, TOGAF - these are versioned inputs to an operating model, composable and overridable, not monolithic prescriptions.

## Principles

### Platforms are projections, not sources of truth

When configuring or integrating with enterprise tools, the first question is: what operating model is this projecting? The tool's data model, workflow states, and permission structure are a *mapping* from something more fundamental. Understand the source before optimizing the projection.

An organization that configures Jira to match how it works has a healthy projection. An organization that changes how it works to match Jira's defaults has inverted the relationship.

### The kernel tells you what's lost

Every mapping from operating model to platform erases something. Jira doesn't natively represent cost models. Confluence doesn't enforce process compliance. ServiceNow doesn't capture strategic intent. Understanding what each platform *can't* represent is as important as knowing what it can. The kernel is where shadow processes grow.

### Work items are state machines

Every work management system, regardless of vendor, models work as items moving through states. The specifics differ (Jira calls them statuses, ADO calls them states, Targetprocess calls them entity states) but the pattern is universal: backlog → active → review → done, with variations. Understanding the state machine matters more than understanding the UI.

### Knowledge bases decay without curation

Confluence spaces, SharePoint sites, and wikis accumulate stale content over time. Search quality degrades. New team members can't find what they need. Curation is a continuous practice, not a one-time setup. When building or integrating with knowledge systems, consider the maintenance burden.

### Integration connects projections through the model, not to each other

When connecting systems (work management to source control, knowledge base to CI/CD), the clean pattern is hub-and-spoke through the operating model, not point-to-point between platforms. Each platform maintains a valid mapping to the source of truth. Platforms don't need to know about each other - they only need their own mapping to be correct.

### Feedback loops close through version control

Friction detected in operations (bottlenecks, workarounds, signal loss) should trace back to a specific node in the operating model and produce a versioned change. The improvement cycle is: detect friction → locate in model → author change as PR → review → merge → deploy to platforms → measure. This is the algodonic channel - pain signals from the front line driving structural improvement.

---

## Ways

### operating-models

**Principle**: Understand the operating model before touching any platform. Platforms are projections.

**Triggers on**: Mentioning operating models, organizational design, enterprise architecture, or platform configuration at the structural level.

**Guidance direction**: Ask what the operating model looks like before configuring tools. Identify the entities (capabilities, teams, value streams), their relationships (dependencies, ownership, flow), and the constraints (approval gates, compliance requirements). Then evaluate how well the target platform can represent that structure. Name the gaps explicitly.

### work-management

**Principle**: Work management tools are state machines projecting an operating model's process stream.

**Triggers on**: Mentioning Jira, Azure DevOps, Targetprocess, Linear, Asana, or work item management patterns.

**Guidance direction**: Map the workflow states before writing code or configuration. Understand required fields, transitions, and permissions as reflections of the operating model's process stream. For integrations: use the tool's API. For migrations: export, transform, validate, then import - never in-place. When the tool's ontology can't represent something in the model, document it as a kernel gap rather than silently losing it.

### knowledge-bases

**Principle**: Knowledge systems are projections of the operating model's information architecture.

**Triggers on**: Mentioning Confluence, SharePoint, wikis, knowledge management, or documentation platforms.

**Guidance direction**: Structure should mirror the operating model's boundaries, not the platform's defaults. Template pages for consistency. Label/tag systematically. For content: link to authoritative sources rather than duplicating (duplication is how projections drift from the model). Archive rather than delete - the history has value.

### planning

**Principle**: Planning artifacts connect strategy to execution traceably. The hierarchy should reflect the operating model's decomposition.

**Triggers on**: Mentioning roadmaps, portfolio planning, program management, epics, or capacity planning.

**Guidance direction**: Hierarchy should be meaningful (epic → story → task reflects scope decomposition from the operating model, not bureaucratic layers). Estimates are communication tools, not contracts. Dependencies between teams should be explicit and tracked. Measure flow (cycle time, throughput) not activity (hours logged). Signal degradation through planning layers is the primary risk - measure it.

### assessments

**Principle**: Assessments measure the quality of the projection from operating model to operational reality.

**Triggers on**: Mentioning assessments, audits, maturity models, gap analysis, or readiness reviews.

**Guidance direction**: Use a consistent framework grounded in the three quality properties: signal (does intent survive?), autonomy (can units operate?), and latency (how fast is the feedback loop?). Score on a defined scale. Support every finding with evidence. The kernel analysis (what's lost in each platform projection) is the most valuable output. Deliverable format: structured HTML/PDF with executive summary, detailed findings, and appendices.
