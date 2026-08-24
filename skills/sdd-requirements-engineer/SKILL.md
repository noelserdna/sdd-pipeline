---
name: sdd-requirements-engineer
description: "Professional software requirements engineering assistant based on SWEBOK v4. Use this skill when: (1) Eliciting or gathering software requirements from stakeholders, (2) Writing or formatting requirements (user stories, use cases, BDD scenarios), (3) Auditing or reviewing requirements for quality (ambiguity, testability, completeness, consistency), (4) Analyzing and prioritizing requirements, (5) Creating requirements specification documents, (6) Managing requirements changes and traceability. Triggers on phrases like 'gather requirements', 'write requirements', 'review requirements', 'audit requirements', 'user stories', 'use cases', 'acceptance criteria', 'requirements specification', 'requirements quality'."
---

# Requirements Engineer (SWEBOK v4)

Professional requirements engineering skill based on IEEE SWEBOK v4 Chapter 1: Software Requirements.

## Modes of Operation

This skill operates in three modes. Determine which mode based on user intent:

### Mode 1: Elicit Requirements

Use when the user wants help gathering, discovering, or creating requirements for a project.

1. Read [references/elicitation-guide.md](references/elicitation-guide.md) for the full elicitation workflow
2. Ask the user about the project context: what problem is being solved, who are the stakeholders, what constraints exist
3. Guide the user through stakeholder identification
4. Help select appropriate elicitation techniques
5. For each requirement surfaced, apply the 5-Whys to ensure it represents the true need, not a premature solution
6. Categorize each requirement: functional (policies/processes) vs. nonfunctional (technology constraints / quality of service)
7. Write requirements using the appropriate specification format (see Specification Formats below)
8. Track additional attributes: source, priority, rationale, acceptance criteria

### Mode 2: Audit Requirements

Use when the user provides existing requirements for review/quality assessment.

1. Read [references/audit-checklist.md](references/audit-checklist.md) for the complete audit framework
2. Evaluate EACH requirement against the individual checklist (ambiguity, testability, atomicity, necessity, completeness)
3. Evaluate the COLLECTION against the collection checklist (completeness, consistency, feasibility)
4. Produce an audit report with severity levels: FAIL (must fix), WARN (should fix), PASS
5. For each issue found, provide a specific, actionable recommendation with a rewritten version when possible
6. Identify gaps: missing stakeholder perspectives, uncovered edge cases, absent security/error handling

### Mode 3: Specify/Format Requirements

Use when the user wants help writing requirements in a specific format or converting between formats.

Choose the format based on context:

**User Story**: `As a [role] I want [capability] so that [benefit]`
- Best for: Agile teams, feature-level requirements
- Always add acceptance criteria in BDD format

**BDD Scenario**: `Given [context], when [stimulus], then [outcome]`
- Best for: precise, testable acceptance criteria
- Ensure comprehensive scenarios: normal, alternative, exception paths

**Use Case**: structured template with triggering event, parameters, preconditions, postconditions, normal/alternative courses, exceptions
- Best for: complex workflows, system interactions

**Actor-Action**: `[Triggering event], [Actor] shall [Action] [Condition]`
- Best for: formal specification documents, contractual requirements

**Shall Statement**: `The system shall [behavior]`
- Best for: traditional SRS documents, regulatory contexts

## Key Principles (Always Apply)

### The Perfect Technology Filter
Separate functional from nonfunctional: functional requirements would still exist even if infinite computing resources were available. Everything else is nonfunctional.

### Requirement Quality Gates
Every requirement must be: unambiguous, testable, atomic, binding, stakeholder-aligned. If not, flag and fix.

### Forbidden Words in Requirements
Flag these vague terms: "fast", "user-friendly", "efficient", "flexible", "robust", "easy", "intuitive", "seamless", "adequate", "reasonable", "appropriate", "etc.", "and/or", "if applicable", "as needed", "simple", "quickly".

### Prioritization (Kano-aware)
Consider BOTH satisfaction from having a feature AND dissatisfaction from lacking it. A missing basic feature causes more damage than a missing delighter.

Priority scales: Must have / Should have / Nice to have, or numerical 1-10.

## EARS Syntax (Preferred for SDD Pipeline)

When operating within the SDD pipeline, use EARS (Easy Approach to Requirements Syntax) as the primary format. This ensures compatibility with downstream skills (`sdd-specifications-engineer`, `sdd-spec-auditor`, etc.):

| Pattern | Template | Example |
|---------|----------|---------|
| Ubiquitous | `THE <system> SHALL <behavior>` | THE system SHALL store all data encrypted at rest |
| Event-driven | `WHEN <trigger> THE <system> SHALL <behavior>` | WHEN a user submits login credentials THE system SHALL validate them within 2 seconds |
| State-driven | `WHILE <state> THE <system> SHALL <behavior>` | WHILE the system is in maintenance mode THE system SHALL reject all write operations |
| Unwanted | `IF <condition> THEN THE <system> SHALL <behavior>` | IF the database connection fails THEN THE system SHALL retry 3 times with exponential backoff |
| Optional | `WHERE <feature> THE <system> SHALL <behavior>` | WHERE multi-tenancy is enabled THE system SHALL isolate tenant data |
| Complex | `WHILE <state> WHEN <trigger> THE <system> SHALL <behavior>` | WHILE authenticated WHEN session expires THE system SHALL redirect to login |

## Output Artifacts

### Primary Output: `requirements/REQUIREMENTS.md`

All modes MUST produce or update a structured requirements document at `requirements/REQUIREMENTS.md` with this format:

```markdown
# Requirements Document

> **Project:** {project name}
> **Version:** {X.Y}
> **Last updated:** {YYYY-MM-DD}
> **Status:** Draft | Review | Approved

## Functional Requirements

### REQ-F-001: {Title}
- **Statement:** WHEN {trigger} THE {system} SHALL {behavior}
- **Category:** Functional
- **Priority:** Must have | Should have | Nice to have
- **Source:** {stakeholder or document}
- **Rationale:** {why this requirement exists}
- **Acceptance criteria:**
  - GIVEN {context} WHEN {action} THEN {outcome}
  - GIVEN {context} WHEN {action} THEN {outcome}
- **Dependencies:** {REQ-F-NNN, or "None"}

### REQ-F-002: {Title}
...

## Nonfunctional Requirements

### REQ-NF-001: {Title}
- **Statement:** THE {system} SHALL {behavior} {quantified constraint}
- **Category:** Performance | Security | Scalability | Availability | Usability
- **Priority:** Must have | Should have | Nice to have
- **Metric:** {measurable target, e.g., "p99 < 200ms"}
- **Acceptance criteria:**
  - GIVEN {load condition} WHEN {action} THEN {measurable outcome}

## Constraints

### REQ-C-001: {Title}
- **Statement:** {constraint description}
- **Type:** Technical | Business | Regulatory
- **Source:** {origin of constraint}

## Traceability

| REQ ID | Type | Priority | Source | Acceptance Criteria |
|--------|------|----------|--------|---------------------|
| REQ-F-001 | Functional | Must | {source} | Yes |
| REQ-NF-001 | Nonfunctional | Must | {source} | Yes |
```

### Rules for Output
1. **Every requirement gets a unique ID** with prefix: `REQ-F-` (functional), `REQ-NF-` (nonfunctional), `REQ-C-` (constraint)
2. **Every requirement has acceptance criteria** in BDD format (Given/When/Then)
3. **Every requirement uses EARS syntax** for the statement
4. **No vague terms** — all metrics must be quantified
5. **Traceability table** at the end summarizes all requirements

## Pipeline Integration

This skill is **Step 1** of the SDD pipeline:

```
sdd-requirements-engineer → requirements/REQUIREMENTS.md
        ↓
sdd-specifications-engineer → spec/ (reads REQUIREMENTS.md as input)
        ↓
sdd-spec-auditor → audits/AUDIT-BASELINE.md
        ↓
...
```

**Next step:** After generating `requirements/REQUIREMENTS.md`, tell the user:
> "Requirements document generated. Next step: run `sdd-specifications-engineer` to transform these requirements into formal technical specifications."

## Deep Reference

For detailed SWEBOK knowledge on categories, analysis, economics, tracing, management: read [references/swebok-requirements-knowledge.md](references/swebok-requirements-knowledge.md).

## Persist Summary

After generating all output artifacts, update `pipeline-state.json`:

1. Read `pipeline-state.json` from project root (create if absent with default stage structure)
2. Set `stages["requirements-engineer"].status` = `"done"`
3. Set `stages["requirements-engineer"].lastRun` = current ISO-8601
4. Set `stages["requirements-engineer"].summary`:
   - `artifacts`: list of files created/modified with labels (e.g., `{"file": "requirements/REQUIREMENTS.md", "label": "Requirements Document"}`)
   - `metrics`: `{ "total_requirements": N, "functional": N, "nonfunctional": N, "constraints": N }`
   - `highlights`: top 3-5 notable observations (e.g., "85 requirements across 6 domains", "12 security requirements identified")
   - `nextStep`: `"Run /sdd-specifications-engineer"`
   - `generatedAt`: current ISO-8601
5. Write updated `pipeline-state.json`
6. Display summary table to user (console output)
7. Handoff: follow the plugin-root `references/handoff-protocol.md` (only in station mode; never from a subagent).

## Output Language

Respond in the same language the user uses. If the user writes in Spanish, respond in Spanish. If in English, respond in English.
