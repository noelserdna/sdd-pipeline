# SDD Dashboard HTML Template (v6)

Simplified verification-focused dashboard. Single mission: show what is implemented, what is missing, and what code the LLM invented without traceability. Receives `{{DATA_JSON}}` with the traceability graph (v6 schema, backward-compatible with v3-v5).

## Template

```html
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>SDD Dashboard — {{PROJECT_NAME}}</title>
<style>
*,*::before,*::after{box-sizing:border-box;margin:0;padding:0}
:root{
  --bg:#0f1117;--surface:#1a1d27;--surface2:#242837;--surface3:#2e3348;--border:#2e3348;
  --text:#e4e7f1;--text2:#a0a4be;--text3:#8890a0;
  --accent:#6c8cff;--accent2:#4a6aef;
  --green:#4ade80;--yellow:#facc15;--red:#f87171;--orange:#fb923c;--gray:#6b7280;
  --font:'Inter',-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,sans-serif;
  --mono:'SF Mono',Consolas,'Courier New',monospace;
  --radius:8px;
  --shadow-sm:0 1px 2px rgba(0,0,0,.3),0 0 0 1px rgba(255,255,255,.03);
  --shadow-md:0 2px 8px rgba(0,0,0,.3),0 0 0 1px rgba(255,255,255,.04);
}
body{font-family:var(--font);background:var(--bg);color:var(--text);line-height:1.5;overflow-x:hidden}
a{color:var(--accent);text-decoration:none}
a:hover{text-decoration:underline}
button{font-family:var(--font);cursor:pointer}

/* Scrollbar */
::-webkit-scrollbar{width:6px}
::-webkit-scrollbar-track{background:transparent}
::-webkit-scrollbar-thumb{background:var(--surface3);border-radius:3px}
:focus-visible{outline:2px solid var(--accent);outline-offset:2px}

/* Header */
.header{background:var(--surface);border-bottom:1px solid var(--border);padding:14px 24px;display:flex;align-items:center;justify-content:space-between;position:sticky;top:0;z-index:100}
.header h1{font-size:18px;font-weight:600}
.header h1 span{color:var(--accent);font-weight:700}
.header-meta{font-size:12px;color:var(--text2);display:flex;align-items:center;gap:4px}
.header-version{font-size:10px;color:var(--text3);background:var(--surface2);padding:2px 6px;border-radius:4px;margin-left:8px}

/* Pipeline Bar */
.pipeline{padding:16px 24px;display:flex;gap:10px;align-items:stretch;overflow-x:auto}
.pipeline-stage{flex:1;min-width:110px;padding:10px 12px;border-radius:var(--radius);text-align:center;border:1px solid transparent;transition:transform .15s}
.pipeline-stage:hover{transform:translateY(-1px)}
.pipeline-stage .stage-name{font-size:10px;font-weight:600;text-transform:uppercase;letter-spacing:.5px}
.pipeline-stage .stage-count{font-size:20px;font-weight:700;margin-top:2px}
.pipeline-stage .stage-status{font-size:10px;margin-top:2px;opacity:.8}
.pipeline-arrow{width:20px;display:flex;align-items:center;justify-content:center;flex-shrink:0;color:var(--text3)}

/* Pipeline groups: las cinco fases de ingenieria. El grupo es solo un marco de
   lectura, asi que su cromatismo se mantiene neutro y el color sigue estando
   donde importa: el estado de cada etapa. */
/* El grupo si puede comprimirse (min-width:0): con fit-content la fila entera
   desbordaba el viewport y la ultima fase quedaba fuera de vista. El solape
   entre el total de una fase y el nombre de la siguiente se evita en el head,
   recortando el rotulo cuando no cabe en vez de invadir al vecino. */
.pipeline-group{display:flex;flex-direction:column;gap:6px;min-width:0;flex:1}
.pipeline-group-head{display:flex;align-items:baseline;gap:8px;padding:0 2px 5px;border-bottom:1px solid var(--border);overflow:hidden}
/* El rotulo es metadato, no titular: se le baja el cuerpo y el tracking para que
   quepa en fases estrechas. El recorte con puntos suspensivos queda como ultimo
   recurso en pantallas muy pequenas. */
.pipeline-group-name{font-size:9px;font-weight:700;text-transform:uppercase;letter-spacing:.35px;color:var(--text2);white-space:nowrap;overflow:hidden;text-overflow:ellipsis;min-width:0}
.pipeline-group-total{font-size:10px;font-weight:600;color:var(--text3);font-variant-numeric:tabular-nums;margin-left:auto;flex-shrink:0}
.pipeline-group-dot{width:6px;height:6px;border-radius:50%;flex-shrink:0;background:currentColor}
.pipeline-group-stages{display:flex;gap:4px;align-items:stretch;flex:1}
.pipeline-group-stages .pipeline-stage{display:flex;flex-direction:column;justify-content:center}
/* El punto de estado del grupo hereda el color de la misma escala st-*, pero sin
   su fondo: solo interesa el matiz. */
.gs-done{color:var(--green)}
.gs-running{color:var(--yellow)}
.gs-partial{color:var(--orange)}
.gs-pending{color:var(--gray)}
.gs-unknown{color:var(--text3)}
.stage-lateral-tag{font-size:9px;opacity:.65;margin-top:3px;font-style:italic}
/* Caja secundaria: mismo lenguaje, menor peso. Es una etapa complementaria de la
   principal de su grupo, no una etapa de segunda. */
/* La condicion de secundaria afecta al PESO TIPOGRAFICO, nunca al ancho: el
   ancho lo decide en exclusiva el volumen de artefactos (flex-grow, ver
   sizeWeight). Cuando principal y secundaria tenian minimos distintos, una caja
   de 9 artefactos salia mas ancha que una de 12 solo por su categoria, que es
   justo la logica que esta barra pretende comunicar. */
.pipeline-stage.is-secondary{padding:8px 10px}
.pipeline-stage.is-secondary .stage-name{font-size:9px;letter-spacing:.4px;opacity:.85}
.pipeline-stage.is-secondary .stage-count{font-size:14px;font-weight:600}
.pipeline-stage.is-secondary .stage-status{font-size:9px}
.pipeline-stage.is-secondary .stage-lateral-tag{font-size:8px}
/* Un unico suelo de legibilidad para todas las cajas, sea principal o
   secundaria, para que dos cajas nunca se ordenen por categoria en vez de por
   volumen.
   flex-basis:0 es imprescindible: con `auto` el ancho de partida es el del
   contenido, asi que lo fijaba la palabra mas larga del rotulo ("ARCHITECT"
   reservaba 96px) y una etapa de 9 artefactos salia mas ancha que una de 12.
   Con basis 0 el reparto depende solo del peso por volumen. */
/* Sin overflow-wrap:anywhere: partia palabras a mitad ("REQUIREMENT S",
   "ARCHITE CT"). El min-width explicito ya anula el min-content automatico del
   flex item, que era lo que impedia que basis:0 mandase. */
.pipeline-stage.is-primary,
.pipeline-stage.is-secondary{flex-basis:0;flex-shrink:1;min-width:64px}
.st-done{background:#162e23;color:var(--green)}
.st-running{background:#2e2a10;color:var(--yellow)}
.st-error{background:#2e1616;color:var(--red)}
.st-stale{background:#2e2216;color:var(--orange)}
.st-pending{background:var(--surface);color:var(--gray)}
.st-unknown{background:var(--surface);color:var(--text3)}

/* Stats Cards */
.stats{display:grid;grid-template-columns:repeat(4,1fr);gap:12px;padding:0 24px 16px}
@media(max-width:768px){.stats{grid-template-columns:repeat(2,1fr)}}
.stat-card{background:var(--surface);box-shadow:var(--shadow-sm);border-radius:var(--radius);padding:16px;text-align:center}
.stat-card .stat-label{font-size:11px;color:var(--text2);text-transform:uppercase;letter-spacing:.5px}
.stat-card .stat-value{font-size:32px;font-weight:700;margin-top:4px}
.stat-card .stat-sub{font-size:12px;color:var(--text3);margin-top:2px}
.stat-card .stat-value.good{color:var(--green)}
.stat-card .stat-value.warn{color:var(--yellow)}
.stat-card .stat-value.bad{color:var(--red)}

/* Filter Bar */
.filters{position:sticky;top:52px;z-index:90;background:var(--bg);padding:8px 24px;display:flex;gap:8px;align-items:center;border-bottom:1px solid var(--border)}
.filter-input{background:var(--surface);border:1px solid var(--border);border-radius:6px;padding:6px 10px;color:var(--text);font-size:12px;min-width:200px;outline:none;flex:1;max-width:320px}
.filter-input:focus{border-color:var(--accent)}
.filter-select{background:var(--surface);border:1px solid var(--border);border-radius:6px;padding:6px 8px;color:var(--text);font-size:12px;outline:none;cursor:pointer;appearance:none;-webkit-appearance:none;background-image:url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' width='12' height='12' fill='%238890a0'%3E%3Cpath d='M6 8L1 3h10z'/%3E%3C/svg%3E");background-repeat:no-repeat;background-position:right 8px center;padding-right:24px}
.filter-select:focus{border-color:var(--accent)}
.filter-badge{background:var(--surface2);border:1px solid var(--border);border-radius:12px;padding:2px 10px;font-size:11px;color:var(--text2);white-space:nowrap;margin-left:auto}

/* Verification Matrix */
.matrix-section{padding:0 24px 24px}
.table-wrap{overflow-x:auto}
table{width:100%;border-collapse:collapse;font-size:13px}
thead th{background:var(--surface2)}
th{background:var(--surface2);color:var(--text2);font-size:11px;text-transform:uppercase;letter-spacing:.5px;padding:8px 10px;text-align:left;border-bottom:2px solid var(--border);white-space:nowrap;cursor:pointer;user-select:none}
th:hover{color:var(--text)}
th .sort-icon{margin-left:4px;opacity:.4;font-size:10px}
th.sorted .sort-icon{opacity:1;color:var(--accent)}
td{padding:7px 10px;border-bottom:1px solid var(--border);vertical-align:middle}
tr.data-row:hover td{background:var(--surface2)}
tr.data-row{cursor:pointer}

/* Cell styles */
.cell-id{font-family:var(--mono);font-size:12px;font-weight:600;color:var(--accent)}
.cell-title{max-width:220px;overflow:hidden;text-overflow:ellipsis;white-space:nowrap}
.cell-priority{font-size:11px;font-weight:600;padding:2px 8px;border-radius:4px;white-space:nowrap}
.cell-priority.must{background:#2e1616;color:var(--red)}
.cell-priority.should{background:#2e2a10;color:var(--yellow)}
.cell-priority.could{background:#162e23;color:var(--green)}
.cell-priority.wont{background:var(--surface2);color:var(--gray)}

/* Trace indicator symbols */
.trace-ok{color:var(--green);font-weight:700;font-size:14px}
.trace-partial{color:var(--yellow);font-weight:700;font-size:14px}
.trace-miss{color:var(--red);font-weight:700;font-size:14px}
.trace-na{color:var(--gray);font-size:14px}

/* Status badge */
.status-badge{font-size:11px;font-weight:600;padding:2px 8px;border-radius:4px;white-space:nowrap}
.status-badge.covered{background:#162e23;color:var(--green)}
.status-badge.partial{background:#2e2a10;color:var(--yellow)}
.status-badge.missing{background:#2e1616;color:var(--red)}

/* Expanded row */
tr.expand-row{display:none}
tr.expand-row.open{display:table-row}
tr.expand-row td{padding:0;border-bottom:1px solid var(--border)}
.expand-content{padding:16px 20px;background:var(--surface);border-left:3px solid var(--accent)}
.trace-tree{font-family:var(--mono);font-size:12px;line-height:1.8;color:var(--text2)}
.trace-tree .tree-root{color:var(--accent);font-weight:600;font-size:13px;margin-bottom:4px}
.trace-tree .tree-line{padding-left:20px;position:relative}
.trace-tree .tree-line::before{content:'';position:absolute;left:6px;top:0;bottom:50%;width:1px;border-left:1px solid var(--border)}
.trace-tree .tree-line::after{content:'';position:absolute;left:6px;top:50%;width:10px;border-top:1px solid var(--border)}
.trace-tree .t-ok{color:var(--green)}
.trace-tree .t-miss{color:var(--red);font-weight:600}
.trace-tree .t-label{color:var(--text)}
.trace-tree .t-conf{color:var(--text3);font-size:11px}
.trace-tree .tree-group{margin-top:8px}
.trace-tree .tree-group-label{color:var(--text);font-weight:600;font-size:12px;margin-bottom:2px}

/* Code Orphans Section */
.orphans-section{padding:0 24px 32px}
.orphans-header{font-size:15px;font-weight:600;color:var(--text);margin-bottom:12px;display:flex;align-items:center;gap:8px}
.orphans-header .orphan-count{background:#2e1616;color:var(--red);font-size:12px;padding:2px 8px;border-radius:4px}
.orphan-list{display:grid;grid-template-columns:repeat(auto-fill,minmax(360px,1fr));gap:6px}
.orphan-item{font-family:var(--mono);font-size:12px;color:var(--text2);padding:6px 12px;background:var(--surface);border-radius:var(--radius);border-left:3px solid var(--red);overflow:hidden;text-overflow:ellipsis;white-space:nowrap}

/* Empty state */
.empty{text-align:center;padding:60px 24px;color:var(--text2)}
.empty h2{font-size:18px;margin-bottom:8px;color:var(--text)}

/* Responsive */
@media(max-width:768px){
  .pipeline{flex-wrap:wrap}
  .pipeline-stage{min-width:80px}
  .filters{flex-wrap:wrap}
  .filter-input{min-width:140px}
  .orphan-list{grid-template-columns:1fr}
}
</style>
</head>
<body>

<div class="header">
  <h1><span>SDD</span> Verification Dashboard <span class="header-version">v6</span></h1>
  <div class="header-meta">
    <span id="hdr-project"></span> &middot; <span id="hdr-time"></span>
  </div>
</div>

<div class="pipeline" id="pipeline"></div>

<div class="stats" id="stats"></div>

<div class="filters">
  <input type="text" class="filter-input" id="fSearch" placeholder="Search by ID or title...">
  <select class="filter-select" id="fStatus">
    <option value="">All Status</option>
    <option value="covered">Covered</option>
    <option value="partial">Partial</option>
    <option value="missing">Missing</option>
  </select>
  <select class="filter-select" id="fPriority">
    <option value="">All Priority</option>
  </select>
  <span class="filter-badge" id="fCount"></span>
</div>

<div class="matrix-section">
  <div class="table-wrap">
    <table id="matrix">
      <thead>
        <tr>
          <th data-col="id">ID <span class="sort-icon">&#9650;</span></th>
          <th data-col="title">Title <span class="sort-icon">&#9650;</span></th>
          <th data-col="uc">Use Case <span class="sort-icon">&#9650;</span></th>
          <th data-col="wf">Workflow <span class="sort-icon">&#9650;</span></th>
          <th data-col="api">API <span class="sort-icon">&#9650;</span></th>
          <th data-col="bdd">Scenario <span class="sort-icon">&#9650;</span></th>
          <th data-col="inv">Invariant <span class="sort-icon">&#9650;</span></th>
          <th data-col="adr">Decision <span class="sort-icon">&#9650;</span></th>
          <th data-col="code">Code <span class="sort-icon">&#9650;</span></th>
          <th data-col="test">Test <span class="sort-icon">&#9650;</span></th>
        </tr>
      </thead>
      <tbody id="tbody"></tbody>
    </table>
  </div>
</div>

<div class="orphans-section" id="orphansSection" style="display:none">
  <div class="orphans-header">
    Code Without Traceability <span class="orphan-count" id="orphanCount"></span>
  </div>
  <div class="orphan-list" id="orphanList"></div>
</div>

<div class="empty" id="empty" style="display:none">
  <h2>No artifacts found</h2>
  <p>Run the SDD pipeline to generate traceability artifacts, then re-run <code>/sdd-dashboard</code>.</p>
</div>

<script>
(function(){
  "use strict";
  var DATA = {{DATA_JSON}};

  // --- Helpers ---
  var $ = function(s){ return document.getElementById(s) };
  var ce = function(t){ return document.createElement(t) };
  function esc(s){ var d = ce("span"); d.textContent = s; return d.innerHTML }

  // --- Header ---
  $("hdr-project").textContent = DATA.projectName || "SDD Project";
  $("hdr-time").textContent = DATA.generatedAt ? new Date(DATA.generatedAt).toLocaleString() : "";

  // --- Pipeline Bar ---
  // Las etapas se pintan agrupadas en las cinco fases de ingenieria que define
  // pipeline.groups. La agrupacion viene del generador, no se decide aqui: este
  // codigo solo la recorre.
  var pipeEl = $("pipeline");
  var stages = (DATA.pipeline && DATA.pipeline.stages) || [];
  var laterals = (DATA.pipeline && DATA.pipeline.lateralStages) || [];
  var groups = (DATA.pipeline && DATA.pipeline.groups) || [];

  // Peso visual de una caja segun su numero de artefactos.
  //
  // Escala logaritmica y no lineal: los recuentos de un pipeline real van de 7 a
  // 835 (120x). En proporcion directa, la caja de 7 quedaria reducida a un hilo
  // ilegible mientras una sola se comeria la fila. El logaritmo comprime ese
  // rango a ~3x, que sigue comunicando "esta tiene mucho mas que aquella" sin
  // que ninguna deje de leerse. El +0.35 evita que una etapa a 0 desaparezca.
  function sizeWeight(count) {
    return Math.log10((count || 0) + 1) + 0.35;
  }

  function stageBox(s){
    var div = ce("div");
    // Las secundarias se pintan reducidas; el nombre completo queda en el title
    // para que reducir la caja no cueste informacion.
    div.className = "pipeline-stage st-" + (s.status || "unknown")
      + (s.secondary ? " is-secondary" : " is-primary");
    var count = (s.status === "pending" || s.status === "unknown") && !s.artifactCount ? "\u2014" : String(s.artifactCount || 0);
    // El ancho de la caja refleja su volumen de artefactos.
    div.style.flexGrow = sizeWeight(s.artifactCount).toFixed(3);
    var fullName = s.name.replace(/-/g, " ");
    var shown = s.displayName || fullName;
    div.title = fullName + ": " + (s.artifactCount || 0) + " " + (s.stageLabel || "artifacts") + " (" + (s.status || "unknown") + ")";
    div.innerHTML = '<div class="stage-name">' + esc(shown) + '</div>'
      + '<div class="stage-count">' + count + '</div>'
      + '<div class="stage-status">' + esc(s.status || "unknown") + '</div>'
      + (s.lateral ? '<div class="stage-lateral-tag">lateral</div>' : '');
    return div;
  }

  function arrowEl(){
    var arrow = ce("span");
    arrow.className = "pipeline-arrow";
    arrow.innerHTML = '<svg width="16" height="10" viewBox="0 0 16 10"><path d="M0 5h12M9 1l4 4-4 4" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"/></svg>';
    return arrow;
  }

  if (groups.length) {
    var byName = {};
    stages.concat(laterals).forEach(function(s){ byName[s.name] = s });

    groups.forEach(function(g, gi){
      if (gi > 0) pipeEl.appendChild(arrowEl());

      var wrap = ce("div");
      wrap.className = "pipeline-group";
      // El grupo pesa lo que suman sus cajas, de modo que la proporcion es
      // coherente en los dos niveles: entre fases y dentro de cada fase.
      var groupWeight = (g.stages || []).reduce(function(acc, name){
        var st = byName[name];
        return acc + (st ? sizeWeight(st.artifactCount) : 0);
      }, 0);
      wrap.style.flexGrow = (groupWeight || 1).toFixed(3);

      var head = ce("div");
      head.className = "pipeline-group-head";
      head.innerHTML = '<span class="pipeline-group-dot gs-' + esc(g.status || "unknown") + '"></span>'
        + '<span class="pipeline-group-name">' + esc(g.label || g.id) + '</span>'
        + '<span class="pipeline-group-total">' + String(g.artifactCount || 0) + '</span>';
      head.title = (g.label || g.id) + ": " + (g.artifactCount || 0) + " artefactos (" + (g.status || "unknown") + ")";
      wrap.appendChild(head);

      var row = ce("div");
      row.className = "pipeline-group-stages";
      (g.stages || []).forEach(function(name){
        var s = byName[name];
        if (s) row.appendChild(stageBox(s));
      });
      wrap.appendChild(row);
      pipeEl.appendChild(wrap);
    });
  } else {
    // Compatibilidad con grafos generados antes de que existieran los grupos.
    stages.forEach(function(s, i){
      if (i > 0) pipeEl.appendChild(arrowEl());
      pipeEl.appendChild(stageBox(s));
    });
  }

  // --- Build indexes ---
  var artById = {};
  (DATA.artifacts || []).forEach(function(a){ artById[a.id] = a });

  var incoming = {};
  var outgoing = {};
  (DATA.relationships || []).forEach(function(r){
    if (!incoming[r.target]) incoming[r.target] = [];
    incoming[r.target].push(r);
    if (!outgoing[r.source]) outgoing[r.source] = [];
    outgoing[r.source].push(r);
  });

  // --- Trace helpers ---
  // Tipos que se PINTAN como columna de la matriz.
  var TRACE_TYPES = ["UC","WF","API","BDD","INV","ADR"];
  // Tipos que PUNTUAN para el estado de cobertura. ADR queda fuera a proposito:
  // un ADR documenta una decision tecnica puntual y no es exigible a cada
  // requisito (solo el 27% tiene uno), asi que contarlo permitiria alcanzar
  // "covered" por tener una decision en lugar de casos de uso o pruebas.
  var COVERAGE_TYPES = ["UC","WF","API","BDD","INV"];

  function getRelated(reqId, targetType) {
    var ids = {};
    (incoming[reqId] || []).forEach(function(r){
      var art = artById[r.source];
      if (art && art.type === targetType) ids[r.source] = art;
    });
    (outgoing[reqId] || []).forEach(function(r){
      var art = artById[r.target];
      if (art && art.type === targetType) ids[r.target] = art;
    });
    return ids;
  }

  function countRelated(reqId, targetType) {
    return Object.keys(getRelated(reqId, targetType)).length;
  }

  // Recursively collect related artifacts through the chain
  function collectChain(reqId) {
    var chain = {};
    TRACE_TYPES.forEach(function(t){ chain[t] = getRelated(reqId, t) });

    // Also look for indirect relations: UC -> WF, UC -> API, etc.
    var ucIds = Object.keys(chain.UC);
    ucIds.forEach(function(ucId){
      ["WF","API","BDD","INV"].forEach(function(t){
        var sub = getRelated(ucId, t);
        Object.keys(sub).forEach(function(k){ chain[t][k] = sub[k] });
      });
    });
    var wfIds = Object.keys(chain.WF);
    wfIds.forEach(function(wfId){
      ["API","BDD","INV"].forEach(function(t){
        var sub = getRelated(wfId, t);
        Object.keys(sub).forEach(function(k){ chain[t][k] = sub[k] });
      });
    });

    return chain;
  }

  // --- Status computation ---
  function computeStatus(req) {
    var chain = collectChain(req.id);
    var ucCount = Object.keys(chain.UC).length;
    var bddCount = Object.keys(chain.BDD).length;
    var codeCount = (req.codeRefs || []).length;
    var testCount = (req.testRefs || []).length;

    var specParts = 0;
    COVERAGE_TYPES.forEach(function(t){ if (Object.keys(chain[t]).length > 0) specParts++ });
    var implParts = (codeCount > 0 ? 1 : 0) + (testCount > 0 ? 1 : 0);

    if (specParts >= 3 && codeCount > 0 && testCount > 0) return "covered";
    if (specParts > 0 || codeCount > 0 || testCount > 0) return "partial";
    return "missing";
  }

  // --- Trace indicator: returns symbol and class ---
  function traceIndicator(count, expected) {
    if (expected === false) return { sym: "\u2014", cls: "trace-na" };
    if (count > 1) return { sym: "\u2713", cls: "trace-ok" };
    if (count === 1) return { sym: "\u2713", cls: "trace-ok" };
    return { sym: "\u2717", cls: "trace-miss" };
  }

  // --- Build row data ---
  var reqs = (DATA.artifacts || []).filter(function(a){ return a.type === "REQ" });
  var rows = [];

  reqs.forEach(function(req){
    var chain = collectChain(req.id);
    var counts = {};
    TRACE_TYPES.forEach(function(t){ counts[t] = Object.keys(chain[t]).length });
    counts.CODE = (req.codeRefs || []).length;
    counts.TEST = (req.testRefs || []).length;
    var status = computeStatus(req);
    rows.push({ art: req, counts: counts, chain: chain, status: status });
  });

  // If no REQs, fall back to showing all artifacts
  if (reqs.length === 0) {
    (DATA.artifacts || []).forEach(function(a){
      rows.push({ art: a, counts: {}, chain: {}, status: "missing" });
    });
  }

  // --- Stats Cards ---
  var st = DATA.statistics || {};
  var cov = st.traceabilityCoverage || {};
  var statsEl = $("stats");

  function covPct(m) {
    if (!m) return 0;
    return m.functionalPercentage != null ? m.functionalPercentage : (m.percentage || 0);
  }

  function addStat(label, value, sub, cls) {
    var d = ce("div"); d.className = "stat-card";
    d.innerHTML = '<div class="stat-label">' + esc(label) + '</div>'
      + '<div class="stat-value ' + cls + '">' + esc(String(value)) + '</div>'
      + '<div class="stat-sub">' + esc(sub) + '</div>';
    statsEl.appendChild(d);
  }

  var pctCode = covPct(cov.reqsWithCode);
  var pctTest = covPct(cov.reqsWithTests);
  var orphanCount = (st.orphans || []).length;
  var brokenCount = (st.brokenReferences || []).length;

  addStat("REQs with Code", pctCode.toFixed(0) + "%",
    cov.reqsWithCode ? (cov.reqsWithCode.functionalCount || cov.reqsWithCode.count || 0) + "/" + (cov.reqsWithCode.functionalTotal || cov.reqsWithCode.total || 0) + " functional" : "",
    pctCode >= 70 ? "good" : pctCode >= 40 ? "warn" : "bad");

  addStat("REQs with Tests", pctTest.toFixed(0) + "%",
    cov.reqsWithTests ? (cov.reqsWithTests.functionalCount || cov.reqsWithTests.count || 0) + "/" + (cov.reqsWithTests.functionalTotal || cov.reqsWithTests.total || 0) + " functional" : "",
    pctTest >= 70 ? "good" : pctTest >= 40 ? "warn" : "bad");

  addStat("Orphan Artifacts", orphanCount, orphanCount === 0 ? "All linked" : "Unreferenced",
    orphanCount === 0 ? "good" : "bad");

  addStat("Broken References", brokenCount, brokenCount === 0 ? "All valid" : "Undefined targets",
    brokenCount === 0 ? "good" : "bad");

  // --- Populate priority dropdown ---
  var priorities = {};
  (DATA.artifacts || []).forEach(function(a){
    if (a.priority) priorities[a.priority] = 1;
  });
  var priSel = $("fPriority");
  Object.keys(priorities).sort().forEach(function(k){
    var o = ce("option"); o.value = k; o.textContent = k;
    priSel.appendChild(o);
  });

  // --- Priority CSS class ---
  function priClass(p) {
    if (!p) return "";
    var l = p.toLowerCase();
    if (l.indexOf("must") >= 0 || l === "critical" || l === "m") return "must";
    if (l.indexOf("should") >= 0 || l === "high" || l === "s") return "should";
    if (l.indexOf("could") >= 0 || l === "medium" || l === "c") return "could";
    return "wont";
  }

  // --- Sorting ---
  var sortCol = "id";
  var sortDir = 1;

  function sortRows(arr) {
    return arr.slice().sort(function(a, b){
      var va, vb;
      switch (sortCol) {
        case "id": va = a.art.id; vb = b.art.id; break;
        case "title": va = (a.art.title || "").toLowerCase(); vb = (b.art.title || "").toLowerCase(); break;
        case "priority": va = a.art.priority || ""; vb = b.art.priority || ""; break;
        case "status":
          var order = { covered: 0, partial: 1, missing: 2 };
          va = order[a.status] != null ? order[a.status] : 3;
          vb = order[b.status] != null ? order[b.status] : 3;
          break;
        default:
          var col = sortCol.toUpperCase();
          va = (a.counts[col] || 0); vb = (b.counts[col] || 0);
      }
      if (va < vb) return -1 * sortDir;
      if (va > vb) return 1 * sortDir;
      return 0;
    });
  }

  // --- Header click sorting ---
  document.querySelectorAll("th[data-col]").forEach(function(th){
    th.addEventListener("click", function(){
      var col = th.dataset.col;
      if (sortCol === col) { sortDir *= -1; }
      else { sortCol = col; sortDir = 1; }
      document.querySelectorAll("th").forEach(function(h){ h.classList.remove("sorted") });
      th.classList.add("sorted");
      th.querySelector(".sort-icon").textContent = sortDir === 1 ? "\u25B2" : "\u25BC";
      applyFilters();
    });
  });

  // --- Filtering ---
  function applyFilters() {
    var search = $("fSearch").value.toLowerCase();
    var statusF = $("fStatus").value;
    var priorityF = $("fPriority").value;

    var filtered = rows.filter(function(row){
      if (search && row.art.id.toLowerCase().indexOf(search) < 0 && (row.art.title || "").toLowerCase().indexOf(search) < 0) return false;
      if (statusF && row.status !== statusF) return false;
      if (priorityF && row.art.priority !== priorityF) return false;
      return true;
    });

    filtered = sortRows(filtered);
    renderTable(filtered);
    $("fCount").textContent = filtered.length + " of " + rows.length;
  }

  $("fSearch").addEventListener("input", applyFilters);
  $("fStatus").addEventListener("change", applyFilters);
  $("fPriority").addEventListener("change", applyFilters);

  // --- Currently expanded row ---
  var expandedId = null;

  // --- Render matrix table ---
  function renderTable(filtered) {
    var tb = $("tbody");
    tb.innerHTML = "";

    if (filtered.length === 0 && rows.length === 0) {
      $("empty").style.display = "block";
      return;
    }
    $("empty").style.display = "none";

    filtered.forEach(function(row){
      // Data row
      var tr = ce("tr");
      tr.className = "data-row";
      tr.dataset.id = row.art.id;

      // ID
      var tdId = ce("td");
      tdId.innerHTML = '<span class="cell-id">' + esc(row.art.id) + '</span>';
      tr.appendChild(tdId);

      // Title
      var tdTitle = ce("td");
      tdTitle.className = "cell-title";
      tdTitle.textContent = row.art.title || "";
      tdTitle.title = row.art.title || "";
      tr.appendChild(tdTitle);

      // Priority y Status no tienen columna propia: la prioridad ya se filtra
      // desde la barra superior y el estado se sigue calculando para ese filtro,
      // pero ocupaban dos columnas sin aportar a la lectura de la trazabilidad,
      // que es de lo que va esta tabla.

      // Trace columns: UC, WF, API, BDD, INV, ADR
      TRACE_TYPES.forEach(function(t){
        var td = ce("td");
        td.style.textAlign = "center";
        var c = row.counts[t] || 0;
        var ind = traceIndicator(c);
        td.innerHTML = '<span class="' + ind.cls + '" title="' + c + " " + t + '">' + ind.sym + '</span>';
        tr.appendChild(td);
      });

      // Code
      var tdCode = ce("td");
      tdCode.style.textAlign = "center";
      var cc = row.counts.CODE || 0;
      var cInd = traceIndicator(cc);
      tdCode.innerHTML = '<span class="' + cInd.cls + '" title="' + cc + ' code refs">' + cInd.sym + '</span>';
      tr.appendChild(tdCode);

      // Test
      var tdTest = ce("td");
      tdTest.style.textAlign = "center";
      var tc = row.counts.TEST || 0;
      var tInd = traceIndicator(tc);
      tdTest.innerHTML = '<span class="' + tInd.cls + '" title="' + tc + ' test refs">' + tInd.sym + '</span>';
      tr.appendChild(tdTest);

      // Click to expand
      tr.addEventListener("click", function(){ toggleExpand(row.art.id) });
      tb.appendChild(tr);

      // Expand row (hidden by default)
      var expandTr = ce("tr");
      expandTr.className = "expand-row";
      expandTr.id = "expand-" + row.art.id;
      if (expandedId === row.art.id) expandTr.classList.add("open");
      var expandTd = ce("td");
      // Se cuentan las cabeceras reales en vez de fijar un numero: al anadir la
      // columna de decisiones el valor fijo se quedo corto y la fila desplegada
      // dejaba de abarcar toda la tabla.
      expandTd.colSpan = document.querySelectorAll("#matrix thead th").length || 10;
      expandTd.innerHTML = '<div class="expand-content">' + buildTraceTree(row) + '</div>';
      expandTr.appendChild(expandTd);
      tb.appendChild(expandTr);
    });
  }

  function toggleExpand(id) {
    var el = $("expand-" + id);
    if (!el) return;
    if (expandedId === id) {
      el.classList.remove("open");
      expandedId = null;
    } else {
      // Close previous
      if (expandedId) {
        var prev = $("expand-" + expandedId);
        if (prev) prev.classList.remove("open");
      }
      el.classList.add("open");
      expandedId = id;
    }
  }

  // --- Build trace tree HTML ---
  function buildTraceTree(row) {
    var req = row.art;
    var chain = row.chain || {};
    var html = '<div class="trace-tree">';
    html += '<div class="tree-root">' + esc(req.id) + ': ' + esc(req.title || "") + '</div>';

    // UC entries with their sub-traces
    var ucs = chain.UC || {};
    var ucKeys = Object.keys(ucs);

    if (ucKeys.length > 0) {
      ucKeys.forEach(function(ucId){
        var uc = ucs[ucId];
        html += '<div class="tree-line"><span class="t-ok">\u2713</span> ' + esc(ucId) + ' <span class="t-label">' + esc(uc.title || "") + '</span></div>';

        // Sub-traces from this UC
        var subTypes = ["WF","API","BDD","INV"];
        subTypes.forEach(function(st){
          var subArts = getRelated(ucId, st);
          Object.keys(subArts).forEach(function(subId){
            html += '<div class="tree-line" style="padding-left:40px"><span class="t-ok">\u2713</span> ' + esc(subId) + ' <span class="t-label">' + esc(subArts[subId].title || "") + '</span></div>';
          });
        });

        // Find missing BDD/INV for this UC (if none linked)
        if (Object.keys(getRelated(ucId, "BDD")).length === 0 && (chain.BDD && Object.keys(chain.BDD).length === 0)) {
          html += '<div class="tree-line" style="padding-left:40px"><span class="t-miss">\u2717</span> BDD <span class="t-miss">\u2190 MISSING</span></div>';
        }
        if (Object.keys(getRelated(ucId, "INV")).length === 0 && (chain.INV && Object.keys(chain.INV).length === 0)) {
          html += '<div class="tree-line" style="padding-left:40px"><span class="t-miss">\u2717</span> INV <span class="t-miss">\u2190 MISSING</span></div>';
        }
      });
    } else {
      html += '<div class="tree-line"><span class="t-miss">\u2717</span> UC <span class="t-miss">\u2190 MISSING</span></div>';
    }

    // Artefactos enlazados directamente al REQ y no alcanzables desde un UC.
    // Se deriva de TRACE_TYPES (menos UC, que es la raiz de las ramas de arriba)
    // para que cualquier tipo nuevo en la matriz aparezca tambien aqui: cuando
    // esta lista era literal, ADR salia con tick en la columna pero no figuraba
    // en el detalle.
    TRACE_TYPES.filter(function(t){ return t !== "UC" }).forEach(function(t){
      var arts = chain[t] || {};
      Object.keys(arts).forEach(function(artId){
        // Check if already shown via UC path
        var shownViaUC = false;
        ucKeys.forEach(function(ucId){
          if (getRelated(ucId, t)[artId]) shownViaUC = true;
        });
        if (!shownViaUC) {
          html += '<div class="tree-line"><span class="t-ok">\u2713</span> ' + esc(artId) + ' <span class="t-label">' + esc(arts[artId].title || "") + '</span></div>';
        }
      });
    });

    // Code references
    html += '<div class="tree-group"><div class="tree-group-label">Code</div>';
    if (req.codeRefs && req.codeRefs.length > 0) {
      req.codeRefs.forEach(function(cr){
        var conf = cr.confidence ? ' <span class="t-conf">(confidence: ' + cr.confidence + ')</span>' : '';
        var origin = cr.origin ? ' <span class="t-conf">[' + esc(cr.origin) + ']</span>' : '';
        html += '<div class="tree-line"><span class="t-ok">\u2713</span> <span class="t-label">' + esc(cr.file || cr.path || "unknown") + '</span>' + conf + origin + '</div>';
      });
    } else {
      html += '<div class="tree-line"><span class="t-miss">\u2717</span> <span class="t-miss">No code references</span></div>';
    }
    html += '</div>';

    // Test references
    html += '<div class="tree-group"><div class="tree-group-label">Tests</div>';
    if (req.testRefs && req.testRefs.length > 0) {
      req.testRefs.forEach(function(tr){
        html += '<div class="tree-line"><span class="t-ok">\u2713</span> <span class="t-label">' + esc(tr.file || tr.path || "unknown") + '</span></div>';
      });
    } else {
      html += '<div class="tree-line"><span class="t-miss">\u2717</span> <span class="t-miss">No test references</span></div>';
    }
    html += '</div>';

    html += '</div>';
    return html;
  }

  // --- Code Orphans Section ---
  function renderOrphans() {
    var codeStats = st.codeStats || {};
    var orphanFiles = codeStats.orphanFiles || [];

    // Also check for code refs with origin "uncovered" across all artifacts
    var uncoveredFiles = {};
    (DATA.artifacts || []).forEach(function(a){
      (a.codeRefs || []).forEach(function(cr){
        if (cr.origin === "uncovered") {
          uncoveredFiles[cr.file || cr.path] = true;
        }
      });
    });

    // Merge orphan sources
    var allOrphans = {};
    orphanFiles.forEach(function(f){ allOrphans[f] = true });
    Object.keys(uncoveredFiles).forEach(function(f){ if (f) allOrphans[f] = true });

    var orphanArr = Object.keys(allOrphans).sort();

    if (orphanArr.length === 0) return;

    var section = $("orphansSection");
    section.style.display = "block";
    $("orphanCount").textContent = orphanArr.length + " files";

    var list = $("orphanList");
    orphanArr.forEach(function(f){
      var item = ce("div");
      item.className = "orphan-item";
      item.textContent = f;
      item.title = f;
      list.appendChild(item);
    });
  }

  // --- Initial render ---
  applyFilters();
  renderOrphans();

})();
</script>
</body>
</html>
```

## Template Variables

- `{{DATA_JSON}}` — The complete traceability graph JSON (v6 schema)
- `{{PROJECT_NAME}}` — The project name displayed in header and title

## Data Contract

The template expects these fields in `DATA_JSON`:

### Top-level
- `projectName` (string) — Project display name
- `generatedAt` (ISO 8601) — Dashboard generation timestamp
- `pipeline.stages[]` — Array of `{ name, status, artifactCount, stageLabel }`
- `artifacts[]` — Array of all artifacts
- `relationships[]` — Array of `{ source, target }` links
- `statistics` — Aggregate statistics

### Artifact shape
```json
{
  "id": "REQ-001",
  "type": "REQ",
  "title": "User registration",
  "priority": "Must Have",
  "codeRefs": [{ "file": "src/auth/register.ts", "confidence": 0.9, "origin": "linked" }],
  "testRefs": [{ "file": "tests/auth/register.test.ts" }]
}
```

### Statistics shape
```json
{
  "totalArtifacts": 120,
  "orphans": ["WF-099"],
  "brokenReferences": [{ "source": "UC-001", "target": "API-999" }],
  "traceabilityCoverage": {
    "reqsWithCode": { "percentage": 65, "functionalPercentage": 72, "count": 18, "total": 25, "functionalCount": 18, "functionalTotal": 25 },
    "reqsWithTests": { "percentage": 55, "functionalPercentage": 60, "count": 15, "total": 25, "functionalCount": 15, "functionalTotal": 25 }
  },
  "codeStats": {
    "orphanFiles": ["src/utils/helpers.ts", "src/config/constants.ts"]
  }
}
```
