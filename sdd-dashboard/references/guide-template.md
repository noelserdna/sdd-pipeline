# SDD System Guide Template

Self-contained HTML guide for the SDD system and dashboard interpretation. Generated alongside `index.html` by the dashboard skill. No data injection needed — this is static documentation.

## Template

```html
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>SDD System Guide</title>
<style>
*,*::before,*::after{box-sizing:border-box;margin:0;padding:0}
:root{
  --bg:#0f1117;--surface:#1a1d27;--surface2:#242837;--surface3:#2e3348;--border:#2e3348;
  --text:#e4e7f1;--text2:#a0a4be;--text3:#8890a0;--accent:#6c8cff;--accent2:#4a6aef;
  --green:#34d399;--yellow:#f5c542;--red:#f87171;--orange:#fb923c;--gray:#8890a0;
  --purple:#a78bfa;--cyan:#22d3ee;--pink:#f472b6;--lime:#a3e635;
  --font:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,sans-serif;
  --mono:'SF Mono',Consolas,'Courier New',monospace;
  --radius:8px;
}
body{font-family:var(--font);background:var(--bg);color:var(--text);line-height:1.6;overflow-x:hidden}
a{color:var(--accent);text-decoration:none}
a:hover{text-decoration:underline}

/* Layout */
.guide-layout{display:flex;min-height:100vh}
.sidebar{width:260px;background:var(--surface);border-right:1px solid var(--border);position:sticky;top:0;height:100vh;overflow-y:auto;flex-shrink:0;padding:20px 0}
.sidebar-header{padding:0 20px 16px;border-bottom:1px solid var(--border);margin-bottom:12px}
.sidebar-header h2{font-size:16px;font-weight:700}
.sidebar-header h2 span{color:var(--accent)}
.sidebar-back{display:block;font-size:12px;color:var(--text2);margin-top:8px;text-decoration:none}
.sidebar-back:hover{color:var(--accent);text-decoration:none}
.sidebar-section{padding:8px 20px 4px;font-size:10px;text-transform:uppercase;letter-spacing:1px;color:var(--text3);font-weight:700}
.sidebar-link{display:block;padding:6px 20px;font-size:13px;color:var(--text2);text-decoration:none;border-left:2px solid transparent;transition:all .15s}
.sidebar-link:hover{color:var(--text);background:var(--surface2);text-decoration:none}
.sidebar-link.active{color:var(--accent);border-left-color:var(--accent);background:var(--surface2)}
.sidebar-link.sub{padding-left:36px;font-size:12px}

/* Main content */
.main{flex:1;max-width:860px;padding:40px 48px 80px;margin:0 auto}
.main h1{font-size:28px;font-weight:800;margin-bottom:8px}
.main h1 span{color:var(--accent)}
.main .subtitle{font-size:15px;color:var(--text2);margin-bottom:40px}
.main h2{font-size:22px;font-weight:700;margin-top:48px;margin-bottom:16px;padding-bottom:8px;border-bottom:1px solid var(--border)}
.main h3{font-size:17px;font-weight:600;margin-top:32px;margin-bottom:12px;color:var(--text)}
.main h4{font-size:14px;font-weight:600;margin-top:24px;margin-bottom:8px;color:var(--text2)}
.main p{margin-bottom:14px;color:var(--text2);font-size:14px}
.main ul,.main ol{margin-bottom:14px;padding-left:24px;color:var(--text2);font-size:14px}
.main li{margin-bottom:6px}
.main strong{color:var(--text);font-weight:600}
.main code{font-family:var(--mono);font-size:12px;background:var(--surface2);padding:2px 6px;border-radius:4px;color:var(--accent)}

/* Pipeline flow diagram */
.pipeline-flow{display:flex;flex-wrap:wrap;gap:8px;align-items:center;margin:20px 0;padding:16px;background:var(--surface);border:1px solid var(--border);border-radius:var(--radius)}
.pf-step{padding:8px 14px;border-radius:var(--radius);font-size:12px;font-weight:600;text-align:center;min-width:100px}
.pf-step.core{background:#162e23;color:var(--green);border:1px solid #1e4030}
.pf-step.lateral{background:#2e162e;color:var(--purple);border:1px solid #3e2040}
.pf-step.utility{background:#1a2e3a;color:var(--cyan);border:1px solid #204050}
.pf-arrow{color:var(--text3);font-size:14px;flex-shrink:0}
.pf-label{width:100%;font-size:10px;text-transform:uppercase;letter-spacing:1px;color:var(--text3);margin-top:8px;font-weight:600}

/* Info cards */
.info-card{background:var(--surface);border:1px solid var(--border);border-radius:var(--radius);padding:16px;margin:16px 0}
.info-card h4{margin-top:0;margin-bottom:8px;color:var(--text);font-size:14px}
.info-card p{margin-bottom:8px;font-size:13px}
.info-card p:last-child{margin-bottom:0}

/* Traceability chain */
.trace-chain{display:flex;flex-wrap:wrap;gap:4px;align-items:center;margin:16px 0;padding:16px;background:var(--surface);border:1px solid var(--border);border-radius:var(--radius)}
.tc-node{padding:6px 12px;border-radius:var(--radius);font-size:12px;font-weight:600;font-family:var(--mono);background:var(--surface2);border:1px solid var(--border);color:var(--accent)}
.tc-arrow{color:var(--text3);font-size:12px}

/* Metric table */
.metric-table{width:100%;border-collapse:collapse;margin:16px 0;font-size:13px}
.metric-table th{background:var(--surface2);color:var(--text2);padding:8px 12px;text-align:left;font-size:11px;text-transform:uppercase;letter-spacing:.5px;border-bottom:2px solid var(--border)}
.metric-table td{padding:8px 12px;border-bottom:1px solid var(--border);vertical-align:top}
.metric-table tr:hover td{background:var(--surface)}

/* Color swatches */
.swatch{display:inline-flex;align-items:center;gap:6px;margin:4px 0}
.swatch-dot{width:12px;height:12px;border-radius:50%;flex-shrink:0}
.swatch-label{font-size:13px}

/* Grade scale */
.grade-scale{display:flex;gap:8px;margin:16px 0;flex-wrap:wrap}
.grade-item{padding:8px 16px;border-radius:var(--radius);text-align:center;min-width:80px;background:var(--surface);border:1px solid var(--border)}
.grade-letter{font-size:24px;font-weight:800}
.grade-range{font-size:11px;color:var(--text2);margin-top:2px}
.grade-label{font-size:11px;margin-top:2px}

/* Glossary */
.glossary-grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(200px,1fr));gap:8px;margin:16px 0}
.glossary-item{padding:8px 12px;background:var(--surface);border:1px solid var(--border);border-radius:var(--radius)}
.glossary-abbr{font-family:var(--mono);font-weight:700;color:var(--accent);font-size:13px}
.glossary-def{font-size:12px;color:var(--text2);margin-top:2px}

/* Screenshot placeholder */
.screenshot{background:var(--surface);border:1px solid var(--border);border-radius:var(--radius);padding:24px;text-align:center;color:var(--text3);font-size:13px;margin:16px 0}

/* Responsive */
@media(max-width:768px){
  .sidebar{display:none}
  .main{padding:24px 16px 60px}
  .pipeline-flow{flex-direction:column}
  .pf-arrow{transform:rotate(90deg)}
  .trace-chain{flex-direction:column}
  .tc-arrow{transform:rotate(90deg)}
  .grade-scale{flex-direction:column}
}
</style>
</head>
<body>

<div class="guide-layout">

<!-- Sidebar Navigation -->
<nav class="sidebar">
  <div class="sidebar-header">
    <h2><span>SDD</span> Guide</h2>
    <a href="index.html" class="sidebar-back">&larr; Back to Dashboard</a>
  </div>

  <div class="sidebar-section">Part 1: The SDD System</div>
  <a href="#what-is-sdd" class="sidebar-link">What is SDD?</a>
  <a href="#the-pipeline" class="sidebar-link">The Pipeline</a>
  <a href="#pipeline-requirements" class="sidebar-link sub">Requirements Engineer</a>
  <a href="#pipeline-specifications" class="sidebar-link sub">Specifications Engineer</a>
  <a href="#pipeline-auditor" class="sidebar-link sub">Spec Auditor</a>
  <a href="#pipeline-test-planner" class="sidebar-link sub">Test Planner</a>
  <a href="#pipeline-plan-architect" class="sidebar-link sub">Plan Architect</a>
  <a href="#pipeline-task-generator" class="sidebar-link sub">Task Generator</a>
  <a href="#pipeline-task-implementer" class="sidebar-link sub">Task Implementer</a>
  <a href="#pipeline-security" class="sidebar-link sub">Security Auditor</a>
  <a href="#pipeline-req-change" class="sidebar-link sub">Req Change</a>
  <a href="#traceability-chain" class="sidebar-link">Traceability Chain</a>
  <a href="#automation" class="sidebar-link">Automation</a>
  <a href="#utility-skills" class="sidebar-link">Utility Skills</a>

  <div class="sidebar-section">Part 2: Adopting SDD</div>
  <a href="#when-to-onboard" class="sidebar-link">When to Onboard</a>
  <a href="#project-scenarios" class="sidebar-link">Project Scenarios</a>
  <a href="#skill-onboarding" class="sidebar-link sub">sdd:onboarding</a>
  <a href="#skill-reverse-engineer" class="sidebar-link sub">sdd:reverse-engineer</a>
  <a href="#skill-reconcile" class="sidebar-link sub">sdd:reconcile</a>
  <a href="#skill-import" class="sidebar-link sub">sdd:import</a>

  <div class="sidebar-section">Part 3: Reading the Dashboard</div>
  <a href="#dashboard-header" class="sidebar-link">Header &amp; Pipeline Bar</a>
  <a href="#dashboard-stats" class="sidebar-link">Stats Cards</a>
  <a href="#dashboard-health" class="sidebar-link">Health Score</a>
  <a href="#dashboard-colors" class="sidebar-link">Color Legend</a>
  <a href="#view-summary" class="sidebar-link">Summary View</a>
  <a href="#view-matrix" class="sidebar-link">Matrix View</a>
  <a href="#view-classification" class="sidebar-link">Classification View</a>
  <a href="#view-coverage" class="sidebar-link">Code Coverage View</a>
  <a href="#view-adoption" class="sidebar-link">Adoption View</a>
  <a href="#detail-panel" class="sidebar-link">Detail Panel</a>
  <a href="#health-formula" class="sidebar-link">Health Score Formula</a>
  <a href="#glossary" class="sidebar-link">Glossary</a>
</nav>

<!-- Main Content -->
<main class="main">

<h1><span>SDD</span> System Guide</h1>
<p class="subtitle">Complete documentation for the Specification-Driven Development pipeline and dashboard interpretation.</p>

<!-- ============================================================ -->
<!-- PART 1: THE SDD SYSTEM                                        -->
<!-- ============================================================ -->

<h2 id="what-is-sdd">What is SDD?</h2>

<p><strong>Specification-Driven Development (SDD)</strong> is a structured methodology that bridges the gap between what a system should do (requirements) and how it gets built (code). Based on <strong>SWEBOK v4</strong> (Software Engineering Body of Knowledge), SDD ensures that every piece of code traces back to a formal requirement through a chain of specifications, plans, and tasks.</p>

<p>The SDD system is implemented as a set of <strong>Claude Code skills</strong> — specialized AI assistants that generate and maintain engineering artifacts. Each skill handles one stage of the pipeline, reading artifacts from the previous stage and producing artifacts for the next.</p>

<div class="info-card">
  <h4>Why SDD?</h4>
  <p>Traditional development often loses traceability between requirements and code. SDD maintains a <strong>continuous chain</strong> from initial requirements through specifications, tests, plans, tasks, and finally code — so you always know <em>why</em> a piece of code exists and <em>what requirement</em> it satisfies.</p>
</div>


<h2 id="the-pipeline">The Pipeline</h2>

<p>The SDD pipeline consists of <strong>19 skills</strong> (9 pipeline + 4 onboarding + 5 utility + 1 setup). Each skill reads the output of previous stages, applies engineering discipline, and produces formal artifacts.</p>

<div class="pipeline-flow">
  <span class="pf-label">Linear Pipeline (execute in order)</span>
  <div class="pf-step core">1. Requirements<br>Engineer</div>
  <span class="pf-arrow">&rarr;</span>
  <div class="pf-step core">2. Specifications<br>Engineer</div>
  <span class="pf-arrow">&rarr;</span>
  <div class="pf-step core">3. Spec<br>Auditor</div>
  <span class="pf-arrow">&rarr;</span>
  <div class="pf-step core">4. Test<br>Planner</div>
  <span class="pf-arrow">&rarr;</span>
  <div class="pf-step core">5. Plan<br>Architect</div>
  <span class="pf-arrow">&rarr;</span>
  <div class="pf-step core">6. Task<br>Generator</div>
  <span class="pf-arrow">&rarr;</span>
  <div class="pf-step core">7. Task<br>Implementer</div>

  <span class="pf-label">Lateral Skills (invoke anytime)</span>
  <div class="pf-step lateral">8. Security Auditor</div>
  <div class="pf-step lateral">9. Req Change</div>
</div>


<h3 id="pipeline-requirements">1. Requirements Engineer</h3>
<p>Elicits, structures, and formalizes software requirements from stakeholder input using <strong>EARS syntax</strong> (Easy Approach to Requirements Syntax).</p>
<div class="info-card">
  <h4>Output</h4>
  <p><code>requirements/REQUIREMENTS.md</code> — Structured requirements document with IDs like <code>REQ-EXT-001</code>, prioritized using MoSCoW (Must/Should/Could/Won't).</p>
  <h4>EARS Pattern</h4>
  <p><code>WHEN &lt;trigger&gt; THE &lt;system&gt; SHALL &lt;behavior&gt;</code></p>
</div>

<h3 id="pipeline-specifications">2. Specifications Engineer</h3>
<p>Transforms requirements into formal technical specifications: use cases, workflows, API contracts, invariants, and architecture decision records.</p>
<div class="info-card">
  <h4>Output</h4>
  <p><code>spec/</code> directory containing:</p>
  <ul>
    <li><strong>Use Cases</strong> (<code>UC-*</code>) — Functional scenarios implementing requirements</li>
    <li><strong>Workflows</strong> (<code>WF-*</code>) — Process orchestrations and state machines</li>
    <li><strong>API Contracts</strong> (<code>API-*</code>) — Endpoint definitions with request/response schemas</li>
    <li><strong>Invariants</strong> (<code>INV-*</code>) — Business rules that must always hold true</li>
    <li><strong>ADRs</strong> (<code>ADR-*</code>) — Architecture Decision Records documenting design choices</li>
    <li><strong>BDD Scenarios</strong> (<code>BDD-*</code>) — Behavior-Driven Development acceptance criteria in Gherkin</li>
    <li><strong>NFRs</strong> (<code>NFR-*</code>) — Non-Functional Requirements (performance, security, etc.)</li>
  </ul>
</div>

<h3 id="pipeline-auditor">3. Spec Auditor</h3>
<p>Performs systematic cross-document analysis to detect defects in specifications: ambiguities, contradictions, dangerous silences, and incomplete coverage.</p>
<div class="info-card">
  <h4>Two Modes</h4>
  <p><strong>Mode Audit:</strong> Creates <code>audits/AUDIT-BASELINE.md</code> with categorized findings (P0 critical to P3 cosmetic).</p>
  <p><strong>Mode Fix:</strong> Applies corrections to <code>spec/</code> documents based on audit findings, with before/after tracking.</p>
</div>

<h3 id="pipeline-test-planner">4. Test Planner</h3>
<p>Generates comprehensive test strategies from specifications following <strong>SWEBOK v4 Chapter 04</strong> (Software Testing).</p>
<div class="info-card">
  <h4>Output</h4>
  <ul>
    <li><code>test/TEST-PLAN.md</code> — Overall test strategy and approach</li>
    <li><code>test/TEST-MATRIX-*.md</code> — Test case matrices mapping tests to requirements</li>
    <li><code>test/PERF-SCENARIOS.md</code> — Performance test scenarios with load profiles</li>
  </ul>
</div>

<h3 id="pipeline-plan-architect">5. Plan Architect</h3>
<p>Creates implementation plans that bridge specifications and code. Decomposes the system into ordered phases (FASEs) with dependency tracking.</p>
<div class="info-card">
  <h4>Output</h4>
  <ul>
    <li><code>plan/PLAN.md</code> — Master implementation plan</li>
    <li><code>plan/ARCHITECTURE.md</code> — C4-model architecture diagrams</li>
    <li><code>plan/fases/FASE-*.md</code> — Individual phase definitions with specs-to-read lists</li>
  </ul>
</div>

<h3 id="pipeline-task-generator">6. Task Generator</h3>
<p>Decomposes each FASE into atomic, reversible tasks with conventional commit messages and traceability to specs.</p>
<div class="info-card">
  <h4>Output</h4>
  <p><code>task/TASK-FASE-*.md</code> — Task documents with:</p>
  <ul>
    <li>One task = one commit (Conventional Commits format)</li>
    <li>Revert strategy per task (SAFE, COUPLED, MIGRATION, CONFIG)</li>
    <li>Parallel execution markers (which tasks can run concurrently)</li>
    <li><code>Refs:</code> trailers linking to spec artifact IDs</li>
  </ul>
</div>

<h3 id="pipeline-task-implementer">7. Task Implementer</h3>
<p>Guides phase-by-phase code construction using test-first development (TDD). Each task produces code with embedded traceability references.</p>
<div class="info-card">
  <h4>Output</h4>
  <p><code>src/</code> and <code>tests/</code> — Source code and tests with <code>Refs:</code> comments linking back to spec artifacts.</p>
  <h4>Code Traceability</h4>
  <p>Every function, class, or module includes a <code>Refs:</code> comment listing the artifact IDs it implements:</p>
  <p><code>/** Refs: UC-001, INV-EXT-005 */</code></p>
</div>

<h3 id="pipeline-security">8. Security Auditor (Lateral)</h3>
<p>Audits the security posture of technical specifications based on <strong>OWASP ASVS v4</strong>, <strong>CWE</strong>, and <strong>SWEBOK v4</strong>. Can be invoked at any pipeline stage.</p>
<div class="info-card">
  <h4>Output</h4>
  <p><code>audits/SECURITY-AUDIT-BASELINE.md</code> — Security findings with risk severity, affected artifacts, and remediation guidance.</p>
</div>

<h3 id="pipeline-req-change">9. Req Change (Lateral)</h3>
<p>Manages the full lifecycle of requirements changes: ADD, MODIFY, and DEPRECATE with bidirectional propagation through all spec documents. Supports <strong>pipeline cascade</strong> — automatically re-triggers downstream skills when changes invalidate existing artifacts.</p>
<div class="info-card">
  <h4>Capabilities</h4>
  <ul>
    <li>ISO 14764 maintenance classification (Corrective, Adaptive, Perfective, Preventive)</li>
    <li>Impact analysis across the full traceability chain</li>
    <li>Pipeline cascade modes: <code>auto</code>, <code>manual</code>, <code>dry-run</code>, <code>plan-only</code></li>
    <li>Feature retirement planning for DEPRECATE operations</li>
  </ul>
</div>


<h2 id="traceability-chain">The Traceability Chain</h2>

<p>The core principle of SDD: every artifact traces to every other artifact through a structured chain. This ensures nothing is built without justification and nothing is specified without being tested.</p>

<div class="trace-chain">
  <span class="tc-node">REQ</span>
  <span class="tc-arrow">&rarr;</span>
  <span class="tc-node">UC</span>
  <span class="tc-arrow">&rarr;</span>
  <span class="tc-node">WF</span>
  <span class="tc-arrow">&rarr;</span>
  <span class="tc-node">API</span>
  <span class="tc-arrow">&rarr;</span>
  <span class="tc-node">BDD</span>
  <span class="tc-arrow">&rarr;</span>
  <span class="tc-node">INV</span>
  <span class="tc-arrow">&rarr;</span>
  <span class="tc-node">ADR</span>
  <span class="tc-arrow">&rarr;</span>
  <span class="tc-node">TASK</span>
  <span class="tc-arrow">&rarr;</span>
  <span class="tc-node" style="background:#2e2216;border-color:#3e3020;color:var(--orange)">COMMIT</span>
  <span class="tc-arrow">&rarr;</span>
  <span class="tc-node">Code</span>
  <span class="tc-arrow">&rarr;</span>
  <span class="tc-node">Tests</span>
</div>

<table class="metric-table">
  <thead>
    <tr><th>Link</th><th>Meaning</th><th>Example</th></tr>
  </thead>
  <tbody>
    <tr><td><strong>REQ &rarr; UC</strong></td><td>Requirement is implemented by a Use Case</td><td>REQ-EXT-001 &rarr; UC-001</td></tr>
    <tr><td><strong>UC &rarr; WF</strong></td><td>Use Case is orchestrated by a Workflow</td><td>UC-001 &rarr; WF-001</td></tr>
    <tr><td><strong>UC &rarr; API</strong></td><td>Use Case is exposed via an API Contract</td><td>UC-001 &rarr; API-001</td></tr>
    <tr><td><strong>REQ &rarr; BDD</strong></td><td>Requirement is verified by acceptance tests</td><td>REQ-EXT-001 &rarr; BDD-001</td></tr>
    <tr><td><strong>REQ &rarr; INV</strong></td><td>Requirement is constrained by business rules</td><td>REQ-EXT-001 &rarr; INV-EXT-005</td></tr>
    <tr><td><strong>REQ &rarr; ADR</strong></td><td>Design decision was made for a requirement</td><td>REQ-SYS-002 &rarr; ADR-001</td></tr>
    <tr><td><strong>FASE &rarr; TASK</strong></td><td>Phase is decomposed into implementation tasks</td><td>FASE-1 &rarr; TASK-F1-001</td></tr>
    <tr><td><strong>TASK &rarr; COMMIT</strong></td><td>Task produces a git commit (<code>Task:</code> trailer)</td><td>TASK-F1-001 &rarr; commit abc1234</td></tr>
    <tr><td><strong>COMMIT &rarr; Code</strong></td><td>Commit contains source code changes (<code>Refs:</code> trailer)</td><td>abc1234 &rarr; src/validator.ts</td></tr>
    <tr><td><strong>TASK &rarr; Code</strong></td><td>Task is implemented in source code (<code>Refs:</code>)</td><td>TASK-F1-001 &rarr; src/validator.ts</td></tr>
    <tr><td><strong>TASK &rarr; Tests</strong></td><td>Task is verified by test files (<code>Refs:</code>)</td><td>TASK-F1-001 &rarr; tests/validator.test.ts</td></tr>
  </tbody>
</table>


<h2 id="automation">Automation</h2>

<p>SDD includes automation infrastructure that enforces pipeline discipline without manual intervention.</p>

<h3>Hooks</h3>
<p>Hooks are scripts that run automatically in response to Claude Code events:</p>

<table class="metric-table">
  <thead>
    <tr><th>Hook</th><th>Trigger</th><th>Purpose</th></tr>
  </thead>
  <tbody>
    <tr><td><strong>H1 — Session Start</strong></td><td>Session begins</td><td>Reads <code>pipeline-state.json</code> and injects current pipeline status into context</td></tr>
    <tr><td><strong>H2 — Upstream Guard</strong></td><td>Before file edit/write</td><td>Blocks downstream skills from modifying upstream artifacts (e.g., task-implementer cannot edit <code>spec/</code>)</td></tr>
    <tr><td><strong>H3 — State Updater</strong></td><td>After file write</td><td>Auto-updates <code>pipeline-state.json</code> when pipeline artifacts change</td></tr>
    <tr><td><strong>H4 — Stop Hook</strong></td><td>Session ends</td><td>Verifies pipeline state consistency before ending</td></tr>
  </tbody>
</table>

<h3>Agents</h3>
<p>Agents are specialized sub-processes that handle specific concerns:</p>

<table class="metric-table">
  <thead>
    <tr><th>Agent</th><th>Purpose</th></tr>
  </thead>
  <tbody>
    <tr><td><strong>A1 — Constitution Enforcer</strong></td><td>Validates operations against the 11 articles of the SDD Constitution</td></tr>
    <tr><td><strong>A2 — Cross-Auditor</strong></td><td>Cross-references all skill definitions for I/O contract mismatches</td></tr>
    <tr><td><strong>A3 — Context Keeper</strong></td><td>Maintains informal project context (preferences, deferred decisions)</td></tr>
    <tr><td><strong>A4 — Requirements Watcher</strong></td><td>Monitors requirement changes and triggers alerts</td></tr>
    <tr><td><strong>A5 — Spec Compliance Checker</strong></td><td>Validates spec consistency after changes</td></tr>
    <tr><td><strong>A6 — Test Coverage Monitor</strong></td><td>Tracks test coverage gaps across requirements</td></tr>
    <tr><td><strong>A7 — Traceability Validator</strong></td><td>Detects suspect links (DOORS-style) when upstream changes</td></tr>
    <tr><td><strong>A8 — Pipeline Health Monitor</strong></td><td>Monitors overall pipeline health and staleness</td></tr>
  </tbody>
</table>

<h3>Pipeline State</h3>
<p>The file <code>pipeline-state.json</code> in the project root tracks pipeline progress. Each stage has a status:</p>
<ul>
  <li><strong>pending</strong> — Not yet executed</li>
  <li><strong>running</strong> — Currently being executed</li>
  <li><strong>done</strong> — Completed successfully</li>
  <li><strong>stale</strong> — Input artifacts have changed since last execution</li>
  <li><strong>error</strong> — Execution failed</li>
</ul>
<p>When a stage becomes stale (its inputs changed), all downstream stages are also marked stale. This ensures the pipeline stays consistent.</p>


<h2 id="utility-skills">Utility Skills</h2>

<p>These skills can be invoked at any time and do not participate in the linear pipeline:</p>

<table class="metric-table">
  <thead>
    <tr><th>Skill</th><th>Command</th><th>Purpose</th></tr>
  </thead>
  <tbody>
    <tr><td><strong>Pipeline Status</strong></td><td><code>/sdd-pipeline-status</code></td><td>Shows current pipeline state, artifact counts, and next recommended action</td></tr>
    <tr><td><strong>Traceability Check</strong></td><td><code>/sdd-traceability-check</code></td><td>Verifies the full REQ-UC-WF-API-BDD-INV-ADR chain; finds orphans and broken links</td></tr>
    <tr><td><strong>Dashboard</strong></td><td><code>/sdd-dashboard</code></td><td>Generates this interactive HTML dashboard from pipeline artifacts</td></tr>
    <tr><td><strong>Sync Notion</strong></td><td><code>/sdd-sync-notion</code></td><td>Bidirectional synchronization with Notion databases</td></tr>
    <tr><td><strong>Session Summary</strong></td><td><code>/sdd-session-summary</code></td><td>Summarizes session decisions and updates project memory</td></tr>
  </tbody>
</table>


<!-- ============================================================ -->
<!-- PART 2: ADOPTING SDD IN EXISTING PROJECTS                      -->
<!-- ============================================================ -->

<h2 id="when-to-onboard">When to Onboard</h2>

<p>SDD supports both <strong>greenfield</strong> (new projects starting from scratch) and <strong>brownfield</strong> (existing projects adopting SDD). The onboarding skills analyze your project and create a custom adoption path.</p>

<div class="info-card">
  <h4>Decision Rule</h4>
  <p><strong>Greenfield:</strong> Start with <code>/sdd-requirements-engineer</code> and follow the pipeline in order.</p>
  <p><strong>Brownfield:</strong> Start with <code>/sdd-onboarding</code> to assess your project and get a tailored adoption plan.</p>
</div>

<div class="pipeline-flow">
  <span class="pf-label">Brownfield Adoption Path</span>
  <div class="pf-step utility">1. Onboarding<br>(diagnose)</div>
  <span class="pf-arrow">&rarr;</span>
  <div class="pf-step utility">2. Reverse<br>Engineer</div>
  <span class="pf-arrow">&rarr;</span>
  <div class="pf-step utility">3. Reconcile<br>(align)</div>
  <span class="pf-arrow">&rarr;</span>
  <div class="pf-step core">Continue<br>Pipeline</div>

  <span class="pf-label">Optional: External Docs</span>
  <div class="pf-step lateral">Import<br>(external docs)</div>
  <span class="pf-arrow">&rarr;</span>
  <div class="pf-step core">Pipeline</div>
</div>


<h2 id="project-scenarios">Project Scenarios</h2>

<p>The onboarding skill classifies projects into <strong>8 scenarios</strong> based on detected signals:</p>

<table class="metric-table">
  <thead>
    <tr><th>Scenario</th><th>Signals</th><th>Recommended Path</th></tr>
  </thead>
  <tbody>
    <tr><td><strong>Greenfield</strong></td><td>No code, no docs</td><td>Standard pipeline from Step 1</td></tr>
    <tr><td><strong>Brownfield Bare</strong></td><td>Has code, no documentation</td><td>reverse-engineer &rarr; reconcile &rarr; pipeline</td></tr>
    <tr><td><strong>SDD Drift</strong></td><td>Has SDD artifacts + code, but out of sync</td><td>reconcile &rarr; continue pipeline</td></tr>
    <tr><td><strong>Partial SDD</strong></td><td>Some SDD artifacts, incomplete</td><td>Fill gaps &rarr; spec-auditor &rarr; continue</td></tr>
    <tr><td><strong>Brownfield with Docs</strong></td><td>Has code + external docs (Jira, OpenAPI, etc.)</td><td>import &rarr; reverse-engineer &rarr; reconcile</td></tr>
    <tr><td><strong>Tests as Spec</strong></td><td>Has tests but no requirements/specs</td><td>reverse-engineer (test-focused) &rarr; pipeline</td></tr>
    <tr><td><strong>Multi-Team</strong></td><td>Multiple teams, partial adoption</td><td>Per-module onboarding &rarr; reconcile</td></tr>
    <tr><td><strong>Fork/Migration</strong></td><td>Forked from another project</td><td>import &rarr; reverse-engineer &rarr; reconcile</td></tr>
  </tbody>
</table>


<h3 id="skill-onboarding">/sdd-onboarding</h3>

<p>The entry point for adopting SDD in any existing project. Performs a 7-phase diagnostic and generates a tailored adoption plan.</p>

<div class="info-card">
  <h4>What it does</h4>
  <ul>
    <li>Scans for existing SDD artifacts, code, tests, external docs</li>
    <li>Classifies the project into one of 8 scenarios</li>
    <li>Computes a health score (0-100) with 7 dimension breakdowns</li>
    <li>Generates an action plan with ordered steps and effort estimates</li>
  </ul>
  <h4>Output</h4>
  <p><code>onboarding/ONBOARDING-REPORT.md</code></p>
  <h4>Modes</h4>
  <p><code>/sdd-onboarding</code> (full) | <code>/sdd-onboarding --quick</code> (fast scan) | <code>/sdd-onboarding --reassess</code> (re-evaluate after changes)</p>
</div>


<h3 id="skill-reverse-engineer">/sdd-reverse-engineer</h3>

<p>Analyzes existing code to generate complete SDD artifacts: requirements (EARS syntax), specifications, test plans, architecture plans, and findings reports.</p>

<div class="info-card">
  <h4>10-Phase Process</h4>
  <p>Inventory &rarr; Analysis &rarr; <em>Checkpoint 1</em> &rarr; Requirements &rarr; Specs &rarr; Test Plan &rarr; Architecture &rarr; Tasks &rarr; <em>Checkpoint 2</em> &rarr; Findings Report</p>
  <h4>Findings Markers</h4>
  <p>Code analysis produces findings tagged with markers:</p>
  <ul>
    <li><code>[DEAD-CODE]</code> — Unreachable or unused code</li>
    <li><code>[TECH-DEBT]</code> — Technical debt patterns</li>
    <li><code>[WORKAROUND]</code> — Temporary solutions</li>
    <li><code>[INFERRED]</code> — Requirements inferred from code behavior</li>
    <li><code>[IMPLICIT-RULE]</code> — Business rules embedded in code logic</li>
  </ul>
  <h4>Output</h4>
  <p><code>requirements/</code>, <code>spec/</code>, <code>test/</code>, <code>plan/</code>, <code>task/</code>, <code>findings/</code>, <code>reverse-engineering/</code></p>
</div>


<h3 id="skill-reconcile">/sdd-reconcile</h3>

<p>Detects drift between SDD specifications and code, classifies divergences, and aligns them through automatic or user-guided resolution.</p>

<div class="info-card">
  <h4>6 Divergence Types</h4>
  <table class="metric-table">
    <thead><tr><th>Type</th><th>Resolution</th><th>Example</th></tr></thead>
    <tbody>
      <tr><td>NEW_FUNCTIONALITY</td><td>Auto (update specs)</td><td>Code has features not in specs</td></tr>
      <tr><td>REMOVED_FEATURE</td><td>Auto (deprecate)</td><td>Spec describes removed code</td></tr>
      <tr><td>BEHAVIORAL_CHANGE</td><td>Ask user</td><td>Code behaves differently than spec</td></tr>
      <tr><td>REFACTORING</td><td>Auto (update refs)</td><td>Code restructured, same behavior</td></tr>
      <tr><td>BUG_OR_DEFECT</td><td>Ask user</td><td>Code behavior appears incorrect</td></tr>
      <tr><td>AMBIGUOUS</td><td>Ask user</td><td>Cannot determine intent</td></tr>
    </tbody>
  </table>
  <h4>Output</h4>
  <p><code>reconciliation/RECONCILIATION-REPORT.md</code> + updated specs/requirements</p>
</div>


<h3 id="skill-import">/sdd-import</h3>

<p>Imports external documentation into SDD format. Supports 6 formats with automatic detection.</p>

<div class="info-card">
  <h4>Supported Formats</h4>
  <ul>
    <li><strong>Jira</strong> (JSON/CSV export) &rarr; Requirements with EARS syntax</li>
    <li><strong>OpenAPI/Swagger</strong> (YAML/JSON) &rarr; API Contracts + Use Cases</li>
    <li><strong>Markdown</strong> (generic docs) &rarr; Requirements + Specs</li>
    <li><strong>Notion</strong> (markdown/CSV export) &rarr; Requirements + Specs</li>
    <li><strong>CSV</strong> (tabular data) &rarr; Requirements</li>
    <li><strong>Excel</strong> (.xlsx) &rarr; Requirements</li>
  </ul>
  <h4>Output</h4>
  <p><code>requirements/</code>, <code>spec/</code>, <code>import/IMPORT-REPORT.md</code></p>
</div>


<!-- ============================================================ -->
<!-- PART 3: READING THE DASHBOARD                                  -->
<!-- ============================================================ -->

<h2 id="dashboard-header">Header &amp; Pipeline Bar</h2>

<h3>Header</h3>
<p>The top bar shows the <strong>project name</strong> and <strong>generation timestamp</strong>. The version badge (<code>v4</code>) indicates the dashboard template version.</p>

<h3>Pipeline Bar</h3>
<p>Below the header, colored stage cards show the current state of each pipeline stage:</p>

<table class="metric-table">
  <thead>
    <tr><th>Color</th><th>Status</th><th>Meaning</th></tr>
  </thead>
  <tbody>
    <tr><td><span class="swatch"><span class="swatch-dot" style="background:#162e23"></span><span class="swatch-label" style="color:#34d399">Green</span></span></td><td>Done</td><td>Stage completed successfully</td></tr>
    <tr><td><span class="swatch"><span class="swatch-dot" style="background:#2e2a10"></span><span class="swatch-label" style="color:#f5c542">Yellow</span></span></td><td>Running</td><td>Stage is currently executing</td></tr>
    <tr><td><span class="swatch"><span class="swatch-dot" style="background:#2e1616"></span><span class="swatch-label" style="color:#f87171">Red</span></span></td><td>Error</td><td>Stage execution failed</td></tr>
    <tr><td><span class="swatch"><span class="swatch-dot" style="background:#2e2216"></span><span class="swatch-label" style="color:#fb923c">Orange</span></span></td><td>Stale</td><td>Inputs changed since last run</td></tr>
    <tr><td><span class="swatch"><span class="swatch-dot" style="background:#1a1d27"></span><span class="swatch-label" style="color:#8890a0">Gray</span></span></td><td>Pending</td><td>Not yet executed</td></tr>
  </tbody>
</table>

<p>Each stage card shows the <strong>stage name</strong>, <strong>artifact count</strong> (number produced), and <strong>current status</strong>. Click a stage card to filter the matrix view to artifacts from that stage.</p>


<h2 id="dashboard-stats">Stats Cards</h2>

<p>The stats row provides at-a-glance metrics about your project's traceability health:</p>

<table class="metric-table">
  <thead>
    <tr><th>Card</th><th>What it shows</th><th>Good value</th></tr>
  </thead>
  <tbody>
    <tr><td><strong>Artifacts</strong></td><td>Total number of traced artifacts across all types (REQ, UC, WF, etc.)</td><td>Grows with pipeline progress</td></tr>
    <tr><td><strong>Relationships</strong></td><td>Total cross-reference links between artifacts</td><td>Higher = better connected</td></tr>
    <tr><td><strong>Requirements with Use Cases</strong></td><td>% of REQs that have at least one UC linked</td><td>&ge; 90% (green)</td></tr>
    <tr><td><strong>Requirements with Code</strong></td><td>% of REQs referenced by source code via <code>Refs:</code> comments</td><td>&ge; 60% (green)</td></tr>
    <tr><td><strong>Requirements with Tests</strong></td><td>% of REQs referenced by test files via <code>Refs:</code> comments</td><td>&ge; 60% (green)</td></tr>
    <tr><td><strong>Orphans</strong></td><td>Artifacts not referenced by any other artifact</td><td>0 (green)</td></tr>
    <tr><td><strong>Commits</strong></td><td>Git commits with <code>Refs:</code> or <code>Task:</code> trailers (shown only if commits exist)</td><td>Higher = better tracked</td></tr>
    <tr><td><strong>Requirements with Commits</strong></td><td>% of REQs linked to at least one git commit</td><td>&ge; 50% (green)</td></tr>
    <tr><td><strong>SDD Adoption</strong></td><td>Adoption health grade and score (shown only if onboarding data exists)</td><td>&ge; 60 (green)</td></tr>
    <tr><td><strong>Code Findings</strong></td><td>Critical + high findings from reverse engineering (shown only if findings exist)</td><td>0 (green)</td></tr>
    <tr><td><strong>Broken References</strong></td><td>IDs referenced in documents that don't exist as defined artifacts</td><td>0 (green)</td></tr>
  </tbody>
</table>

<p>Cards with <strong style="color:var(--red)">red values</strong> indicate problems that need attention. Cards with <strong style="color:var(--green)">green values</strong> meet targets.</p>


<h2 id="dashboard-health">Health Score</h2>

<p>The health score provides a single letter grade (A-F) summarizing overall traceability health. It appears as a large hero element below the stats cards.</p>

<div class="grade-scale">
  <div class="grade-item"><div class="grade-letter" style="color:var(--green)">A</div><div class="grade-range">90-100</div><div class="grade-label" style="color:var(--green)">Excellent</div></div>
  <div class="grade-item"><div class="grade-letter" style="color:var(--accent)">B</div><div class="grade-range">75-89</div><div class="grade-label" style="color:var(--accent)">Good</div></div>
  <div class="grade-item"><div class="grade-letter" style="color:var(--yellow)">C</div><div class="grade-range">60-74</div><div class="grade-label" style="color:var(--yellow)">Needs Work</div></div>
  <div class="grade-item"><div class="grade-letter" style="color:var(--orange)">D</div><div class="grade-range">40-59</div><div class="grade-label" style="color:var(--orange)">At Risk</div></div>
  <div class="grade-item"><div class="grade-letter" style="color:var(--red)">F</div><div class="grade-range">0-39</div><div class="grade-label" style="color:var(--red)">Critical</div></div>
</div>

<p>Next to the grade, the <strong>Action Required</strong> panel lists prioritized recommendations to improve the score, with priority dots:</p>
<ul>
  <li><span class="swatch"><span class="swatch-dot" style="background:var(--red)"></span><span class="swatch-label">High priority</span></span> — Critical gaps that significantly impact the score</li>
  <li><span class="swatch"><span class="swatch-dot" style="background:var(--yellow)"></span><span class="swatch-label">Medium priority</span></span> — Important improvements to address</li>
  <li><span class="swatch"><span class="swatch-dot" style="background:var(--green)"></span><span class="swatch-label">Low priority</span></span> — Nice-to-have enhancements</li>
</ul>


<h2 id="dashboard-colors">Color Legend</h2>

<p>The dashboard uses a consistent color system for traceability status throughout all views:</p>

<table class="metric-table">
  <thead>
    <tr><th>Color</th><th>Status</th><th>Dashboard Label</th><th>Meaning</th></tr>
  </thead>
  <tbody>
    <tr>
      <td><span class="swatch"><span class="swatch-dot" style="background:#34d399"></span></span></td>
      <td><code>full</code></td>
      <td><strong>Complete</strong></td>
      <td>Requirement has UC + BDD + TASK + Code + Tests all linked</td>
    </tr>
    <tr>
      <td><span class="swatch"><span class="swatch-dot" style="background:#f5c542"></span></span></td>
      <td><code>partial</code></td>
      <td><strong>In Progress</strong></td>
      <td>Requirement has UC and either code or tests, but not all links</td>
    </tr>
    <tr>
      <td><span class="swatch"><span class="swatch-dot" style="background:#fb923c"></span></span></td>
      <td><code>spec-only</code></td>
      <td><strong>Specified</strong></td>
      <td>Requirement has UC but no code or tests yet</td>
    </tr>
    <tr>
      <td><span class="swatch"><span class="swatch-dot" style="background:#f87171"></span></span></td>
      <td><code>none</code></td>
      <td><strong>Not Started</strong></td>
      <td>Requirement has no Use Case — traceability not yet started</td>
    </tr>
  </tbody>
</table>

<div class="info-card">
  <h4>Status Calculation Logic</h4>
  <p>For each requirement, the status is computed as:</p>
  <ol>
    <li>If UC &gt; 0 AND BDD &gt; 0 AND TASK &gt; 0 AND Code &gt; 0 AND Tests &gt; 0 &rarr; <strong>Complete</strong></li>
    <li>If UC &gt; 0 AND (Code &gt; 0 OR Tests &gt; 0) &rarr; <strong>In Progress</strong></li>
    <li>If UC &gt; 0 &rarr; <strong>Specified</strong></li>
    <li>Otherwise &rarr; <strong>Not Started</strong></li>
  </ol>
</div>


<h2 id="view-summary">Summary View</h2>

<p>The default view when opening the dashboard. Provides an executive overview with four panels:</p>

<h3>Traceability Coverage</h3>
<p>Progress bars showing what percentage of requirements have each artifact type linked. Each bar shows the current percentage against a target threshold:</p>
<table class="metric-table">
  <thead>
    <tr><th>Metric</th><th>Target</th><th>Weight in Health Score</th></tr>
  </thead>
  <tbody>
    <tr><td>Requirements with Use Cases</td><td>90%</td><td>25%</td></tr>
    <tr><td>Requirements with Acceptance Tests (BDD)</td><td>70%</td><td>20%</td></tr>
    <tr><td>Requirements with Tasks</td><td>80%</td><td>20%</td></tr>
    <tr><td>Requirements with Code</td><td>60%</td><td>20%</td></tr>
    <tr><td>Requirements with Tests</td><td>50%</td><td>15%</td></tr>
  </tbody>
</table>

<h3>Top Gaps</h3>
<p>Lists the requirements with the most missing traceability links, sorted by gap severity. Click a requirement ID to open its detail panel. The "missing" column shows which artifact types are absent.</p>

<h3>Artifact Breakdown</h3>
<p>Shows counts for each artifact type: Requirements, Use Cases, Workflows, Contracts, Acceptance Tests, Rules, Decisions, Tasks.</p>

<h3>Pipeline Status</h3>
<p>Mirrors the pipeline bar in a compact format, showing each stage's status and last run timestamp.</p>


<h2 id="view-matrix">Matrix View</h2>

<p>The most detailed view — a table where each row is a requirement and columns show linked artifact counts.</p>

<h3>Columns</h3>
<table class="metric-table">
  <thead>
    <tr><th>Column</th><th>Shows</th></tr>
  </thead>
  <tbody>
    <tr><td><strong>ID</strong></td><td>Requirement identifier (click to open detail panel)</td></tr>
    <tr><td><strong>Title</strong></td><td>Requirement description text</td></tr>
    <tr><td><strong>Priority</strong></td><td>MoSCoW priority: <span style="color:var(--red)">Must</span>, <span style="color:var(--yellow)">Should</span>, <span style="color:var(--green)">Could</span>, <span style="color:var(--gray)">Won't</span></td></tr>
    <tr><td><strong>Domain</strong></td><td>Auto-classified business domain from REQ prefix</td></tr>
    <tr><td><strong>Layer</strong></td><td>Technical layer: <span style="color:var(--cyan)">Backend</span>, <span style="color:var(--purple)">Frontend</span>, <span style="color:var(--yellow)">Infrastructure</span>, <span style="color:var(--lime)">Integration</span></td></tr>
    <tr><td><strong>Use Cases</strong></td><td>Count of linked UC artifacts</td></tr>
    <tr><td><strong>Workflows</strong></td><td>Count of linked WF artifacts</td></tr>
    <tr><td><strong>Contracts</strong></td><td>Count of linked API artifacts</td></tr>
    <tr><td><strong>Acceptance</strong></td><td>Count of linked BDD scenarios</td></tr>
    <tr><td><strong>Rules</strong></td><td>Count of linked INV (invariant/business rule) artifacts</td></tr>
    <tr><td><strong>Decisions</strong></td><td>Count of linked ADR artifacts</td></tr>
    <tr><td><strong>Tasks</strong></td><td>Count of linked TASK artifacts</td></tr>
    <tr><td><strong>Code</strong></td><td>Count of source code references (<code>Refs:</code> comments in src/)</td></tr>
    <tr><td><strong>Tests</strong></td><td>Count of test file references (<code>Refs:</code> in tests/)</td></tr>
    <tr><td><strong>Status</strong></td><td>Computed traceability status (Complete/In Progress/Specified/Not Started)</td></tr>
  </tbody>
</table>

<h3>Sorting &amp; Filtering</h3>
<p>Click any column header to sort. The filter bar above the table provides:</p>
<ul>
  <li><strong>Search</strong> — Filter by ID or title text</li>
  <li><strong>Status</strong> — Show only a specific traceability status</li>
  <li><strong>Priority</strong> — Filter by MoSCoW priority</li>
  <li><strong>Type</strong> — Filter by artifact type</li>
  <li><strong>Stage</strong> — Filter by pipeline stage</li>
  <li><strong>Domain / Layer / Category</strong> — Filter by classification</li>
</ul>
<p>The badge on the right shows the count of matching results. Pipeline stage cards are also clickable filters.</p>

<h3>Cell Values</h3>
<p>Numeric cells show a <span style="color:var(--accent);font-weight:600">blue count</span> when artifacts are linked, or a <span style="color:var(--gray)">dash (—)</span> when zero. Zero cells have a tooltip explaining what's missing.</p>


<h2 id="view-classification">Classification View</h2>

<p>Groups requirements by <strong>business domain</strong> (auto-classified from the REQ prefix). Each domain gets a card showing:</p>
<ul>
  <li><strong>Domain name</strong> and requirement count</li>
  <li><strong>Progress bar</strong> — percentage of requirements with "Complete" status (green &ge; 80%, yellow &ge; 50%, red &lt; 50%)</li>
  <li><strong>Requirement list</strong> — each item shows status dot, ID, and title. Click to open detail panel.</li>
</ul>

<p>This view helps stakeholders see coverage by business area rather than by individual requirement.</p>


<h2 id="view-coverage">Code Coverage View</h2>

<p>Shows traceability from the code perspective — which source files reference SDD artifacts and which don't.</p>

<h3>Summary Cards</h3>
<p>Top-level metrics: total files scanned, files with refs, symbols with refs, and overall coverage percentage.</p>

<h3>File List</h3>
<p>Each source file gets an expandable card showing:</p>
<ul>
  <li><strong>File path</strong> (relative from project root)</li>
  <li><strong>Coverage bar</strong> — percentage of symbols in the file that have <code>Refs:</code> comments</li>
  <li><strong>Coverage percentage</strong> — color-coded: <span style="color:var(--green)">high (&ge;75%)</span>, <span style="color:var(--yellow)">mid (25-74%)</span>, <span style="color:var(--red)">low (&lt;25%)</span>, <span style="color:var(--gray)">zero (0%)</span></li>
</ul>
<p>Click a file to expand and see individual symbols (functions, classes) with their referenced artifact IDs.</p>


<h2 id="view-adoption">Adoption View</h2>

<p>The 5th tab, visible when onboarding data exists (or as an empty state prompting you to run <code>/sdd-onboarding</code>). Shows how SDD adoption is progressing in brownfield projects.</p>

<h3>Adoption Journey</h3>
<p>A horizontal stepper showing the recommended action plan steps from the onboarding report. Each step shows:</p>
<ul>
  <li><strong>Completion status</strong> — green checkmark if the corresponding skill has been run, gray circle otherwise</li>
  <li><strong>Step label</strong> — the skill or action to perform (e.g., "Run reverse-engineer", "Run reconcile")</li>
</ul>
<p>The journey visualizes the full adoption path from diagnosis to pipeline entry.</p>

<h3>Scenario Card</h3>
<p>Shows the detected project scenario (one of 8 types) with:</p>
<ul>
  <li><strong>Scenario name</strong> — e.g., "Brownfield Bare", "SDD Drift", "Partial SDD"</li>
  <li><strong>Confidence level</strong> — how confident the detection is (high/medium/low)</li>
  <li><strong>Signals</strong> — the indicators that led to this classification (e.g., "has code", "no docs", "partial specs")</li>
</ul>

<h3>Health Dimensions</h3>
<p>Seven horizontal bars showing the onboarding health score breakdown across dimensions like documentation, testing, architecture, etc. Each bar shows the dimension score (0-100) against the overall adoption score.</p>

<h3>Findings Panel</h3>
<p>If reverse engineering has been run, shows code analysis findings:</p>
<ul>
  <li><strong>Severity bar</strong> — stacked bar showing distribution across Critical, High, Medium, Low</li>
  <li><strong>Category breakdown</strong> — findings grouped by type (dead code, tech debt, workarounds, etc.)</li>
  <li><strong>Top findings</strong> — the most important findings requiring attention</li>
</ul>

<h3>Reconciliation Panel</h3>
<p>If reconciliation has been run, shows spec-code alignment:</p>
<ul>
  <li><strong>Alignment percentage</strong> — how well specs match the current code</li>
  <li><strong>Divergence table</strong> — list of divergences by type (NEW_FUNCTIONALITY, REMOVED_FEATURE, BEHAVIORAL_CHANGE, etc.) with counts and resolution status</li>
</ul>

<h3>Import Panel</h3>
<p>If import has been run, shows external documentation integration:</p>
<ul>
  <li><strong>Source table</strong> — which external sources were imported (Jira, OpenAPI, Markdown, etc.) with artifact counts</li>
  <li><strong>Quality metrics</strong> — mapping accuracy, duplicate detection, and conversion success rates</li>
</ul>

<div class="info-card">
  <h4>Empty State</h4>
  <p>If no onboarding data exists, the Adoption view shows a prompt: <strong>"Run <code>/sdd-onboarding</code> to diagnose your project"</strong>. Each sub-panel also degrades gracefully — if only onboarding was run but not reverse-engineer, the Findings panel shows its own empty state.</p>
</div>


<h2 id="detail-panel">Detail Panel</h2>

<p>Click any artifact ID in the dashboard to open a slide-out detail panel with 5 tabs:</p>

<h3>Story Tab</h3>
<p>A <strong>narrative summary</strong> of the artifact — auto-generated text describing what the requirement does, what it connects to, and its current status. Uses humanized language for non-technical stakeholders.</p>

<h3>Trace Chain Tab</h3>
<p>Shows all <strong>incoming</strong> (artifacts that reference this one) and <strong>outgoing</strong> (artifacts this one references) relationships as a visual chain. Each linked artifact shows its ID, type, and source file. Click any ID to navigate to that artifact's detail panel.</p>

<h3>Code Tab</h3>
<p>Lists all <strong>source code references</strong> for this artifact — file paths, symbol names (function/class), symbol types, and the specific artifact IDs referenced in each <code>Refs:</code> comment.</p>

<h3>Tests Tab</h3>
<p>Lists all <strong>test references</strong> — test file paths, test names, testing framework, and referenced artifact IDs.</p>

<h3>Documents Tab</h3>
<p>Groups all related specification documents by type (Use Cases, Workflows, Contracts, etc.), showing each artifact's ID, title, and source file.</p>


<h2 id="health-formula">Health Score Formula</h2>

<p>The health score is a weighted sum of 5 coverage metrics, each normalized against its target:</p>

<table class="metric-table">
  <thead>
    <tr><th>Metric</th><th>Target</th><th>Weight</th><th>Formula</th></tr>
  </thead>
  <tbody>
    <tr><td>Requirements with Use Cases</td><td>90%</td><td>25%</td><td><code>min(actual / 90, 1) &times; 25</code></td></tr>
    <tr><td>Requirements with BDD</td><td>70%</td><td>20%</td><td><code>min(actual / 70, 1) &times; 20</code></td></tr>
    <tr><td>Requirements with Tasks</td><td>80%</td><td>20%</td><td><code>min(actual / 80, 1) &times; 20</code></td></tr>
    <tr><td>Requirements with Code</td><td>60%</td><td>20%</td><td><code>min(actual / 60, 1) &times; 20</code></td></tr>
    <tr><td>Requirements with Tests</td><td>50%</td><td>15%</td><td><code>min(actual / 50, 1) &times; 15</code></td></tr>
  </tbody>
</table>

<div class="info-card">
  <h4>Example Calculation</h4>
  <p>If your project has: UC coverage 85%, BDD 60%, Tasks 75%, Code 40%, Tests 30%:</p>
  <p>Score = min(85/90,1)&times;25 + min(60/70,1)&times;20 + min(75/80,1)&times;20 + min(40/60,1)&times;20 + min(30/50,1)&times;15</p>
  <p>Score = 0.944&times;25 + 0.857&times;20 + 0.938&times;20 + 0.667&times;20 + 0.600&times;15</p>
  <p>Score = 23.6 + 17.1 + 18.8 + 13.3 + 9.0 = <strong>82 (Grade B — Good)</strong></p>
</div>

<p>The score is <strong>capped at 100</strong>. Exceeding a target does not earn bonus points — the <code>min(..., 1)</code> ensures each metric contributes at most its weight.</p>


<h2 id="glossary">Glossary</h2>

<div class="glossary-grid">
  <div class="glossary-item"><div class="glossary-abbr">REQ</div><div class="glossary-def">Requirement — a formal statement of what the system must do</div></div>
  <div class="glossary-item"><div class="glossary-abbr">UC</div><div class="glossary-def">Use Case — a functional scenario implementing a requirement</div></div>
  <div class="glossary-item"><div class="glossary-abbr">WF</div><div class="glossary-def">Workflow — a process orchestration or state machine</div></div>
  <div class="glossary-item"><div class="glossary-abbr">API</div><div class="glossary-def">API Contract — endpoint definition with request/response schemas</div></div>
  <div class="glossary-item"><div class="glossary-abbr">BDD</div><div class="glossary-def">Behavior-Driven Development scenario — Gherkin acceptance test</div></div>
  <div class="glossary-item"><div class="glossary-abbr">INV</div><div class="glossary-def">Invariant — a business rule that must always hold true</div></div>
  <div class="glossary-item"><div class="glossary-abbr">ADR</div><div class="glossary-def">Architecture Decision Record — documents a design choice and rationale</div></div>
  <div class="glossary-item"><div class="glossary-abbr">NFR</div><div class="glossary-def">Non-Functional Requirement — performance, security, scalability, etc.</div></div>
  <div class="glossary-item"><div class="glossary-abbr">TASK</div><div class="glossary-def">Implementation Task — atomic work item (1 task = 1 commit)</div></div>
  <div class="glossary-item"><div class="glossary-abbr">FASE</div><div class="glossary-def">Phase — a grouping of related tasks in the implementation plan</div></div>
  <div class="glossary-item"><div class="glossary-abbr">RN</div><div class="glossary-def">Business Rule (Regla de Negocio) — same as INV</div></div>
  <div class="glossary-item"><div class="glossary-abbr">SDD</div><div class="glossary-def">Specification-Driven Development — the methodology</div></div>
  <div class="glossary-item"><div class="glossary-abbr">SWEBOK</div><div class="glossary-def">Software Engineering Body of Knowledge — IEEE reference</div></div>
  <div class="glossary-item"><div class="glossary-abbr">EARS</div><div class="glossary-def">Easy Approach to Requirements Syntax</div></div>
  <div class="glossary-item"><div class="glossary-abbr">MoSCoW</div><div class="glossary-def">Must / Should / Could / Won't — prioritization method</div></div>
  <div class="glossary-item"><div class="glossary-abbr">TDD</div><div class="glossary-def">Test-Driven Development — write tests before code</div></div>
  <div class="glossary-item"><div class="glossary-abbr">OWASP ASVS</div><div class="glossary-def">Application Security Verification Standard</div></div>
  <div class="glossary-item"><div class="glossary-abbr">CWE</div><div class="glossary-def">Common Weakness Enumeration — security vulnerability catalog</div></div>
  <div class="glossary-item"><div class="glossary-abbr">COMMIT</div><div class="glossary-def">Git commit linked via Task: and Refs: trailers to the traceability chain</div></div>
  <div class="glossary-item"><div class="glossary-abbr">SHA</div><div class="glossary-def">Secure Hash Algorithm — short git commit identifier (e.g., abc1234)</div></div>
  <div class="glossary-item"><div class="glossary-abbr">Brownfield</div><div class="glossary-def">Existing project with code, adopting SDD retroactively</div></div>
  <div class="glossary-item"><div class="glossary-abbr">Greenfield</div><div class="glossary-def">New project starting from scratch with SDD from day one</div></div>
  <div class="glossary-item"><div class="glossary-abbr">Scenario</div><div class="glossary-def">Project classification (1 of 8) detected by the onboarding skill</div></div>
  <div class="glossary-item"><div class="glossary-abbr">Drift</div><div class="glossary-def">Divergence between SDD specifications and actual code behavior</div></div>
  <div class="glossary-item"><div class="glossary-abbr">Reconciliation</div><div class="glossary-def">Process of detecting and resolving spec-code drift</div></div>
  <div class="glossary-item"><div class="glossary-abbr">[DEAD-CODE]</div><div class="glossary-def">Finding marker: unreachable or unused code detected by reverse engineering</div></div>
  <div class="glossary-item"><div class="glossary-abbr">[TECH-DEBT]</div><div class="glossary-def">Finding marker: technical debt patterns in existing code</div></div>
  <div class="glossary-item"><div class="glossary-abbr">[WORKAROUND]</div><div class="glossary-def">Finding marker: temporary solutions that should be replaced</div></div>
  <div class="glossary-item"><div class="glossary-abbr">[INFERRED]</div><div class="glossary-def">Finding marker: requirement inferred from code behavior, not documented</div></div>
  <div class="glossary-item"><div class="glossary-abbr">[IMPLICIT-RULE]</div><div class="glossary-def">Finding marker: business rule embedded in code logic without documentation</div></div>
  <div class="glossary-item"><div class="glossary-abbr">Health Score</div><div class="glossary-def">Weighted 0-100 score measuring traceability completeness (or adoption readiness)</div></div>
  <div class="glossary-item"><div class="glossary-abbr">Blast Radius</div><div class="glossary-def">Set of files/artifacts affected by a change, used in impact analysis</div></div>
  <div class="glossary-item"><div class="glossary-abbr">Coverage Map</div><div class="glossary-def">Per-file source-to-test mapping with classification (plan-architect §7.4)</div></div>
  <div class="glossary-item"><div class="glossary-abbr">ISO 14764</div><div class="glossary-def">Standard for software maintenance classification (Corrective/Adaptive/Perfective/Preventive)</div></div>
</div>

</main>
</div>

<!-- Sidebar active-link tracking -->
<script>
(function(){
  var links = document.querySelectorAll('.sidebar-link');
  var sections = [];
  links.forEach(function(link){
    var id = link.getAttribute('href');
    if(id && id.charAt(0) === '#'){
      var el = document.getElementById(id.slice(1));
      if(el) sections.push({el: el, link: link});
    }
  });

  function updateActive(){
    var scrollY = window.scrollY + 100;
    var active = null;
    sections.forEach(function(s){
      if(s.el.offsetTop <= scrollY) active = s;
    });
    links.forEach(function(l){ l.classList.remove('active') });
    if(active) active.link.classList.add('active');
  }

  window.addEventListener('scroll', updateActive);
  updateActive();
})();
</script>

</body>
</html>
```
