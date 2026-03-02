# HTML Dashboard Template v5

Self-contained HTML template for the SDD Comprehension Dashboard. The skill replaces `{{DATA_JSON}}` with the serialized `traceability-graph.json` content (v3 schema).

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
  --text:#e4e7f1;--text2:#a0a4be;--text3:#8890a0;--accent:#6c8cff;--accent2:#4a6aef;
  --green:#34d399;--yellow:#f5c542;--red:#f87171;--orange:#fb923c;--gray:#8890a0;
  --purple:#a78bfa;--cyan:#22d3ee;--pink:#f472b6;--lime:#a3e635;
  --font:'Inter',-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,sans-serif;
  --mono:'SF Mono',Consolas,'Courier New',monospace;
  --radius:8px;
  --shadow-sm:0 1px 2px rgba(0,0,0,.3),0 0 0 1px rgba(255,255,255,.03);
  --shadow-md:0 2px 8px rgba(0,0,0,.3),0 0 0 1px rgba(255,255,255,.04);
  --shadow-lg:0 8px 24px rgba(0,0,0,.4),0 0 0 1px rgba(255,255,255,.05);
}
body{font-family:var(--font);background:var(--bg);background-image:radial-gradient(ellipse at 50% 0%,rgba(108,140,255,.04) 0%,transparent 60%);color:var(--text);line-height:1.5;overflow-x:hidden;font-feature-settings:'tnum' 1,'cv01' 1}
a{color:var(--accent);text-decoration:none}
a:hover{text-decoration:underline}
button{font-family:var(--font);cursor:pointer}

/* Header */
.header{background:var(--surface);border-bottom:1px solid var(--border);padding:16px 24px;display:flex;align-items:center;justify-content:space-between;position:sticky;top:0;z-index:100}
.header h1{font-size:18px;font-weight:600}
.header h1 span{color:var(--accent);font-weight:700}
.header-meta{font-size:12px;color:var(--text2);display:flex;align-items:center;gap:4px}
.header-version{font-size:10px;color:var(--text3);background:var(--surface2);padding:2px 6px;border-radius:4px;margin-left:8px}
.header-guide{margin-left:12px;font-size:11px;padding:3px 10px;border-radius:4px;background:var(--surface2);color:var(--accent);border:1px solid var(--border);text-decoration:none;font-weight:600}
.header-guide:hover{background:var(--surface3);text-decoration:none}

/* Pipeline Bar */
.pipeline{padding:20px 24px;display:flex;gap:4px;align-items:center;overflow-x:auto}
.pipeline-stage{flex:1;min-width:120px;padding:10px 12px;border-radius:var(--radius);text-align:center;cursor:pointer;transition:transform .15s,box-shadow .15s;border:1px solid transparent;position:relative}
.pipeline-stage:hover{transform:translateY(-2px);box-shadow:0 4px 12px rgba(0,0,0,.3)}
.pipeline-stage.active{border-color:var(--accent)}
.pipeline-stage .stage-name{font-size:11px;font-weight:600;text-transform:uppercase;letter-spacing:.5px}
.pipeline-stage .stage-count{font-size:20px;font-weight:700;margin-top:2px}
.pipeline-stage .stage-status{font-size:10px;margin-top:2px;opacity:.8}
.pipeline-arrow{color:var(--text2);font-size:16px;flex-shrink:0}
.st-done{background:#162e23;color:var(--green)}
.st-running{background:#2e2a10;color:var(--yellow)}
.st-error{background:#2e1616;color:var(--red)}
.st-stale{background:#2e2216;color:var(--orange)}
.st-pending{background:var(--surface);color:var(--gray)}
.st-unknown{background:var(--surface);color:var(--text2)}

/* Stats Cards */
.stats{display:grid;grid-template-columns:repeat(auto-fit,minmax(160px,1fr));gap:12px;padding:0 24px 16px}
.stat-card{background:var(--surface);box-shadow:var(--shadow-sm);border:none;border-radius:var(--radius);padding:14px 16px;transition:box-shadow .2s ease}
.stat-card:hover{box-shadow:var(--shadow-md)}
.stat-card .stat-label{font-size:11px;color:var(--text2);text-transform:uppercase;letter-spacing:.5px}
.stat-card .stat-value{font-size:28px;font-weight:700;margin-top:2px}
.stat-card .stat-sub{font-size:12px;color:var(--text2);margin-top:2px}
.stat-card.warn .stat-value{color:var(--red)}
.stat-card.good .stat-value{color:var(--green)}

/* Hero Health Score */
.hero{padding:20px 24px;display:flex;gap:20px;align-items:stretch}
.hero-score{background:var(--surface);box-shadow:var(--shadow-md);border:none;border-radius:var(--radius);padding:24px;text-align:center;min-width:180px;display:flex;flex-direction:column;align-items:center;justify-content:center}
.hero-letter{font-size:56px;font-weight:800;line-height:1}
.hero-label{font-size:13px;margin-top:4px;color:var(--text2)}
.hero-sublabel{font-size:11px;color:var(--text3);margin-top:2px}
.hero-actions{flex:1;background:var(--surface);box-shadow:var(--shadow-md);border:none;border-radius:var(--radius);padding:16px 20px}
.hero-actions h3{font-size:13px;text-transform:uppercase;letter-spacing:.5px;color:var(--text2);margin-bottom:12px}
.hero-rec{display:flex;align-items:flex-start;gap:8px;padding:6px 0;font-size:13px}
.hero-rec-dot{width:8px;height:8px;border-radius:50%;margin-top:5px;flex-shrink:0}
.hero-rec-dot.high{background:var(--red)}
.hero-rec-dot.medium{background:var(--yellow)}
.hero-rec-dot.low{background:var(--green)}
.hero-rec-text{flex:1}
.hero-rec-action{font-size:11px;color:var(--text3);font-family:var(--mono)}
.hero-ok{padding:20px;text-align:center;color:var(--green);font-size:14px}

/* Legend */
.legend{padding:4px 24px;display:flex;gap:16px;font-size:11px;color:var(--text2)}
.legend-item{display:flex;align-items:center;gap:4px}
.legend-dot{width:8px;height:8px;border-radius:50%;flex-shrink:0}

/* Executive Summary View */
.summary-grid{display:grid;grid-template-columns:repeat(3,1fr);gap:16px;padding-top:16px}
.summary-card:nth-child(1){grid-column:1/3}
.summary-card:nth-child(2){grid-row:1/3;grid-column:3}
.summary-card{background:var(--surface);box-shadow:var(--shadow-sm);border:none;border-radius:var(--radius);padding:16px;transition:box-shadow .2s ease}
.summary-card:hover{box-shadow:var(--shadow-md)}
.summary-card h3{font-size:13px;text-transform:uppercase;letter-spacing:.5px;color:var(--text2);margin-bottom:12px}
.summary-progress{margin-bottom:12px}
.summary-progress-header{display:flex;justify-content:space-between;font-size:13px;margin-bottom:4px}
.summary-progress-bar{height:12px;background:var(--surface2);border-radius:6px;overflow:hidden}
.summary-progress-fill{height:100%;border-radius:6px;background:linear-gradient(90deg,var(--accent2),var(--accent));transition:width .3s}
.summary-top-gaps{list-style:none}
.summary-top-gaps li{padding:6px 0;border-bottom:1px solid var(--border);font-size:13px;display:flex;justify-content:space-between;align-items:center}
.summary-top-gaps li:last-child{border-bottom:none}
.summary-gap-id{font-family:var(--mono);font-weight:600;color:var(--accent);cursor:pointer}
.summary-gap-missing{font-size:11px;color:var(--text2)}
.summary-breakdown{display:grid;grid-template-columns:repeat(auto-fit,minmax(120px,1fr));gap:8px}
.summary-breakdown-item{text-align:center;padding:12px;background:var(--surface2);border-radius:var(--radius)}
.summary-breakdown-value{font-size:24px;font-weight:700}
.summary-breakdown-label{font-size:11px;color:var(--text2);margin-top:2px}

/* View Tabs */
.view-tabs{display:flex;gap:0;padding:0 24px;border-bottom:1px solid var(--border)}
.view-tab{padding:10px 20px;font-size:13px;font-weight:600;color:var(--text2);background:none;border:none;border-bottom:2px solid transparent;cursor:pointer;transition:color .15s,border-color .15s}
.view-tab:hover{color:var(--text)}
.view-tab.active{color:var(--accent);border-bottom-color:var(--accent)}

/* Filter Bar */
.filters{position:sticky;top:60px;z-index:90;background:var(--bg);padding:6px 24px;display:flex;gap:5px;align-items:center;border-bottom:1px solid var(--border);flex-wrap:wrap}
.filter-input{background:var(--surface);border:1px solid var(--border);border-radius:6px;padding:4px 8px;color:var(--text);font-size:12px;min-width:130px;outline:none}
.filter-input:focus{border-color:var(--accent)}
.filter-select{background:var(--surface);border:1px solid var(--border);border-radius:6px;padding:4px 6px;color:var(--text);font-size:11px;outline:none;cursor:pointer}
.filter-select:focus{border-color:var(--accent)}
.filter-badge{background:var(--surface2);border:1px solid var(--border);border-radius:12px;padding:2px 8px;font-size:11px;color:var(--text2);white-space:nowrap;margin-left:auto}

/* View Containers */
.view{display:none;padding:0 24px 24px;opacity:0;transform:translateY(8px);transition:opacity .2s ease,transform .2s ease}
.view.active{display:block;opacity:1;transform:translateY(0)}

/* Animations */
@keyframes fadeUp{from{opacity:0;transform:translateY(12px)}to{opacity:1;transform:translateY(0)}}
.stat-card,.summary-card,.class-card{animation:fadeUp .3s ease backwards}

/* Custom Tooltips */
[data-tooltip]{position:relative}
[data-tooltip]::after{content:attr(data-tooltip);position:absolute;bottom:calc(100% + 8px);left:50%;transform:translateX(-50%) translateY(4px);background:var(--surface3);color:var(--text);padding:6px 10px;border-radius:6px;font-size:12px;white-space:nowrap;pointer-events:none;opacity:0;transition:opacity .15s,transform .15s;z-index:300;box-shadow:0 4px 12px rgba(0,0,0,.4)}
[data-tooltip]:hover::after{opacity:1;transform:translateX(-50%) translateY(0)}

/* Scrollbar */
::-webkit-scrollbar{width:6px}
::-webkit-scrollbar-track{background:transparent}
::-webkit-scrollbar-thumb{background:var(--surface3);border-radius:3px}

/* Focus Visible */
:focus-visible{outline:2px solid var(--accent);outline-offset:2px}
.filter-select{appearance:none;-webkit-appearance:none;background-image:url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' width='12' height='12' fill='%238890a0'%3E%3Cpath d='M6 8L1 3h10z'/%3E%3C/svg%3E");background-repeat:no-repeat;background-position:right 8px center;padding-right:24px}

/* Pipeline Arrows CSS */
.pipeline-arrow{width:24px;display:flex;align-items:center;justify-content:center;flex-shrink:0}
.pipeline-arrow::before{content:'';display:block;width:16px;height:2px;background:var(--border);position:relative}
.pipeline-arrow::after{content:'';display:block;border:4px solid transparent;border-left-color:var(--border);position:absolute}

/* === MATRIX VIEW === */
.table-wrap{overflow:visible}
table{width:100%;border-collapse:collapse;font-size:13px}
thead{position:sticky;top:108px;z-index:80}
th{background:var(--surface2);color:var(--text2);font-size:11px;text-transform:uppercase;letter-spacing:.5px;padding:8px 10px;text-align:left;border-bottom:2px solid var(--border);white-space:nowrap;cursor:pointer;user-select:none}
th:hover{color:var(--text)}
th .sort-icon{margin-left:4px;opacity:.4}
th.sorted .sort-icon{opacity:1;color:var(--accent)}
td{padding:7px 10px;border-bottom:1px solid var(--border);vertical-align:top}
tr:hover td{background:var(--surface2)}
tr:hover td:first-child{box-shadow:inset 3px 0 0 var(--accent)}
tr.row-full td:last-child{color:var(--green)}
tr.row-partial td:last-child{color:var(--yellow)}
tr.row-spec-only td:last-child{color:var(--orange)}
tr.row-none td:last-child{color:var(--red)}

/* Cell badges */
.cell-count{display:inline-flex;align-items:center;justify-content:center;min-width:24px;height:22px;border-radius:4px;font-size:12px;font-weight:600;padding:0 6px}
.cell-count.has{background:#1a2e3a;color:var(--accent)}
.cell-count.zero{color:var(--gray)}
.cell-id{font-family:var(--mono);font-size:12px;font-weight:600;color:var(--accent);cursor:pointer}
.cell-id:hover{text-decoration:underline}
.cell-title{max-width:220px;overflow:hidden;text-overflow:ellipsis;white-space:nowrap}
.cell-priority{font-size:11px;font-weight:600;padding:2px 8px;border-radius:4px;white-space:nowrap}
.cell-priority.must{background:#2e1616;color:var(--red)}
.cell-priority.should{background:#2e2a10;color:var(--yellow)}
.cell-priority.could{background:#162e23;color:var(--green)}
.cell-priority.wont{background:var(--surface2);color:var(--gray)}
.cell-domain{font-size:10px;padding:2px 6px;border-radius:4px;background:var(--surface2);color:var(--text2);white-space:nowrap}
.cell-layer{font-size:10px;padding:2px 6px;border-radius:4px;white-space:nowrap}
.cell-layer.backend{background:#1a2e3a;color:var(--cyan)}
.cell-layer.frontend{background:#2e1a3a;color:var(--purple)}
.cell-layer.infrastructure{background:#2e2a10;color:var(--yellow)}
.cell-layer.integrationdeployment{background:#1a3a2e;color:var(--lime)}
.cell-layer.unknown{background:var(--surface2);color:var(--gray)}

/* Status badge */
.status-badge{font-size:11px;font-weight:600;padding:2px 8px;border-radius:4px}
.status-badge.full{background:#162e23;color:var(--green)}
.status-badge.partial{background:#2e2a10;color:var(--yellow)}
.status-badge.spec-only{background:#2e2216;color:var(--orange)}
.status-badge.none{background:#2e1616;color:var(--red)}
.status-badge.orphan{background:#2e162e;color:var(--purple)}

/* === CLASSIFICATION VIEW === */
.class-grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(280px,1fr));gap:16px;padding-top:16px}
.class-card{background:var(--surface);box-shadow:var(--shadow-sm);border:none;border-radius:var(--radius);overflow:hidden;transition:box-shadow .2s ease}
.class-card:hover{box-shadow:var(--shadow-md)}
.class-card-header{padding:12px 16px;border-bottom:1px solid var(--border);display:flex;justify-content:space-between;align-items:center}
.class-card-header h3{font-size:14px;font-weight:600}
.class-card-header .class-count{font-size:20px;font-weight:700;color:var(--accent)}
.class-card-body{padding:8px 0;max-height:300px;overflow-y:auto}
.class-item{padding:6px 16px;display:flex;align-items:center;gap:8px;cursor:pointer;font-size:13px}
.class-item:hover{background:var(--surface2)}
.class-item .item-id{font-family:var(--mono);font-size:11px;font-weight:600;color:var(--accent);min-width:110px}
.class-item .item-title{flex:1;overflow:hidden;text-overflow:ellipsis;white-space:nowrap;color:var(--text2)}
.class-item .item-status{width:8px;height:8px;border-radius:50%;flex-shrink:0}
.class-item .item-status.full{background:var(--green)}
.class-item .item-status.partial{background:var(--yellow)}
.class-item .item-status.spec-only{background:var(--orange)}
.class-item .item-status.none{background:var(--red)}
.class-bar{height:4px;background:var(--surface2);margin:0 16px 8px}
.class-bar-fill{height:100%;border-radius:2px;transition:width .3s}

/* === CODE COVERAGE VIEW === */
.cov-list{padding-top:16px}
.cov-file{background:var(--surface);box-shadow:var(--shadow-sm);border:none;border-radius:var(--radius);margin-bottom:8px;overflow:hidden}
.cov-file-header{padding:10px 16px;display:flex;align-items:center;gap:12px;cursor:pointer}
.cov-file-header:hover{background:var(--surface2)}
.cov-file-path{font-family:var(--mono);font-size:12px;flex:1;overflow:hidden;text-overflow:ellipsis;white-space:nowrap}
.cov-file-pct{font-size:13px;font-weight:700;min-width:50px;text-align:right}
.cov-file-pct.high{color:var(--green)}
.cov-file-pct.mid{color:var(--yellow)}
.cov-file-pct.low{color:var(--red)}
.cov-file-pct.zero{color:var(--gray)}
.cov-bar{width:100px;height:6px;background:var(--surface2);border-radius:3px;overflow:hidden}
.cov-bar-fill{height:100%;border-radius:3px}
.cov-file-symbols{display:none;padding:0 16px 8px;border-top:1px solid var(--border)}
.cov-file.open .cov-file-symbols{display:block}
.cov-symbol{padding:4px 0;font-size:12px;display:flex;align-items:center;gap:8px}
.cov-symbol-name{font-family:var(--mono);color:var(--text)}
.cov-symbol-type{font-size:10px;color:var(--text3);background:var(--surface2);padding:1px 6px;border-radius:3px}
.cov-symbol-refs{font-size:11px;color:var(--accent)}
.cov-summary{display:grid;grid-template-columns:repeat(auto-fit,minmax(200px,1fr));gap:12px;margin-bottom:16px}

/* === DETAIL PANEL (5 tabs) === */
.detail-overlay{position:fixed;top:0;right:0;bottom:0;left:0;background:rgba(0,0,0,.5);z-index:200;display:none;opacity:0;transition:opacity .2s}
.detail-overlay.open{display:block;opacity:1}
.detail-panel{position:fixed;top:0;right:0;bottom:0;width:520px;max-width:90vw;background:var(--surface);border-left:1px solid var(--border);z-index:201;transform:translateX(100%);transition:transform .25s ease;overflow-y:auto;display:flex;flex-direction:column}
.detail-panel.open{transform:translateX(0)}
.detail-header{padding:20px 20px 0;flex-shrink:0}
.detail-close{position:absolute;top:12px;right:12px;background:none;border:none;color:var(--text2);font-size:20px;cursor:pointer;padding:4px 8px;border-radius:4px}
.detail-close:hover{background:var(--surface2);color:var(--text)}
.detail-id{font-family:var(--mono);font-size:16px;font-weight:700;color:var(--accent);margin-bottom:4px}
.detail-title{font-size:14px;color:var(--text);margin-bottom:4px}
.detail-file{font-family:var(--mono);font-size:12px;color:var(--text2);margin-bottom:4px}
.detail-badges{display:flex;gap:6px;flex-wrap:wrap;margin-bottom:12px}
.detail-badge{font-size:10px;padding:2px 8px;border-radius:4px;font-weight:600}

/* Detail Tabs */
.detail-tabs{display:flex;gap:0;border-bottom:1px solid var(--border);flex-shrink:0;padding:0 20px;overflow-x:auto}
.detail-tab{padding:8px 14px;font-size:12px;font-weight:600;color:var(--text2);background:none;border:none;border-bottom:2px solid transparent;cursor:pointer;white-space:nowrap}
.detail-tab:hover{color:var(--text)}
.detail-tab.active{color:var(--accent);border-bottom-color:var(--accent)}
.detail-tab-content{display:none;padding:16px 20px;flex:1;overflow-y:auto}
.detail-tab-content.active{display:block}

/* Story tab */
.story-text{font-size:14px;line-height:1.7;color:var(--text)}
.story-text strong{color:var(--accent)}
.story-text .story-highlight{background:var(--surface2);padding:2px 6px;border-radius:4px;font-family:var(--mono);font-size:12px}

/* Trace Chain tab */
.detail-chain{list-style:none}
.detail-chain li{padding:4px 0 4px 16px;position:relative;font-size:13px}
.detail-chain li::before{content:'';position:absolute;left:4px;top:0;bottom:0;width:2px;background:var(--border)}
.detail-chain li::after{content:'';position:absolute;left:1px;top:11px;width:8px;height:8px;border-radius:50%;background:var(--accent);border:2px solid var(--surface)}
.detail-chain li .chain-id{font-family:var(--mono);font-weight:600;color:var(--accent);cursor:pointer}
.detail-chain li .chain-type{font-size:11px;color:var(--text2);margin-left:6px}
.detail-chain li .chain-file{font-size:11px;color:var(--text2);display:block}

/* Code tab */
.code-ref{padding:8px 0;border-bottom:1px solid var(--border)}
.code-ref:last-child{border-bottom:none}
.code-ref-file{font-family:var(--mono);font-size:12px;color:var(--accent)}
.code-ref-symbol{font-family:var(--mono);font-size:13px;font-weight:600;margin-top:2px}
.code-ref-type{font-size:10px;color:var(--text3);background:var(--surface2);padding:1px 6px;border-radius:3px;margin-left:6px}
.code-ref-ids{font-size:11px;color:var(--text2);margin-top:2px}

/* Tests tab */
.test-ref{padding:8px 0;border-bottom:1px solid var(--border)}
.test-ref:last-child{border-bottom:none}
.test-ref-file{font-family:var(--mono);font-size:12px;color:var(--accent)}
.test-ref-name{font-size:13px;margin-top:2px}
.test-ref-framework{font-size:10px;color:var(--text3);background:var(--surface2);padding:1px 6px;border-radius:3px;margin-left:6px}
.test-ref-ids{font-size:11px;color:var(--text2);margin-top:2px}

/* Documents tab */
.doc-group{margin-bottom:12px}
.doc-group h4{font-size:11px;color:var(--text2);text-transform:uppercase;letter-spacing:.5px;margin-bottom:6px;padding-bottom:4px;border-bottom:1px solid var(--border)}
.doc-item{padding:4px 0;font-size:13px;display:flex;align-items:center;gap:8px}
.doc-item-id{font-family:var(--mono);font-weight:600;color:var(--accent);cursor:pointer;min-width:100px}
.doc-item-title{color:var(--text2);overflow:hidden;text-overflow:ellipsis;white-space:nowrap}

/* === ADOPTION VIEW === */
.adopt-grid{display:grid;grid-template-columns:1fr;gap:16px;padding-top:16px}
.adopt-row-2{display:grid;grid-template-columns:1fr 2fr;gap:16px}
.adopt-row-2b{display:grid;grid-template-columns:1fr 1fr;gap:16px}
.adopt-card{background:var(--surface);box-shadow:var(--shadow-sm);border:none;border-radius:var(--radius);padding:16px}
.adopt-card h3{font-size:13px;text-transform:uppercase;letter-spacing:.5px;color:var(--text2);margin-bottom:12px}
.adopt-journey-steps{display:flex;gap:0;overflow-x:auto;padding:8px 0}
.adopt-step{flex:1;min-width:140px;padding:12px;text-align:center;border-right:1px solid var(--border);position:relative}
.adopt-step:last-child{border-right:none}
.adopt-step-num{font-size:20px;font-weight:800;color:var(--accent);margin-bottom:4px}
.adopt-step-skill{font-family:var(--mono);font-size:11px;color:var(--text2);margin-bottom:4px}
.adopt-step-desc{font-size:12px;color:var(--text3)}
.adopt-step-effort{font-size:10px;margin-top:4px;padding:2px 6px;border-radius:4px;display:inline-block}
.adopt-step-effort.high{background:#2e1616;color:var(--red)}
.adopt-step-effort.medium{background:#2e2a10;color:var(--yellow)}
.adopt-step-effort.low{background:#162e23;color:var(--green)}
.adopt-step.done{opacity:.5}
.adopt-step.done .adopt-step-num{color:var(--green)}
.adopt-step.done::after{content:'\2713';position:absolute;top:8px;right:8px;color:var(--green);font-size:14px;font-weight:700}
.adopt-scenario-name{font-size:18px;font-weight:700;color:var(--text);margin-bottom:4px}
.adopt-confidence{font-size:12px;color:var(--text2);margin-bottom:12px}
.adopt-signal{display:inline-block;font-size:11px;background:var(--surface2);color:var(--text2);padding:2px 8px;border-radius:4px;margin:2px 4px 2px 0;font-family:var(--mono)}
.adopt-dim{display:flex;align-items:center;gap:8px;padding:4px 0;font-size:13px}
.adopt-dim-label{width:120px;color:var(--text2);font-size:12px}
.adopt-dim-bar{flex:1;height:8px;background:var(--surface2);border-radius:4px;overflow:hidden}
.adopt-dim-fill{height:100%;border-radius:4px;transition:width .3s}
.adopt-dim-val{width:36px;text-align:right;font-size:12px;font-weight:600;font-family:var(--mono)}
.adopt-severity-bar{display:flex;height:24px;border-radius:4px;overflow:hidden;margin-bottom:12px}
.adopt-severity-seg{display:flex;align-items:center;justify-content:center;font-size:11px;font-weight:600}
.adopt-cat-row{display:flex;align-items:center;gap:8px;padding:3px 0;font-size:12px}
.adopt-cat-label{width:120px;color:var(--text2);font-family:var(--mono);font-size:11px}
.adopt-cat-count{font-weight:600;color:var(--text)}
.adopt-finding-row{padding:6px 0;border-bottom:1px solid var(--border);font-size:12px}
.adopt-finding-row:last-child{border-bottom:none}
.adopt-finding-id{font-family:var(--mono);font-weight:600;color:var(--accent);margin-right:6px}
.adopt-finding-sev{font-size:10px;padding:1px 6px;border-radius:3px;font-weight:600;margin-right:6px}
.adopt-finding-sev.critical{background:#2e1616;color:var(--red)}
.adopt-finding-sev.high{background:#2e2216;color:var(--orange)}
.adopt-align-pct{font-size:36px;font-weight:800;margin-bottom:4px}
.adopt-div-table{font-size:12px;width:100%;margin-top:8px}
.adopt-div-table td{padding:3px 8px;border-bottom:1px solid var(--border)}
.adopt-div-table td:first-child{font-family:var(--mono);color:var(--text2);font-size:11px}
.adopt-div-table td:last-child{text-align:right;font-weight:600}
.adopt-import-row{display:flex;align-items:center;gap:12px;padding:6px 0;border-bottom:1px solid var(--border);font-size:12px}
.adopt-import-row:last-child{border-bottom:none}
.adopt-import-format{font-family:var(--mono);font-weight:600;color:var(--accent);min-width:60px}
.adopt-import-file{flex:1;color:var(--text2);overflow:hidden;text-overflow:ellipsis;white-space:nowrap}
.adopt-import-metric{text-align:right;font-weight:600}
.adopt-source-table{width:100%;margin-top:8px}
.adopt-empty{text-align:center;padding:40px 24px;color:var(--text2)}
.adopt-empty h3{font-size:16px;margin-bottom:8px;color:var(--text)}
.adopt-empty-cmd{font-family:var(--mono);font-size:13px;color:var(--accent);background:var(--surface2);padding:4px 12px;border-radius:4px;display:inline-block;margin-top:8px}
@media(max-width:768px){
  .adopt-row-2,.adopt-row-2b{grid-template-columns:1fr}
}

/* Empty state */
.empty{text-align:center;padding:60px 24px;color:var(--text2)}
.empty h2{font-size:18px;margin-bottom:8px;color:var(--text)}
.empty p{font-size:14px}
.empty-section{text-align:center;padding:30px;color:var(--text2);font-size:13px}

/* === INTERACTIVE PROMPTS & LIVE STATUS === */

/* Toast notification */
.toast{position:fixed;bottom:24px;right:24px;background:var(--surface2);color:var(--text);padding:10px 18px;border-radius:var(--radius);font-size:13px;z-index:400;box-shadow:var(--shadow-lg);opacity:0;transform:translateY(16px);transition:opacity .2s,transform .2s;pointer-events:none;display:flex;align-items:center;gap:8px;border:1px solid var(--border)}
.toast.visible{opacity:1;transform:translateY(0);pointer-events:auto}
.toast.success{border-left:3px solid var(--green)}
.toast.error{border-left:3px solid var(--red)}
.toast.info{border-left:3px solid var(--accent)}

/* Copy button */
.copy-btn{background:var(--surface2);border:1px solid var(--border);border-radius:4px;color:var(--text2);padding:3px 8px;font-size:11px;cursor:pointer;display:inline-flex;align-items:center;gap:4px;transition:background .15s,color .15s,border-color .15s;white-space:nowrap;vertical-align:middle}
.copy-btn:hover{background:var(--surface3);color:var(--text);border-color:var(--accent)}
.copy-btn::before{content:'\2398';font-size:13px}
.copy-btn.copied{border-color:var(--green);color:var(--green)}
.copy-btn.copied::before{content:'\2713'}

/* Next Action card */
.next-action-card{background:var(--surface);box-shadow:var(--shadow-md);border:none;border-radius:var(--radius);padding:20px;margin-bottom:16px;border-left:3px solid var(--accent);animation:fadeUp .3s ease backwards}
.next-action-card h3{font-size:13px;text-transform:uppercase;letter-spacing:.5px;color:var(--accent);margin-bottom:8px;display:flex;align-items:center;gap:8px}
.next-action-card .next-reason{font-size:13px;color:var(--text2);margin-bottom:12px}
.next-action-card .prompt-block{margin:0}

/* Prompt block */
.prompt-block{background:var(--bg);border:1px solid var(--border);border-radius:var(--radius);padding:12px 16px;font-family:var(--mono);font-size:12px;line-height:1.6;color:var(--text);position:relative;white-space:pre-wrap;word-break:break-word}
.prompt-block .copy-btn{position:absolute;top:8px;right:8px}

/* Activity feed panel */
.activity-panel{background:var(--surface);box-shadow:var(--shadow-sm);border:none;border-radius:var(--radius);padding:16px;margin-top:16px}
.activity-panel h3{font-size:13px;text-transform:uppercase;letter-spacing:.5px;color:var(--text2);margin-bottom:12px;display:flex;align-items:center;gap:8px}
.activity-feed{max-height:240px;overflow-y:auto}
.activity-entry{display:flex;align-items:flex-start;gap:10px;padding:6px 0;border-bottom:1px solid var(--border);font-size:12px}
.activity-entry:last-child{border-bottom:none}
.activity-icon{width:20px;height:20px;border-radius:50%;display:flex;align-items:center;justify-content:center;font-size:10px;flex-shrink:0;margin-top:2px}
.activity-icon.running{background:#2e2a10;color:var(--yellow)}
.activity-icon.done{background:#162e23;color:var(--green)}
.activity-icon.error{background:#2e1616;color:var(--red)}
.activity-icon.info{background:var(--surface2);color:var(--text2)}
.activity-body{flex:1}
.activity-stage{font-weight:600;color:var(--text)}
.activity-msg{color:var(--text2)}
.activity-time{font-size:10px;color:var(--text3);white-space:nowrap;margin-top:2px}
.activity-empty{text-align:center;padding:24px;color:var(--text2);font-size:13px}

/* Stage popover */
.stage-popover{position:absolute;top:calc(100% + 8px);left:50%;transform:translateX(-50%);background:var(--surface2);border:1px solid var(--border);border-radius:var(--radius);padding:16px;min-width:300px;max-width:400px;z-index:150;box-shadow:var(--shadow-lg);display:none;text-align:left}
.stage-popover.open{display:block}
.stage-popover::before{content:'';position:absolute;top:-6px;left:50%;transform:translateX(-50%) rotate(45deg);width:10px;height:10px;background:var(--surface2);border-left:1px solid var(--border);border-top:1px solid var(--border)}
.stage-popover-header{display:flex;justify-content:space-between;align-items:center;margin-bottom:10px}
.stage-popover-status{font-size:11px;font-weight:600;padding:2px 8px;border-radius:4px}
.stage-popover-info{font-size:12px;color:var(--text2);margin-bottom:10px}
.stage-popover-actions{display:flex;gap:8px;margin-top:10px}
.stage-popover-filter{font-size:11px;padding:4px 10px;background:var(--surface3);border:1px solid var(--border);border-radius:4px;color:var(--text2);cursor:pointer}
.stage-popover-filter:hover{background:var(--accent);color:var(--bg);border-color:var(--accent)}

/* Live dot */
.live-dot{width:8px;height:8px;border-radius:50%;background:var(--green);display:inline-block;animation:livePulse 2s ease-in-out infinite}
.live-dot.stale{background:var(--yellow);animation:none}
.live-dot.off{display:none}
@keyframes livePulse{0%,100%{opacity:1}50%{opacity:.3}}

/* Responsive */
@media(max-width:768px){
  .pipeline{flex-wrap:wrap}
  .pipeline-stage{min-width:90px}
  .stats{grid-template-columns:repeat(2,1fr)}
  .hero{flex-direction:column}
  .summary-grid{grid-template-columns:1fr}
  .summary-card:nth-child(1){grid-column:auto}
  .summary-card:nth-child(2){grid-row:auto;grid-column:auto}
  .detail-panel{width:100%}
  .class-grid{grid-template-columns:1fr}
  .stage-popover{min-width:250px;left:0;transform:none}
  .stage-popover::before{left:20%}
  .toast{left:16px;right:16px;bottom:16px}
}
</style>
</head>
<body>

<div class="header">
  <h1><span>SDD</span> Dashboard <span class="header-version">v5</span></h1>
  <div class="header-meta">
    <span id="hdr-project"></span> &middot; <span id="hdr-time"></span>
    <a href="guide.html" class="header-guide" title="System documentation and dashboard guide">Guide</a>
  </div>
</div>

<div class="pipeline" id="pipeline"></div>

<div class="stats" id="stats"></div>

<!-- Health Score Hero -->
<div class="hero" id="hero"></div>

<!-- Legend -->
<div class="legend" id="legend">
  <span class="legend-item"><span class="legend-dot" style="background:var(--green)"></span> Complete</span>
  <span class="legend-item"><span class="legend-dot" style="background:var(--yellow)"></span> In Progress</span>
  <span class="legend-item"><span class="legend-dot" style="background:var(--orange)"></span> Specified</span>
  <span class="legend-item"><span class="legend-dot" style="background:var(--red)"></span> Not Started</span>
</div>

<!-- View Tabs -->
<div class="view-tabs">
  <button class="view-tab active" data-view="summary">Summary</button>
  <button class="view-tab" data-view="matrix">Matrix</button>
  <button class="view-tab" data-view="classification">Classification</button>
  <button class="view-tab" data-view="coverage">Code Coverage</button>
  <button class="view-tab" data-view="adoption">Adoption</button>
</div>

<!-- Filters -->
<div class="filters" id="filterBar">
  <input type="text" class="filter-input" id="fSearch" placeholder="Search by ID or title...">
  <select class="filter-select" id="fStatus"><option value="">All Status</option><option value="full">Complete</option><option value="partial">In Progress</option><option value="spec-only">Specified</option><option value="none">Not Started</option></select>
  <select class="filter-select" id="fPriority"><option value="">All Priority</option></select>
  <select class="filter-select" id="fType"><option value="">All Types</option></select>
  <select class="filter-select" id="fStage"><option value="">All Stages</option></select>
  <select class="filter-select" id="fDomain"><option value="">All Domains</option></select>
  <select class="filter-select" id="fLayer"><option value="">All Layers</option></select>
  <select class="filter-select" id="fCategory"><option value="">All Categories</option></select>
  <span class="filter-badge" id="fCount"></span>
</div>

<!-- SUMMARY VIEW -->
<div class="view active" id="view-summary"></div>

<!-- MATRIX VIEW -->
<div class="view" id="view-matrix">
  <div class="table-wrap">
    <table id="matrix">
      <thead>
        <tr>
          <th data-col="id" title="Requirement identifier">ID <span class="sort-icon">&#9650;</span></th>
          <th data-col="title" title="Requirement description">Title <span class="sort-icon">&#9650;</span></th>
          <th data-col="priority" title="MoSCoW priority level">Priority <span class="sort-icon">&#9650;</span></th>
          <th data-col="domain" title="Business domain (auto-classified from REQ prefix)">Domain <span class="sort-icon">&#9650;</span></th>
          <th data-col="layer" title="Technical layer: Infrastructure, Backend, Frontend (from FASE)">Layer <span class="sort-icon">&#9650;</span></th>
          <th data-col="uc" title="Use Cases — functional scenarios that implement this requirement">Use Cases <span class="sort-icon">&#9650;</span></th>
          <th data-col="wf" title="Workflows — process orchestrations for this requirement">Workflows <span class="sort-icon">&#9650;</span></th>
          <th data-col="api" title="API Contracts — endpoints and interfaces for this requirement">Contracts <span class="sort-icon">&#9650;</span></th>
          <th data-col="bdd" title="BDD Scenarios — behavior-driven tests that verify this requirement">Acceptance <span class="sort-icon">&#9650;</span></th>
          <th data-col="inv" title="Invariants — domain business rules that guarantee this requirement">Rules <span class="sort-icon">&#9650;</span></th>
          <th data-col="adr" title="Architecture Decision Records — design decisions for this requirement">Decisions <span class="sort-icon">&#9650;</span></th>
          <th data-col="task" title="Implementation Tasks — work items to build this requirement">Tasks <span class="sort-icon">&#9650;</span></th>
          <th data-col="code" title="Code References — source functions/classes referencing this requirement">Code <span class="sort-icon">&#9650;</span></th>
          <th data-col="tests" title="Test References — test cases verifying this requirement">Tests <span class="sort-icon">&#9650;</span></th>
          <th data-col="status" title="Traceability status: Full (all linked), Partial (code/tests), Spec Only (UC only), Untraced">Status <span class="sort-icon">&#9650;</span></th>
        </tr>
      </thead>
      <tbody id="tbody"></tbody>
    </table>
  </div>
</div>

<!-- CLASSIFICATION VIEW -->
<div class="view" id="view-classification">
  <div class="class-grid" id="classGrid"></div>
</div>

<!-- CODE COVERAGE VIEW -->
<div class="view" id="view-coverage">
  <div class="cov-summary" id="covSummary"></div>
  <div class="cov-list" id="covList"></div>
</div>

<!-- ADOPTION VIEW -->
<div class="view" id="view-adoption"></div>

<!-- Empty state -->
<div class="empty" id="empty" style="display:none">
  <h2>No artifacts found</h2>
  <p>Run the SDD pipeline to generate traceability artifacts, then re-run <code>/sdd-dashboard</code>.</p>
</div>

<!-- Detail Panel -->
<div class="detail-overlay" id="detailOverlay"></div>
<div class="detail-panel" id="detailPanel" role="dialog" aria-modal="true" aria-label="Artifact detail panel">
  <div class="detail-header">
    <button class="detail-close" id="detailClose">&times;</button>
    <div class="detail-id" id="dId"></div>
    <div class="detail-title" id="dTitle"></div>
    <div class="detail-file" id="dFile"></div>
    <div class="detail-badges" id="dBadges"></div>
  </div>
  <div class="detail-tabs">
    <button class="detail-tab active" data-dtab="story">Story</button>
    <button class="detail-tab" data-dtab="trace">Trace Chain</button>
    <button class="detail-tab" data-dtab="code">Code</button>
    <button class="detail-tab" data-dtab="tests">Tests</button>
    <button class="detail-tab" data-dtab="docs">Documents</button>
  </div>
  <div class="detail-tab-content active" id="dtab-story"></div>
  <div class="detail-tab-content" id="dtab-trace">
    <div class="detail-section">
      <h3 style="font-size:12px;color:var(--text2);text-transform:uppercase;letter-spacing:.5px;margin-bottom:8px;padding-bottom:4px;border-bottom:1px solid var(--border)">Incoming (referenced by)</h3>
      <ul class="detail-chain" id="dIncoming"></ul>
    </div>
    <div class="detail-section" style="margin-top:16px">
      <h3 style="font-size:12px;color:var(--text2);text-transform:uppercase;letter-spacing:.5px;margin-bottom:8px;padding-bottom:4px;border-bottom:1px solid var(--border)">Outgoing (references)</h3>
      <ul class="detail-chain" id="dOutgoing"></ul>
    </div>
  </div>
  <div class="detail-tab-content" id="dtab-code"></div>
  <div class="detail-tab-content" id="dtab-tests"></div>
  <div class="detail-tab-content" id="dtab-docs"></div>
</div>

<script>
(function(){
  "use strict";
  var DATA = {{DATA_JSON}};

  // --- Helpers ---
  var $ = function(s){return document.getElementById(s)};
  var ce = function(t){return document.createElement(t)};
  function esc(s){var d=ce("span");d.textContent=s;return d.innerHTML}

  // --- Human Labels ---
  var LABELS = {
    UC: "Use Cases", WF: "Workflows", API: "API Contracts",
    BDD: "Acceptance Tests", INV: "Business Rules", ADR: "Decisions",
    TASK: "Tasks", REQ: "Requirements", NFR: "Quality Attrs",
    FASE: "Phases", RN: "Business Rules (RN)"
  };
  function humanLabel(abbr) { return LABELS[abbr] || abbr; }

  // --- Contextual Prompt Generation ---
  var STAGE_ORDER = ["requirements-engineer","specifications-engineer","spec-auditor","test-planner","plan-architect","task-generator","task-implementer"];
  var STAGE_LABELS = {
    "requirements-engineer":"Ingenieria de Requisitos","specifications-engineer":"Ingenieria de Especificaciones",
    "spec-auditor":"Auditor de Especificaciones","test-planner":"Planificador de Tests",
    "plan-architect":"Arquitecto de Plan","task-generator":"Generador de Tareas","task-implementer":"Implementador de Tareas"
  };

  function getStagePrompt(stageName, stageStatus) {
    var stCov = (DATA.statistics || {}).traceabilityCoverage || {};
    if (stageStatus === "stale") {
      return "El stage " + stageName + " esta stale porque sus inputs cambiaron. Re-ejecuta el skill para actualizar los artefactos de salida.\n\nEjecuta /sdd-" + stageName;
    }
    if (stageStatus === "running") {
      return "El stage " + stageName + " esta en ejecucion. Espera a que termine.";
    }
    if (stageStatus === "done") {
      return "El stage " + stageName + " esta completado. Puedes avanzar al siguiente stage.";
    }

    var ucGap = stCov.reqsWithUCs ? ((stCov.reqsWithUCs.total || 0) - (stCov.reqsWithUCs.count || 0)) : 0;
    var bddGap = stCov.reqsWithBDD ? ((stCov.reqsWithBDD.total || 0) - (stCov.reqsWithBDD.count || 0)) : 0;
    var taskGap = stCov.reqsWithTasks ? ((stCov.reqsWithTasks.total || 0) - (stCov.reqsWithTasks.count || 0)) : 0;

    switch (stageName) {
      case "requirements-engineer":
        return "Necesito definir los requisitos del proyecto. Captura requisitos funcionales y no funcionales usando sintaxis EARS.\n\nEjecuta /sdd-requirements-engineer";
      case "specifications-engineer":
        var msg = "Necesito transformar los requisitos en especificaciones formales (Use Cases, Workflows, API Contracts, BDD Scenarios, Invariants, ADRs).";
        if (ucGap > 0) msg += "\n\nHay " + ucGap + " requisitos sin Use Cases.";
        return msg + "\n\nEjecuta /sdd-specifications-engineer";
      case "spec-auditor":
        return "Necesito auditar las especificaciones para detectar ambiguedades, silencios peligrosos, contradicciones e invariantes implicitos.\n\nEjecuta /sdd-spec-auditor";
      case "test-planner":
        var tmsg = "Necesito generar el plan de testing (test matrix, BDD scenarios, performance scenarios).";
        if (bddGap > 0) tmsg += "\n\nHay " + bddGap + " requisitos sin cobertura BDD.";
        return tmsg + "\n\nEjecuta /sdd-test-planner";
      case "plan-architect":
        return "Necesito disenar el plan de implementacion: FASEs, arquitectura y mapeo spec-to-phase.\n\nEjecuta /sdd-plan-architect";
      case "task-generator":
        var gmsg = "Necesito descomponer las FASEs en tareas atomicas con commits convencionales y trazabilidad.";
        if (taskGap > 0) gmsg += "\n\nHay " + taskGap + " requisitos sin tareas.";
        return gmsg + "\n\nEjecuta /sdd-task-generator";
      case "task-implementer":
        return "Necesito implementar las tareas: desarrollo test-first, commits atomicos, verificacion de trazabilidad.\n\nEjecuta /sdd-task-implementer";
      default:
        return "Ejecuta /sdd-" + stageName;
    }
  }

  function getNextAction() {
    var pipeline = DATA.pipeline || {};
    var stages = pipeline.stages || [];
    var stCov = (DATA.statistics || {}).traceabilityCoverage || {};

    // Priority 1: stale stages
    for (var i = 0; i < STAGE_ORDER.length; i++) {
      var m = null;
      for (var si = 0; si < stages.length; si++) { if (stages[si].name === STAGE_ORDER[i]) { m = stages[si]; break; } }
      if (m && m.status === "stale") {
        return { stage: STAGE_ORDER[i], status: "stale", reason: "Stage stale — sus inputs cambiaron", prompt: getStagePrompt(STAGE_ORDER[i], "stale") };
      }
    }

    // Priority 2: first pending stage (if previous is done)
    for (var j = 0; j < STAGE_ORDER.length; j++) {
      var m2 = null;
      for (var sj = 0; sj < stages.length; sj++) { if (stages[sj].name === STAGE_ORDER[j]) { m2 = stages[sj]; break; } }
      if (!m2 || m2.status === "pending" || m2.status === "unknown") {
        if (j === 0) {
          return { stage: STAGE_ORDER[j], status: "pending", reason: "Primer stage del pipeline", prompt: getStagePrompt(STAGE_ORDER[j], "pending") };
        }
        var prev = null;
        for (var sp = 0; sp < stages.length; sp++) { if (stages[sp].name === STAGE_ORDER[j-1]) { prev = stages[sp]; break; } }
        if (prev && prev.status === "done") {
          var reason = "Siguiente stage pendiente en el pipeline";
          var ucInfo = stCov.reqsWithUCs || {};
          var bddInfo = stCov.reqsWithBDD || {};
          if (STAGE_ORDER[j] === "specifications-engineer" && ucInfo.total && ucInfo.count < ucInfo.total) {
            reason = (ucInfo.total - ucInfo.count) + " requisitos sin Use Cases";
          } else if (STAGE_ORDER[j] === "test-planner" && bddInfo.total && bddInfo.count < bddInfo.total) {
            reason = (bddInfo.total - bddInfo.count) + " requisitos sin cobertura BDD";
          }
          return { stage: STAGE_ORDER[j], status: "pending", reason: reason, prompt: getStagePrompt(STAGE_ORDER[j], "pending") };
        }
      }
    }

    // Priority 3: coverage gaps
    var ucGap = stCov.reqsWithUCs ? ((stCov.reqsWithUCs.total || 0) - (stCov.reqsWithUCs.count || 0)) : 0;
    if (ucGap > 0) {
      return { stage: "specifications-engineer", status: "gap", reason: ucGap + " requisitos sin Use Cases", prompt: getStagePrompt("specifications-engineer", "pending") };
    }

    return { stage: null, status: "ok", reason: "Pipeline completo. Todo al dia.", prompt: "El pipeline SDD esta completo y saludable." };
  }

  // --- Health Score ---
  var TARGETS = { ucs: 90, bdd: 70, tasks: 80, code: 60, tests: 50 };
  function computeHealthScore(cov) {
    if (!cov) return 0;
    var metrics = [
      { val: (cov.reqsWithUCs || {}).percentage || 0, target: TARGETS.ucs, weight: 25 },
      { val: (cov.reqsWithBDD || {}).percentage || 0, target: TARGETS.bdd, weight: 20 },
      { val: (cov.reqsWithTasks || {}).percentage || 0, target: TARGETS.tasks, weight: 20 },
      { val: (cov.reqsWithCode || {}).percentage || 0, target: TARGETS.code, weight: 20 },
      { val: (cov.reqsWithTests || {}).percentage || 0, target: TARGETS.tests, weight: 15 }
    ];
    var score = 0;
    metrics.forEach(function(m) {
      score += Math.min(m.val / m.target, 1) * m.weight;
    });
    score = Math.round(score);
    var audit = (DATA.statistics || {}).auditData;
    if (audit && audit.latestGate === "FAIL") {
      score = Math.max(0, score - 10);
    }
    return score;
  }

  function healthGrade(score) {
    if (score >= 90) return { letter: "A", color: "var(--green)", label: "Excellent" };
    if (score >= 75) return { letter: "B", color: "var(--accent)", label: "Good" };
    if (score >= 60) return { letter: "C", color: "var(--yellow)", label: "Needs Work" };
    if (score >= 40) return { letter: "D", color: "var(--orange)", label: "At Risk" };
    return { letter: "F", color: "var(--red)", label: "Critical" };
  }

  // --- Recommendations ---
  function generateRecommendations(cov, st) {
    var recs = [];
    var c = cov || {};
    var uc = c.reqsWithUCs || {};
    if ((uc.percentage || 0) < TARGETS.ucs) {
      var gap = (uc.total || 0) - (uc.count || 0);
      recs.push({ priority: "high", text: gap + " requirements lack use cases", action: "Run /sdd-specifications-engineer", prompt: getStagePrompt("specifications-engineer", "pending") });
    }
    var cod = c.reqsWithCode || {};
    if ((cod.percentage || 0) < TARGETS.code) {
      var gap2 = (cod.total || 0) - (cod.count || 0);
      recs.push({ priority: "high", text: gap2 + " requirements have no code references", action: "Add Refs: comments to source files", prompt: "Agrega comentarios Refs: en tu codigo fuente para vincular funciones a requisitos SDD.\n\nEjemplo:\n/**\n * Refs: UC-001, INV-EXT-005\n */\nfunction validateInput() { ... }" });
    }
    var tst = c.reqsWithTests || {};
    if ((tst.percentage || 0) < TARGETS.tests) {
      var gap3 = (tst.total || 0) - (tst.count || 0);
      recs.push({ priority: "medium", text: gap3 + " requirements have no test coverage", action: "Add Refs: to test descriptions", prompt: "Agrega comentarios Refs: en tus archivos de test para vincular tests a requisitos.\n\nEjemplo:\n// Refs: UC-001, INV-EXT-005\ndescribe('Validation', () => { ... })" });
    }
    var orphans = (st.orphans || []).length;
    if (orphans > 0) recs.push({ priority: "medium", text: orphans + " orphaned artifacts found", action: "Review and link or remove", prompt: "Ejecuta /sdd-traceability-check para ver los artefactos huerfanos y decidir si vincularlos o eliminarlos." });
    var broken = (st.brokenReferences || []).length;
    if (broken > 0) recs.push({ priority: "high", text: broken + " broken references", action: "Fix or remove invalid references", prompt: "Ejecuta /sdd-traceability-check para localizar las referencias rotas y corregirlas." });
    var audit = st.auditData;
    if (audit && audit.latestGate === "FAIL") {
      var critHigh = ((audit.bySeverity || {}).critical || 0) + ((audit.bySeverity || {}).high || 0);
      recs.push({ priority: "high", text: critHigh + " critical/high audit findings block pipeline", action: "Run /sdd:spec-auditor --fix", prompt: "La auditoria tiene hallazgos criticos/altos sin resolver. El 3C Gate esta en FAIL.\n\nEjecuta /sdd:spec-auditor --fix para corregir los hallazgos." });
    }
    return recs;
  }

  // --- Init Header ---
  $("hdr-project").textContent = DATA.projectName || "SDD Project";
  $("hdr-time").textContent = DATA.generatedAt ? new Date(DATA.generatedAt).toLocaleString() : "";

  // --- Pipeline Bar ---
  var pipeEl = $("pipeline");
  var stageFilter = "";
  var openPopover = null;

  function closeAllPopovers() {
    document.querySelectorAll(".stage-popover.open").forEach(function(p){ p.classList.remove("open"); });
    openPopover = null;
  }

  (DATA.pipeline && DATA.pipeline.stages || []).forEach(function(s, i){
    if(i > 0){
      var arrow = ce("span");
      arrow.className = "pipeline-arrow";
      arrow.innerHTML = '<svg width="20" height="12" viewBox="0 0 20 12"><path d="M0 6h16M12 1l5 5-5 5" fill="none" stroke="var(--border)" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/></svg>';
      pipeEl.appendChild(arrow);
    }
    var cls = "st-" + (s.status || "unknown");
    var div = ce("div");
    div.className = "pipeline-stage " + cls;
    div.setAttribute("role", "button");
    div.setAttribute("tabindex", "0");
    div.dataset.stage = s.name;
    div.innerHTML = '<div class="stage-name">' + esc(s.name.replace(/-/g," ")) + '</div>'
      + '<div class="stage-count">' + (s.artifactCount || 0) + '</div>'
      + '<div class="stage-status">' + esc(s.status || "unknown") + '</div>';

    // Build popover
    var pop = ce("div");
    pop.className = "stage-popover";
    var statusCls = "st-" + (s.status || "unknown");
    var lastRun = s.lastRun ? new Date(s.lastRun).toLocaleString() : "Never";
    var prompt = getStagePrompt(s.name, s.status || "unknown");
    var auditProgHtml = "";
    if (s.name === "spec-auditor" && DATA.statistics && DATA.statistics.auditData && DATA.statistics.auditData.progression && DATA.statistics.auditData.progression.length > 0) {
      var prog = DATA.statistics.auditData.progression;
      var tbl = '<table style="width:100%;font-size:11px;margin:8px 0;border-collapse:collapse">';
      tbl += '<tr style="border-bottom:1px solid var(--border)"><th style="text-align:left;padding:2px 4px">Audit</th><th style="text-align:right;padding:2px 4px">Findings</th><th style="text-align:right;padding:2px 4px">Fixed</th><th style="text-align:right;padding:2px 4px">Accepted</th><th style="text-align:right;padding:2px 4px">Deferred</th><th style="text-align:center;padding:2px 4px">3C</th></tr>';
      prog.forEach(function(row) {
        var gateColor = row.gate === "PASS" ? "var(--green)" : "var(--red)";
        tbl += '<tr><td style="padding:2px 4px">' + esc(row.version) + '</td><td style="text-align:right;padding:2px 4px">' + row.findings + '</td><td style="text-align:right;padding:2px 4px">' + row.fixed + '</td>'
            + '<td style="text-align:right;padding:2px 4px">' + row.accepted + '</td><td style="text-align:right;padding:2px 4px">' + row.deferred + '</td>'
            + '<td style="text-align:center;padding:2px 4px;color:' + gateColor + ';font-weight:600">' + esc(row.gate) + '</td></tr>';
      });
      tbl += '</table>';
      auditProgHtml = tbl;
    }
    pop.innerHTML = '<div class="stage-popover-header">'
      + '<strong>' + esc(STAGE_LABELS[s.name] || s.name.replace(/-/g," ")) + '</strong>'
      + '<span class="stage-popover-status ' + statusCls + '">' + esc(s.status || "unknown") + '</span>'
      + '</div>'
      + '<div class="stage-popover-info">' + (s.artifactCount || 0) + ' artifacts &middot; Last run: ' + esc(lastRun) + '</div>'
      + auditProgHtml
      + '<div class="prompt-block" style="font-size:11px;max-height:120px;overflow-y:auto">' + esc(prompt) + '</div>'
      + '<div class="stage-popover-actions"></div>';
    div.appendChild(pop);

    // Wire popover actions after DOM insertion
    var actionsDiv = pop.querySelector(".stage-popover-actions");
    actionsDiv.appendChild(makeCopyBtn(prompt, "Copy Prompt"));
    var filterBtn = ce("button");
    filterBtn.className = "stage-popover-filter";
    filterBtn.textContent = "Filter by Stage";
    filterBtn.addEventListener("click", function(e) {
      e.stopPropagation();
      closeAllPopovers();
      $("fStage").value = "";
      document.querySelectorAll(".pipeline-stage").forEach(function(e2){e2.classList.remove("active")});
      stageFilter = s.name; div.classList.add("active");
      applyFilters();
    });
    actionsDiv.appendChild(filterBtn);

    div.addEventListener("click", function(e){
      e.stopPropagation();
      if (pop.classList.contains("open")) {
        pop.classList.remove("open");
        openPopover = null;
      } else {
        closeAllPopovers();
        pop.classList.add("open");
        openPopover = pop;
      }
    });
    pipeEl.appendChild(div);
  });

  // Close popover on outside click
  document.addEventListener("click", function(e) {
    if (openPopover && !openPopover.contains(e.target)) {
      closeAllPopovers();
    }
  });

  // --- Stats Cards ---
  var st = DATA.statistics || {};
  var statsEl = $("stats");
  var cov = st.traceabilityCoverage || {};

  addStat("Artifacts", st.totalArtifacts || 0, typeSummary(st.byType), "", "Total number of traced artifacts across all types");
  addStat("Relationships", st.totalRelationships || 0, "", "", "Total number of links between artifacts");
  var covUC = (cov.reqsWithUCs && cov.reqsWithUCs.percentage != null) ? cov.reqsWithUCs.percentage : 0;
  addStat("Requirements with Use Cases", covUC.toFixed(1) + "%", (cov.reqsWithUCs ? cov.reqsWithUCs.count + "/" + cov.reqsWithUCs.total + " functional" : ""), covUC >= 80 ? "good" : "", "Percentage of functional requirements with at least one Use Case (excludes NFR/Constraint REQs)");
  var covCode = (cov.reqsWithCode && cov.reqsWithCode.percentage != null) ? cov.reqsWithCode.percentage : 0;
  addStat("Requirements with Code", covCode.toFixed(1) + "%", (cov.reqsWithCode ? cov.reqsWithCode.count + "/" + cov.reqsWithCode.total : ""), covCode >= 60 ? "good" : "", "Percentage of requirements referenced by source code (Refs: comments)");
  var covTest = (cov.reqsWithTests && cov.reqsWithTests.percentage != null) ? cov.reqsWithTests.percentage : 0;
  addStat("Requirements with Tests", covTest.toFixed(1) + "%", (cov.reqsWithTests ? cov.reqsWithTests.count + "/" + cov.reqsWithTests.total : ""), covTest >= 60 ? "good" : "", "Percentage of requirements referenced by test files");
  var cs = st.commitStats || {};
  if (cs.totalCommits > 0) {
    addStat("Commits", cs.totalCommits, cs.commitsWithRefs + " with refs, " + cs.commitsWithTasks + " with tasks", "", "Git commits with Refs: or Task: trailers linking to SDD artifacts");
    var covCommit = (cov.reqsWithCommits && cov.reqsWithCommits.percentage != null) ? cov.reqsWithCommits.percentage : 0;
    addStat("Requirements with Commits", covCommit.toFixed(1) + "%", (cov.reqsWithCommits ? cov.reqsWithCommits.count + "/" + cov.reqsWithCommits.total : ""), covCommit >= 50 ? "good" : "", "Percentage of requirements linked to at least one git commit via Refs/Task trailers");
  }
  var orphanCount = (st.orphans || []).length;
  addStat("Orphans", orphanCount, "Unreferenced", orphanCount > 0 ? "warn" : "good", "Artifacts not referenced by any other artifact");
  var brokenCount = (st.brokenReferences || []).length;
  addStat("Broken References", brokenCount, "Undefined targets", brokenCount > 0 ? "warn" : "good", "References pointing to artifacts that do not exist");

  var auditD = st.auditData;
  if (auditD && auditD.auditFiles && auditD.auditFiles.length > 0) {
    var gateCls = auditD.latestGate === "PASS" ? "good" : (auditD.latestGate === "FAIL" ? "warn" : "");
    var gateLbl = auditD.latestGate || "N/A";
    var sevSub = "";
    if (auditD.bySeverity) {
      var sv = auditD.bySeverity;
      var parts = [];
      if (sv.critical) parts.push(sv.critical + " crit");
      if (sv.high) parts.push(sv.high + " high");
      if (sv.medium) parts.push(sv.medium + " med");
      if (sv.low) parts.push(sv.low + " low");
      sevSub = parts.join(", ");
    }
    addStat("Audit Gate", gateLbl, auditD.totalFindings + " findings" + (sevSub ? ": " + sevSub : ""), gateCls,
            "3C Gate status from spec-auditor. PASS = all critical/high findings resolved");
  }

  var statIndex = 0;
  function addStat(label, value, sub, cls, tooltip){
    var d = ce("div"); d.className = "stat-card " + cls;
    if(tooltip) d.setAttribute("data-tooltip", tooltip);
    d.style.animationDelay = (statIndex * 0.05) + "s";
    statIndex++;
    d.innerHTML = '<div class="stat-label">' + esc(label) + '</div>'
      + '<div class="stat-value">' + esc(String(value)) + '</div>'
      + '<div class="stat-sub">' + esc(sub) + '</div>';
    statsEl.appendChild(d);
  }
  function typeSummary(bt){
    if(!bt) return "";
    var parts = [];
    Object.keys(bt).forEach(function(k){parts.push(humanLabel(k) + ": " + bt[k])});
    return parts.slice(0,4).join(", ");
  }

  // --- Utility Functions (Interactive) ---
  function showToast(msg, type) {
    var existing = document.querySelector(".toast");
    if (existing) existing.remove();
    var t = ce("div");
    t.className = "toast " + (type || "info");
    t.textContent = msg;
    document.body.appendChild(t);
    requestAnimationFrame(function(){ t.classList.add("visible"); });
    setTimeout(function(){ t.classList.remove("visible"); setTimeout(function(){ t.remove(); }, 200); }, 3000);
  }

  function copyToClipboard(text) {
    if (navigator.clipboard && navigator.clipboard.writeText) {
      navigator.clipboard.writeText(text).then(function(){ showToast("Copied to clipboard!", "success"); }).catch(function(){ fallbackCopy(text); });
    } else {
      fallbackCopy(text);
    }
  }
  function fallbackCopy(text) {
    var ta = ce("textarea");
    ta.value = text; ta.style.position = "fixed"; ta.style.left = "-9999px";
    document.body.appendChild(ta); ta.select();
    try { document.execCommand("copy"); showToast("Copied to clipboard!", "success"); }
    catch(e) { showToast("Copy failed — select manually", "error"); }
    document.body.removeChild(ta);
  }

  function timeAgo(isoDate) {
    if (!isoDate) return "";
    var diff = (Date.now() - new Date(isoDate).getTime()) / 1000;
    if (diff < 60) return Math.floor(diff) + "s ago";
    if (diff < 3600) return Math.floor(diff / 60) + "m ago";
    if (diff < 86400) return Math.floor(diff / 3600) + "h ago";
    return Math.floor(diff / 86400) + "d ago";
  }

  function makeCopyBtn(text, label) {
    var btn = ce("button");
    btn.className = "copy-btn";
    btn.textContent = label || "Copy";
    btn.title = "Copy prompt to clipboard";
    btn.addEventListener("click", function(e) {
      e.stopPropagation();
      copyToClipboard(text);
      btn.classList.add("copied");
      btn.textContent = "Copied!";
      setTimeout(function() { btn.classList.remove("copied"); btn.textContent = label || "Copy"; }, 2000);
    });
    return btn;
  }

  // --- Hero Health Score ---
  var healthScore = computeHealthScore(cov);
  var grade = healthGrade(healthScore);
  var recs = generateRecommendations(cov, st);
  var heroEl = $("hero");

  function renderHealthRing(score, g) {
    var r=52, c=2*Math.PI*r, offset=c-(score/100)*c;
    return '<svg width="140" height="140" viewBox="0 0 120 120">'
      + '<circle cx="60" cy="60" r="52" fill="none" stroke="var(--surface2)" stroke-width="8"/>'
      + '<circle cx="60" cy="60" r="52" fill="none" stroke="'+g.color+'" stroke-width="8" '
      + 'stroke-dasharray="'+c+'" stroke-dashoffset="'+offset+'" '
      + 'stroke-linecap="round" transform="rotate(-90 60 60)" style="transition:stroke-dashoffset 1s ease"/>'
      + '<text x="60" y="55" text-anchor="middle" font-size="36" font-weight="800" fill="'+g.color+'">'+g.letter+'</text>'
      + '<text x="60" y="75" text-anchor="middle" font-size="13" fill="var(--text2)">'+score+'/100</text>'
      + '</svg>';
  }

  var heroHtml = '<div class="hero-score">';
  heroHtml += renderHealthRing(healthScore, grade);
  heroHtml += '<div class="hero-label" style="margin-top:8px">' + grade.label + '</div>';
  heroHtml += '</div>';

  heroHtml += '<div class="hero-actions">';
  if (recs.length > 0) {
    heroHtml += '<h3>Action Required (' + recs.length + ')</h3>';
    recs.forEach(function(r, ri) {
      heroHtml += '<div class="hero-rec">';
      heroHtml += '<span class="hero-rec-dot ' + r.priority + '"></span>';
      heroHtml += '<div style="flex:1"><div class="hero-rec-text">' + esc(r.text) + '</div>';
      heroHtml += '<div class="hero-rec-action">' + esc(r.action) + '</div></div>';
      heroHtml += '<span class="hero-rec-copy" data-rec-idx="' + ri + '"></span>';
      heroHtml += '</div>';
    });
  } else {
    heroHtml += '<div class="hero-ok">All targets met. Pipeline is healthy.</div>';
  }
  heroHtml += '</div>';
  heroEl.innerHTML = heroHtml;

  // Wire up copy buttons on hero recommendations
  heroEl.querySelectorAll(".hero-rec-copy").forEach(function(span) {
    var idx = parseInt(span.getAttribute("data-rec-idx"), 10);
    if (recs[idx] && recs[idx].prompt) {
      span.appendChild(makeCopyBtn(recs[idx].prompt, "Copy"));
    }
  });

  // --- Build indexes ---
  var artById = {};
  (DATA.artifacts || []).forEach(function(a){artById[a.id] = a});

  var incoming = {};
  var outgoing = {};
  (DATA.relationships || []).forEach(function(r){
    if(!incoming[r.target]) incoming[r.target] = [];
    incoming[r.target].push(r);
    if(!outgoing[r.source]) outgoing[r.source] = [];
    outgoing[r.source].push(r);
  });

  // --- REQ rows for matrix ---
  var reqs = (DATA.artifacts || []).filter(function(a){return a.type === "REQ"});
  var traceTypes = ["UC","WF","API","BDD","INV","ADR","TASK"];

  function countRelated(reqId, targetType){
    var rels = incoming[reqId] || [];
    var ids = {};
    rels.forEach(function(r){
      var art = artById[r.source];
      if(art && art.type === targetType) ids[r.source] = 1;
    });
    var rels2 = outgoing[reqId] || [];
    rels2.forEach(function(r){
      var art = artById[r.target];
      if(art && art.type === targetType) ids[r.target] = 1;
    });
    return Object.keys(ids).length;
  }

  function reqStatus(reqId){
    var art = artById[reqId];
    var uc = countRelated(reqId, "UC");
    var bdd = countRelated(reqId, "BDD");
    var task = countRelated(reqId, "TASK");
    var codeCount = (art && art.codeRefs) ? art.codeRefs.length : 0;
    var testCount = (art && art.testRefs) ? art.testRefs.length : 0;
    if(uc > 0 && bdd > 0 && task > 0 && codeCount > 0 && testCount > 0) return "full";
    if(uc > 0 && (codeCount > 0 || testCount > 0)) return "partial";
    if(uc > 0) return "spec-only";
    return "none";
  }

  // --- Populate filter dropdowns ---
  var priorities = {};
  var types = {};
  var domains = {};
  var layers = {};
  var categories = {};
  (DATA.artifacts || []).forEach(function(a){
    if(a.priority) priorities[a.priority] = 1;
    types[a.type] = 1;
    if(a.classification){
      if(a.classification.businessDomain) domains[a.classification.businessDomain] = 1;
      if(a.classification.technicalLayer) layers[a.classification.technicalLayer] = 1;
      if(a.classification.functionalCategory) categories[a.classification.functionalCategory] = 1;
    }
  });
  populateSelect($("fPriority"), priorities);
  populateSelect($("fType"), types);
  populateSelect($("fDomain"), domains);
  populateSelect($("fLayer"), layers);
  populateSelect($("fCategory"), categories);
  (DATA.pipeline && DATA.pipeline.stages || []).forEach(function(s){
    var o = ce("option"); o.value = s.name; o.textContent = s.name.replace(/-/g," ");
    $("fStage").appendChild(o);
  });

  function populateSelect(sel, obj){
    Object.keys(obj).sort().forEach(function(k){
      var o = ce("option"); o.value = k; o.textContent = k;
      sel.appendChild(o);
    });
  }

  // --- Build rows ---
  var rows = [];
  reqs.forEach(function(req){
    var counts = {};
    traceTypes.forEach(function(t){ counts[t] = countRelated(req.id, t) });
    counts.CODE = (req.codeRefs || []).length;
    counts.TESTS = (req.testRefs || []).length;
    rows.push({art: req, counts: counts, status: reqStatus(req.id)});
  });

  if(reqs.length === 0){
    (DATA.artifacts || []).forEach(function(a){
      rows.push({art: a, counts: {}, status: "none"});
    });
  }

  var sortCol = "id";
  var sortDir = 1;

  // --- View switching ---
  document.querySelectorAll(".view-tab").forEach(function(tab){
    tab.addEventListener("click", function(){
      document.querySelectorAll(".view-tab").forEach(function(t){t.classList.remove("active")});
      document.querySelectorAll(".view").forEach(function(v){v.classList.remove("active")});
      tab.classList.add("active");
      $("view-" + tab.dataset.view).classList.add("active");
    });
  });

  // ==========================================
  // MATRIX VIEW
  // ==========================================
  function renderTable(filtered){
    var tb = $("tbody");
    tb.innerHTML = "";
    if(filtered.length === 0){
      $("empty").style.display = "block";
      $("fCount").textContent = "0 results";
      return;
    }
    $("empty").style.display = "none";
    $("fCount").textContent = filtered.length + " result" + (filtered.length !== 1 ? "s":"");

    filtered.forEach(function(row){
      var tr = ce("tr");
      tr.className = "row-" + row.status;

      // ID
      var tdId = ce("td");
      var idSpan = ce("span");
      idSpan.className = "cell-id";
      idSpan.setAttribute("role", "button");
      idSpan.setAttribute("tabindex", "0");
      idSpan.textContent = row.art.id;
      idSpan.addEventListener("click", function(){ openDetail(row.art.id) });
      idSpan.addEventListener("keydown", function(e){ if(e.key==="Enter"||e.key===" "){e.preventDefault();openDetail(row.art.id)} });
      tdId.appendChild(idSpan);
      tr.appendChild(tdId);

      // Title
      var tdTitle = ce("td");
      tdTitle.className = "cell-title";
      tdTitle.textContent = row.art.title || "";
      tdTitle.title = row.art.title || "";
      tr.appendChild(tdTitle);

      // Priority
      var tdPri = ce("td");
      if(row.art.priority){
        var priSpan = ce("span");
        priSpan.className = "cell-priority " + priClass(row.art.priority);
        priSpan.textContent = row.art.priority;
        tdPri.appendChild(priSpan);
      }
      tr.appendChild(tdPri);

      // Domain
      var tdDom = ce("td");
      var cl = row.art.classification;
      if(cl && cl.businessDomain){
        var domSpan = ce("span");
        domSpan.className = "cell-domain";
        domSpan.textContent = cl.businessDomain;
        tdDom.appendChild(domSpan);
      }
      tr.appendChild(tdDom);

      // Layer
      var tdLay = ce("td");
      if(cl && cl.technicalLayer){
        var laySpan = ce("span");
        laySpan.className = "cell-layer " + cl.technicalLayer.toLowerCase().replace(/[^a-z]/g,"");
        laySpan.textContent = cl.technicalLayer;
        tdLay.appendChild(laySpan);
      }
      tr.appendChild(tdLay);

      // Trace counts
      traceTypes.forEach(function(t){
        var td = ce("td");
        var c = row.counts[t] || 0;
        var badge = ce("span");
        badge.className = "cell-count " + (c > 0 ? "has" : "zero");
        badge.textContent = c > 0 ? c : "\u2014";
        if(c === 0) badge.title = "No " + humanLabel(t) + " linked to this requirement yet";
        td.appendChild(badge);
        tr.appendChild(td);
      });

      // Code count
      var tdCode = ce("td");
      var cc = row.counts.CODE || 0;
      var codeBadge = ce("span");
      codeBadge.className = "cell-count " + (cc > 0 ? "has" : "zero");
      codeBadge.textContent = cc > 0 ? cc : "\u2014";
      tdCode.appendChild(codeBadge);
      tr.appendChild(tdCode);

      // Tests count
      var tdTests = ce("td");
      var tc2 = row.counts.TESTS || 0;
      var testBadge = ce("span");
      testBadge.className = "cell-count " + (tc2 > 0 ? "has" : "zero");
      testBadge.textContent = tc2 > 0 ? tc2 : "\u2014";
      tdTests.appendChild(testBadge);
      tr.appendChild(tdTests);

      // Status
      var tdSt = ce("td");
      var stBadge = ce("span");
      stBadge.className = "status-badge " + row.status;
      var statusLabels = {"full":"Complete","partial":"In Progress","spec-only":"Specified","none":"Not Started"};
      stBadge.textContent = statusLabels[row.status] || row.status;
      tdSt.appendChild(stBadge);
      tr.appendChild(tdSt);

      tb.appendChild(tr);
    });
  }

  function priClass(p){
    if(!p) return "";
    var l = p.toLowerCase();
    if(l.indexOf("must") >= 0 || l === "critical" || l === "m") return "must";
    if(l.indexOf("should") >= 0 || l === "high" || l === "s") return "should";
    if(l.indexOf("could") >= 0 || l === "medium" || l === "c") return "could";
    return "wont";
  }

  // ==========================================
  // CLASSIFICATION VIEW
  // ==========================================
  function renderClassification(filtered){
    var grid = $("classGrid");
    grid.innerHTML = "";

    var byDomain = {};
    filtered.filter(function(row){return row.art.type === "REQ"}).forEach(function(row){
      var cl = row.art.classification;
      var domain = (cl && cl.businessDomain) ? cl.businessDomain : "Other";
      if(!byDomain[domain]) byDomain[domain] = [];
      byDomain[domain].push(row);
    });

    var domainKeys = Object.keys(byDomain).sort();
    if(domainKeys.length === 0){
      grid.innerHTML = '<div class="empty-section">No classified artifacts found</div>';
      return;
    }

    domainKeys.forEach(function(domain){
      var items = byDomain[domain];
      var card = ce("div");
      card.className = "class-card";

      // Header
      var header = ce("div");
      header.className = "class-card-header";
      header.innerHTML = '<h3>' + esc(domain) + '</h3><span class="class-count">' + items.length + '</span>';
      card.appendChild(header);

      // Progress bar
      var fullCount = items.filter(function(r){return r.status === "full"}).length;
      var pct = items.length > 0 ? (fullCount / items.length * 100) : 0;
      var bar = ce("div");
      bar.className = "class-bar";
      var fill = ce("div");
      fill.className = "class-bar-fill";
      fill.style.width = pct + "%";
      fill.style.background = pct >= 80 ? "var(--green)" : pct >= 50 ? "var(--yellow)" : "var(--red)";
      bar.appendChild(fill);
      card.appendChild(bar);

      // Items
      var body = ce("div");
      body.className = "class-card-body";
      items.forEach(function(row){
        var item = ce("div");
        item.className = "class-item";
        var statusAriaLabels = {"full":"Complete","partial":"In Progress","spec-only":"Specified","none":"Not Started"};
        item.innerHTML = '<span class="item-status ' + row.status + '" aria-label="' + (statusAriaLabels[row.status] || row.status) + '"></span>'
          + '<span class="item-id">' + esc(row.art.id) + '</span>'
          + '<span class="item-title">' + esc(row.art.title || "") + '</span>';
        item.setAttribute("role", "button");
        item.setAttribute("tabindex", "0");
        item.addEventListener("click", function(){ openDetail(row.art.id) });
        item.addEventListener("keydown", function(e){ if(e.key==="Enter"||e.key===" "){e.preventDefault();openDetail(row.art.id)} });
        body.appendChild(item);
      });
      card.appendChild(body);

      grid.appendChild(card);
    });
  }

  // ==========================================
  // CODE COVERAGE VIEW
  // ==========================================
  function renderCodeCoverage(){
    var sumEl = $("covSummary");
    var listEl = $("covList");
    sumEl.innerHTML = "";
    listEl.innerHTML = "";

    var cs = st.codeStats || {};
    var ts = st.testStats || {};

    // Summary cards
    addCovStat(sumEl, "Source Files", cs.totalFiles || 0, "Scanned in src/");
    addCovStat(sumEl, "Symbols with Refs", cs.symbolsWithRefs || 0, "of " + (cs.totalSymbols || 0) + " total");
    addCovStat(sumEl, "Test Files", ts.totalTestFiles || 0, "Scanned in tests/");
    addCovStat(sumEl, "Tests with Refs", ts.testsWithRefs || 0, "of " + (ts.totalTests || 0) + " total");
    var cms = st.commitStats || {};
    if (cms.totalCommits > 0) {
      addCovStat(sumEl, "Commits", cms.totalCommits, cms.commitsWithRefs + " with refs");
      addCovStat(sumEl, "Tasks Covered", cms.uniqueTasksCovered || 0, "by commits");
    }

    // Build file → codeRefs map
    var fileMap = {};
    (DATA.artifacts || []).forEach(function(a){
      (a.codeRefs || []).forEach(function(cr){
        if(!fileMap[cr.file]) fileMap[cr.file] = {refs: [], totalSymbols: 0};
        fileMap[cr.file].refs.push(cr);
      });
    });

    var files = Object.keys(fileMap).sort();
    if(files.length === 0){
      listEl.innerHTML = '<div class="empty-section">No code references found. Add <code>Refs: UC-001</code> comments to your source code.</div>';
      return;
    }

    files.forEach(function(filepath){
      var info = fileMap[filepath];
      var refCount = info.refs.length;
      var pct = refCount > 0 ? 100 : 0;

      var div = ce("div");
      div.className = "cov-file";

      var header = ce("div");
      header.className = "cov-file-header";
      var pctClass = pct >= 80 ? "high" : pct >= 40 ? "mid" : pct > 0 ? "low" : "zero";
      header.innerHTML = '<span class="cov-file-path">' + esc(filepath) + '</span>'
        + '<span class="cov-file-pct ' + pctClass + '">' + refCount + ' ref' + (refCount !== 1 ? 's' : '') + '</span>'
        + '<div class="cov-bar"><div class="cov-bar-fill" style="width:' + Math.min(pct, 100) + '%;background:var(--' + (pctClass === "high" ? "green" : pctClass === "mid" ? "yellow" : pctClass === "low" ? "red" : "gray") + ')"></div></div>';
      header.addEventListener("click", function(){
        div.classList.toggle("open");
      });
      div.appendChild(header);

      var symbols = ce("div");
      symbols.className = "cov-file-symbols";
      info.refs.forEach(function(cr){
        var sym = ce("div");
        sym.className = "cov-symbol";
        sym.innerHTML = '<span class="cov-symbol-name">' + esc(cr.symbol || "unknown") + '</span>'
          + '<span class="cov-symbol-type">' + esc(cr.symbolType || "unknown") + '</span>'
          + '<span class="cov-symbol-refs">' + esc((cr.refIds || []).join(", ")) + '</span>';
        symbols.appendChild(sym);
      });
      div.appendChild(symbols);

      listEl.appendChild(div);
    });
  }

  function addCovStat(el, label, value, sub){
    var d = ce("div"); d.className = "stat-card";
    d.innerHTML = '<div class="stat-label">' + esc(label) + '</div>'
      + '<div class="stat-value">' + esc(String(value)) + '</div>'
      + '<div class="stat-sub">' + esc(sub) + '</div>';
    el.appendChild(d);
  }

  // ==========================================
  // FILTERING
  // ==========================================
  var debounceTimer;
  function applyFilters(){
    clearTimeout(debounceTimer);
    debounceTimer = setTimeout(doFilter, 150);
  }

  function doFilter(){
    var search = $("fSearch").value.toLowerCase();
    var fSt = $("fStatus").value;
    var fPri = $("fPriority").value;
    var fType = $("fType").value;
    var fStg = $("fStage").value || stageFilter;
    var fDom = $("fDomain").value;
    var fLay = $("fLayer").value;
    var fCat = $("fCategory").value;

    var filtered = rows.filter(function(r){
      if(search && r.art.id.toLowerCase().indexOf(search) < 0 && (r.art.title || "").toLowerCase().indexOf(search) < 0) return false;
      if(fSt && r.status !== fSt) return false;
      if(fPri && r.art.priority !== fPri) return false;
      if(fType && r.art.type !== fType) return false;
      if(fStg && r.art.stage !== fStg) return false;
      var cl = r.art.classification;
      if(fDom && (!cl || cl.businessDomain !== fDom)) return false;
      if(fLay && (!cl || cl.technicalLayer !== fLay)) return false;
      if(fCat && (!cl || cl.functionalCategory !== fCat)) return false;
      return true;
    });

    sortRows(filtered);
    renderTable(filtered);
    renderClassification(filtered);
  }

  function sortRows(arr){
    arr.sort(function(a,b){
      var va, vb;
      if(sortCol === "id"){ va = a.art.id; vb = b.art.id; }
      else if(sortCol === "title"){ va = a.art.title || ""; vb = b.art.title || ""; }
      else if(sortCol === "priority"){ va = a.art.priority || "zzz"; vb = b.art.priority || "zzz"; }
      else if(sortCol === "status"){ va = a.status; vb = b.status; }
      else if(sortCol === "domain"){ va = (a.art.classification||{}).businessDomain||"zzz"; vb = (b.art.classification||{}).businessDomain||"zzz"; }
      else if(sortCol === "layer"){ va = (a.art.classification||{}).technicalLayer||"zzz"; vb = (b.art.classification||{}).technicalLayer||"zzz"; }
      else if(sortCol === "code"){ va = a.counts.CODE || 0; vb = b.counts.CODE || 0; return (va - vb) * sortDir; }
      else if(sortCol === "tests"){ va = a.counts.TESTS || 0; vb = b.counts.TESTS || 0; return (va - vb) * sortDir; }
      else{
        var t = sortCol.toUpperCase();
        va = a.counts[t] || 0; vb = b.counts[t] || 0;
        return (va - vb) * sortDir;
      }
      if(va < vb) return -1 * sortDir;
      if(va > vb) return 1 * sortDir;
      return 0;
    });
  }

  // Event listeners
  $("fSearch").addEventListener("input", applyFilters);
  $("fStatus").addEventListener("change", applyFilters);
  $("fPriority").addEventListener("change", applyFilters);
  $("fType").addEventListener("change", applyFilters);
  $("fStage").addEventListener("change", function(){stageFilter="";applyFilters()});
  $("fDomain").addEventListener("change", applyFilters);
  $("fLayer").addEventListener("change", applyFilters);
  $("fCategory").addEventListener("change", applyFilters);

  // Sort headers
  document.querySelectorAll("th[data-col]").forEach(function(th){
    th.addEventListener("click", function(){
      var col = th.dataset.col;
      if(sortCol === col) sortDir *= -1;
      else{sortCol = col; sortDir = 1;}
      document.querySelectorAll("th").forEach(function(h){h.classList.remove("sorted")});
      th.classList.add("sorted");
      th.querySelector(".sort-icon").textContent = sortDir === 1 ? "\u25B2" : "\u25BC";
      applyFilters();
    });
  });

  // --- Dynamic sticky offsets ---
  function updateStickyOffsets(){
    var hdr = document.querySelector(".header");
    var fb = $("filterBar");
    var thead = document.querySelector("thead");
    if(hdr && fb){
      fb.style.top = hdr.offsetHeight + "px";
      if(thead) thead.style.top = (hdr.offsetHeight + fb.offsetHeight) + "px";
    }
  }
  updateStickyOffsets();
  window.addEventListener("resize", updateStickyOffsets);

  // ==========================================
  // DETAIL PANEL (5 tabs)
  // ==========================================
  function openDetail(id){
    var art = artById[id];
    if(!art) return;
    $("dId").textContent = art.id;
    $("dTitle").textContent = art.title || "";
    $("dFile").textContent = art.file ? (art.file + (art.line ? ":" + art.line : "")) : "";

    // Badges
    var badgesEl = $("dBadges");
    badgesEl.innerHTML = "";
    if(art.priority){
      var pb = ce("span");
      pb.className = "detail-badge cell-priority " + priClass(art.priority);
      pb.textContent = art.priority;
      badgesEl.appendChild(pb);
    }
    if(art.classification){
      if(art.classification.businessDomain){
        var db = ce("span");
        db.className = "detail-badge cell-domain";
        db.textContent = art.classification.businessDomain;
        badgesEl.appendChild(db);
      }
      if(art.classification.technicalLayer){
        var lb = ce("span");
        lb.className = "detail-badge cell-layer " + art.classification.technicalLayer.toLowerCase().replace(/[^a-z]/g,"");
        lb.textContent = art.classification.technicalLayer;
        badgesEl.appendChild(lb);
      }
      if(art.classification.functionalCategory){
        var cb = ce("span");
        cb.className = "detail-badge";
        cb.style.background = "var(--surface2)";
        cb.style.color = "var(--text2)";
        cb.textContent = art.classification.functionalCategory;
        badgesEl.appendChild(cb);
      }
    }

    // --- Tab 1: Story ---
    renderStory(art);

    // --- Tab 2: Trace Chain ---
    var inc = incoming[id] || [];
    var out = outgoing[id] || [];
    renderChain($("dIncoming"), inc, "source");
    renderChain($("dOutgoing"), out, "target");

    // --- Tab 3: Code ---
    renderCodeTab(art);

    // --- Tab 4: Tests ---
    renderTestsTab(art);

    // --- Tab 5: Documents ---
    renderDocsTab(id);

    // Reset to Story tab
    document.querySelectorAll(".detail-tab").forEach(function(t){t.classList.remove("active")});
    document.querySelectorAll(".detail-tab-content").forEach(function(t){t.classList.remove("active")});
    document.querySelector('.detail-tab[data-dtab="story"]').classList.add("active");
    $("dtab-story").classList.add("active");

    $("detailOverlay").classList.add("open");
    $("detailPanel").classList.add("open");
  }

  // Story generation
  function renderStory(art){
    var el = $("dtab-story");
    el.innerHTML = "";
    var div = ce("div");
    div.className = "story-text";

    var codeCount = (art.codeRefs || []).length;
    var testCount = (art.testRefs || []).length;
    var status = art.type === "REQ" ? reqStatus(art.id) : "none";

    var codeDirs = {};
    (art.codeRefs || []).forEach(function(cr){
      var dir = cr.file.split("/").slice(0,-1).join("/");
      codeDirs[dir] = (codeDirs[dir] || 0) + 1;
    });
    var testDirs = {};
    (art.testRefs || []).forEach(function(tr2){
      var dir = tr2.file.split("/").slice(0,-1).join("/");
      testDirs[dir] = (testDirs[dir] || 0) + 1;
    });

    var relUCs = getRelatedIds(art.id, "UC");
    var relBDDs = getRelatedIds(art.id, "BDD");
    var relTasks = getRelatedIds(art.id, "TASK");

    var html = '<p><strong>' + esc(art.id) + '</strong>';
    if(art.title) html += ' (' + esc(art.title) + ')';
    html += '</p>';

    // Implementation status
    if(art.type === "REQ"){
      html += '<p style="margin-top:12px">';
      if(codeCount > 0){
        var dirList = Object.keys(codeDirs);
        html += 'Implemented by <strong>' + codeCount + ' function' + (codeCount !== 1 ? 's' : '') + '</strong>';
        if(dirList.length > 0) html += ' in <span class="story-highlight">' + esc(dirList.slice(0,2).join(", ")) + '</span>';
        html += '. ';
      } else {
        html += 'No code references found yet. ';
      }

      if(testCount > 0){
        html += 'Verified by <strong>' + testCount + ' test' + (testCount !== 1 ? 's' : '') + '</strong>';
        var testDirList = Object.keys(testDirs);
        if(testDirList.length > 0) html += ' in <span class="story-highlight">' + esc(testDirList.slice(0,2).join(", ")) + '</span>';
        html += '. ';
      } else {
        html += 'No test references found yet. ';
      }
      html += '</p>';

      // Traceability
      html += '<p style="margin-top:12px">';
      if(relUCs.length > 0) html += 'Covers use cases <strong>' + esc(relUCs.join(", ")) + '</strong>. ';
      else html += 'No use cases linked. ';
      if(relBDDs.length > 0) html += 'Has <strong>' + relBDDs.length + '</strong> BDD scenario' + (relBDDs.length !== 1 ? 's' : '') + '. ';
      if(relTasks.length > 0) html += 'Decomposed into <strong>' + relTasks.length + '</strong> task' + (relTasks.length !== 1 ? 's' : '') + '. ';
      html += '</p>';

      // Priority and classification
      html += '<p style="margin-top:12px">';
      if(art.priority) html += 'Priority: <strong>' + esc(art.priority) + '</strong>. ';
      var statusLabels2 = {"full":"Complete","partial":"In Progress","spec-only":"Specified","none":"Not Started"};
      html += 'Status: <strong>' + (statusLabels2[status] || status) + '</strong>.';
      html += '</p>';
    } else {
      // Non-REQ artifact story
      html += '<p style="margin-top:12px">This is a <strong>' + esc(art.type) + '</strong> artifact';
      if(art.stage) html += ' from the <strong>' + esc(art.stage.replace(/-/g," ")) + '</strong> stage';
      html += '.</p>';
      var relCount = (incoming[art.id] || []).length + (outgoing[art.id] || []).length;
      html += '<p style="margin-top:8px">Has <strong>' + relCount + '</strong> relationship' + (relCount !== 1 ? 's' : '') + ' with other artifacts.</p>';
    }

    div.innerHTML = html;
    el.appendChild(div);
  }

  function getRelatedIds(id, targetType){
    var ids = {};
    (incoming[id] || []).forEach(function(r){
      var art = artById[r.source];
      if(art && art.type === targetType) ids[r.source] = 1;
    });
    (outgoing[id] || []).forEach(function(r){
      var art = artById[r.target];
      if(art && art.type === targetType) ids[r.target] = 1;
    });
    return Object.keys(ids).sort();
  }

  // Trace Chain
  function renderChain(ul, rels, field){
    ul.innerHTML = "";
    if(rels.length === 0){
      var li = ce("li");
      li.textContent = "None";
      li.style.color = "var(--text2)";
      ul.appendChild(li);
      return;
    }
    rels.forEach(function(r){
      var li = ce("li");
      var idSpan = ce("span");
      idSpan.className = "chain-id";
      idSpan.textContent = r[field];
      idSpan.addEventListener("click", function(){ openDetail(r[field]) });
      li.appendChild(idSpan);

      var typeSpan = ce("span");
      typeSpan.className = "chain-type";
      typeSpan.textContent = r.type;
      li.appendChild(typeSpan);

      var fileSpan = ce("span");
      fileSpan.className = "chain-file";
      fileSpan.textContent = r.sourceFile ? (r.sourceFile + (r.line ? ":" + r.line : "")) : "";
      li.appendChild(fileSpan);

      ul.appendChild(li);
    });
  }

  // Code tab
  function renderCodeTab(art){
    var el = $("dtab-code");
    el.innerHTML = "";
    var refs = art.codeRefs || [];
    if(refs.length === 0){
      el.innerHTML = '<div class="empty-section">No code references found.<br>Add <code>Refs: ' + esc(art.id) + '</code> comments to your source code.</div>';
      return;
    }
    refs.forEach(function(cr){
      var div = ce("div");
      div.className = "code-ref";
      div.innerHTML = '<div class="code-ref-file">' + esc(cr.file) + ':' + (cr.line || '') + '</div>'
        + '<div class="code-ref-symbol">' + esc(cr.symbol || "unknown") + '<span class="code-ref-type">' + esc(cr.symbolType || "unknown") + '</span></div>'
        + '<div class="code-ref-ids">Refs: ' + esc((cr.refIds || []).join(", ")) + '</div>';
      el.appendChild(div);
    });
  }

  // Tests tab
  function renderTestsTab(art){
    var el = $("dtab-tests");
    el.innerHTML = "";
    var refs = art.testRefs || [];
    if(refs.length === 0){
      el.innerHTML = '<div class="empty-section">No test references found.<br>Add <code>Refs: ' + esc(art.id) + '</code> to your test files or test descriptions.</div>';
      return;
    }
    refs.forEach(function(tr2){
      var div = ce("div");
      div.className = "test-ref";
      div.innerHTML = '<div class="test-ref-file">' + esc(tr2.file) + ':' + (tr2.line || '') + '</div>'
        + '<div class="test-ref-name">' + esc(tr2.testName || "unnamed test") + '<span class="test-ref-framework">' + esc(tr2.framework || "unknown") + '</span></div>'
        + '<div class="test-ref-ids">Refs: ' + esc((tr2.refIds || []).join(", ")) + '</div>';
      el.appendChild(div);
    });
  }

  // Documents tab
  function renderDocsTab(id){
    var el = $("dtab-docs");
    el.innerHTML = "";
    var groups = {};
    var inc2 = incoming[id] || [];
    var out2 = outgoing[id] || [];

    function addToGroup(artId){
      var a = artById[artId];
      if(!a) return;
      var type = a.type;
      if(!groups[type]) groups[type] = [];
      if(!groups[type].some(function(x){return x.id === a.id})){
        groups[type].push(a);
      }
    }

    inc2.forEach(function(r){ addToGroup(r.source) });
    out2.forEach(function(r){ addToGroup(r.target) });

    var groupKeys = Object.keys(groups).sort();
    if(groupKeys.length === 0){
      el.innerHTML = '<div class="empty-section">No related documents found.</div>';
      return;
    }

    groupKeys.forEach(function(type){
      var grp = ce("div");
      grp.className = "doc-group";
      var h4 = ce("h4");
      h4.textContent = humanLabel(type) + " (" + groups[type].length + ")";
      grp.appendChild(h4);

      groups[type].sort(function(a,b){return a.id < b.id ? -1 : 1}).forEach(function(a){
        var item = ce("div");
        item.className = "doc-item";
        var idSpan = ce("span");
        idSpan.className = "doc-item-id";
        idSpan.textContent = a.id;
        idSpan.addEventListener("click", function(){ openDetail(a.id) });
        item.appendChild(idSpan);

        var titleSpan = ce("span");
        titleSpan.className = "doc-item-title";
        titleSpan.textContent = a.title || "";
        item.appendChild(titleSpan);

        grp.appendChild(item);
      });
      el.appendChild(grp);
    });
  }

  // Detail tab switching
  document.querySelectorAll(".detail-tab").forEach(function(tab){
    tab.addEventListener("click", function(){
      document.querySelectorAll(".detail-tab").forEach(function(t){t.classList.remove("active")});
      document.querySelectorAll(".detail-tab-content").forEach(function(t){t.classList.remove("active")});
      tab.classList.add("active");
      $("dtab-" + tab.dataset.dtab).classList.add("active");
    });
  });

  $("detailClose").addEventListener("click", closeDetail);
  $("detailOverlay").addEventListener("click", closeDetail);
  function closeDetail(){
    $("detailOverlay").classList.remove("open");
    $("detailPanel").classList.remove("open");
  }
  document.addEventListener("keydown", function(e){
    if(e.key === "Escape") closeDetail();
  });

  // ==========================================
  // EXECUTIVE SUMMARY VIEW
  // ==========================================
  function renderSummary() {
    var el = $("view-summary");
    var html = '';

    // --- Next Action Card ---
    var nextAct = getNextAction();
    if (nextAct.stage) {
      html += '<div class="next-action-card">';
      html += '<h3><span class="live-dot off" id="nextActionLive"></span> Next Action</h3>';
      html += '<div class="next-reason">' + esc(nextAct.reason) + '</div>';
      html += '<div class="prompt-block" id="nextActionPrompt">' + esc(nextAct.prompt) + '</div>';
      html += '</div>';
    }

    // --- Activity Feed ---
    html += '<div class="activity-panel" id="activityPanel">';
    html += '<h3><span class="live-dot off" id="activityLive"></span> Pipeline Activity</h3>';
    html += '<div class="activity-feed" id="activityFeed"><div class="activity-empty">No live activity. Run a pipeline skill to see progress here.</div></div>';
    html += '</div>';

    html += '<div class="summary-grid">';

    // Card 1: Coverage Progress
    html += '<div class="summary-card"><h3>Traceability Coverage</h3>';
    var metrics = [
      { label: "Requirements \u2192 Use Cases", val: cov.reqsWithUCs, target: TARGETS.ucs },
      { label: "Requirements \u2192 Code", val: cov.reqsWithCode, target: TARGETS.code },
      { label: "Requirements \u2192 Tests", val: cov.reqsWithTests, target: TARGETS.tests },
      { label: "Requirements \u2192 Acceptance Tests", val: cov.reqsWithBDD, target: TARGETS.bdd },
      { label: "Requirements \u2192 Tasks", val: cov.reqsWithTasks, target: TARGETS.tasks },
      { label: "Requirements \u2192 Commits", val: cov.reqsWithCommits, target: 50 }
    ];
    metrics.forEach(function(m) {
      var pct = m.val ? m.val.percentage : 0;
      var color = pct >= m.target ? "var(--green)" : pct >= m.target*0.6 ? "var(--yellow)" : "var(--red)";
      html += '<div class="summary-progress">';
      html += '<div class="summary-progress-header"><span>' + esc(m.label) + '</span><span>' + pct.toFixed(1) + '%</span></div>';
      html += '<div class="summary-progress-bar"><div class="summary-progress-fill" style="width:' + pct + '%;background:' + color + '"></div></div>';
      html += '</div>';
    });
    html += '</div>';

    // Card 2: Top Gaps (REQs that need attention)
    html += '<div class="summary-card"><h3>Top Gaps (Needs Attention)</h3>';
    var gaps = rows.filter(function(r) { return r.status === "none" || r.status === "spec-only" })
      .sort(function(a,b) {
        var pa = a.art.priority || "zzz";
        var pb = b.art.priority || "zzz";
        if (pa.indexOf("Must") >= 0 && pb.indexOf("Must") < 0) return -1;
        if (pb.indexOf("Must") >= 0 && pa.indexOf("Must") < 0) return 1;
        return a.art.id < b.art.id ? -1 : 1;
      }).slice(0, 8);
    if (gaps.length > 0) {
      html += '<ul class="summary-top-gaps">';
      gaps.forEach(function(g) {
        var missing = [];
        if (g.counts.UC === 0) missing.push("Use Cases");
        if (g.counts.CODE === 0) missing.push("Code");
        if (g.counts.TESTS === 0) missing.push("Tests");
        html += '<li><span class="summary-gap-id">' + esc(g.art.id) + '</span>';
        if (missing.length > 0) {
          html += '<span class="summary-gap-missing">Missing: ' + missing.join(", ") + '</span>';
        }
        html += '</li>';
      });
      html += '</ul>';
    } else {
      html += '<div class="hero-ok">All requirements have traceability coverage.</div>';
    }
    html += '</div>';

    // Card 3: Artifact Breakdown
    html += '<div class="summary-card"><h3>Artifact Breakdown</h3>';
    html += '<div class="summary-breakdown">';
    var bt = st.byType || {};
    var typeOrder = ["REQ","UC","WF","API","BDD","INV","ADR","TASK"];
    typeOrder.forEach(function(t) {
      if (bt[t]) {
        html += '<div class="summary-breakdown-item">';
        html += '<div class="summary-breakdown-value">' + esc(String(bt[t])) + '</div>';
        html += '<div class="summary-breakdown-label">' + humanLabel(t) + '</div>';
        html += '</div>';
      }
    });
    html += '</div></div>';

    // Card 4: Pipeline Status
    html += '<div class="summary-card"><h3>Pipeline Status</h3>';
    (DATA.pipeline && DATA.pipeline.stages || []).forEach(function(s) {
      var stColor = s.status === "done" ? "var(--green)" : s.status === "running" ? "var(--yellow)" : s.status === "error" ? "var(--red)" : "var(--gray)";
      html += '<div style="display:flex;align-items:center;gap:8px;padding:4px 0;font-size:13px">';
      html += '<span style="width:8px;height:8px;border-radius:50%;background:' + stColor + ';flex-shrink:0" aria-label="Status: ' + esc(s.status || 'unknown') + '"></span>';
      html += '<span style="flex:1">' + esc(s.name.replace(/-/g, " ")) + '</span>';
      html += '<span style="font-size:11px;color:var(--text2)">' + (s.artifactCount || 0) + ' artifacts</span>';
      html += '</div>';
    });
    html += '</div>';

    html += '</div>';
    el.innerHTML = html;

    // Click handlers for gap IDs
    el.querySelectorAll(".summary-gap-id").forEach(function(span) {
      span.addEventListener("click", function() { openDetail(span.textContent) });
    });

    // Wire copy button on Next Action card
    var nap = $("nextActionPrompt");
    if (nap) {
      nap.appendChild(makeCopyBtn(nextAct.prompt, "Copy Prompt"));
    }
  }

  // ==========================================
  // ADOPTION VIEW
  // ==========================================
  function renderAdoptionView() {
    var el = $("view-adoption");
    var adoption = DATA.adoption || { present: false };
    var adoptStats = (DATA.statistics || {}).adoptionStats || {};

    if (!adoption.present) {
      el.innerHTML = '<div class="adopt-empty">'
        + '<h3>No Adoption Data</h3>'
        + '<p>Run onboarding skills to populate this view with project adoption status.</p>'
        + '<div class="adopt-empty-cmd">/sdd-onboarding</div>'
        + '</div>';
      return;
    }

    var html = '<div class="adopt-grid">';

    // Journey Card (action plan stepper)
    var ob = adoption.onboarding;
    if (ob && ob.present && ob.actionPlan && ob.actionPlan.length > 0) {
      html += '<div class="adopt-card"><h3>Adoption Journey</h3>';
      html += '<div class="adopt-journey-steps">';
      ob.actionPlan.forEach(function(step) {
        var done = isStepDone(step.skill, adoption);
        html += '<div class="adopt-step' + (done ? ' done' : '') + '">';
        html += '<div class="adopt-step-num">' + step.step + '</div>';
        html += '<div class="adopt-step-skill">/sdd-' + esc(step.skill) + '</div>';
        html += '<div class="adopt-step-desc">' + esc(step.description) + '</div>';
        html += '<span class="adopt-step-effort ' + esc(step.effort || 'medium') + '">' + esc(step.effort || 'medium') + '</span>';
        html += '</div>';
      });
      html += '</div></div>';
    }

    // Row 2: Scenario + Health Dimensions
    html += '<div class="adopt-row-2">';

    // Scenario card
    if (ob && ob.present) {
      html += '<div class="adopt-card"><h3>Project Scenario</h3>';
      html += '<div class="adopt-scenario-name">' + esc(ob.scenarioName || ob.scenario || 'Unknown') + '</div>';
      if (ob.confidence != null) {
        html += '<div class="adopt-confidence">Confidence: ' + (ob.confidence * 100).toFixed(0) + '%</div>';
      }
      if (ob.signals && ob.signals.length > 0) {
        ob.signals.forEach(function(sig) {
          html += '<span class="adopt-signal">' + esc(sig) + '</span>';
        });
      }
      html += '</div>';
    } else {
      html += '<div class="adopt-card"><h3>Project Scenario</h3><div class="empty-section">Run /sdd-onboarding</div></div>';
    }

    // Health Dimensions card
    if (ob && ob.present && ob.dimensions) {
      html += '<div class="adopt-card"><h3>Health Dimensions</h3>';
      var dims = ob.dimensions;
      var dimKeys = ["requirements","specs","tests","architecture","traceability","codeQuality","pipelineState"];
      var dimLabels = {requirements:"Requirements",specs:"Specifications",tests:"Tests",architecture:"Architecture",traceability:"Traceability",codeQuality:"Code Quality",pipelineState:"Pipeline State"};
      dimKeys.forEach(function(k) {
        var val = dims[k] || 0;
        var color = val >= 70 ? "var(--green)" : val >= 40 ? "var(--yellow)" : "var(--red)";
        html += '<div class="adopt-dim">';
        html += '<span class="adopt-dim-label">' + (dimLabels[k] || k) + '</span>';
        html += '<div class="adopt-dim-bar"><div class="adopt-dim-fill" style="width:' + val + '%;background:' + color + '"></div></div>';
        html += '<span class="adopt-dim-val">' + val + '</span>';
        html += '</div>';
      });
      html += '</div>';
    } else {
      html += '<div class="adopt-card"><h3>Health Dimensions</h3><div class="empty-section">Run /sdd-onboarding</div></div>';
    }
    html += '</div>'; // end row-2

    // Row 2b: Findings + Reconciliation
    html += '<div class="adopt-row-2b">';

    // Findings card
    var re = adoption.reverseEngineering;
    if (re && re.present && re.findings) {
      var f = re.findings;
      html += '<div class="adopt-card"><h3>Code Findings (' + (f.total || 0) + ')</h3>';
      // Severity bar
      var sev = f.bySeverity || {};
      var sevTotal = (sev.critical || 0) + (sev.high || 0) + (sev.medium || 0) + (sev.low || 0);
      if (sevTotal > 0) {
        html += '<div class="adopt-severity-bar">';
        if (sev.critical) html += '<div class="adopt-severity-seg" style="width:' + (sev.critical/sevTotal*100) + '%;background:var(--red)">' + sev.critical + '</div>';
        if (sev.high) html += '<div class="adopt-severity-seg" style="width:' + (sev.high/sevTotal*100) + '%;background:var(--orange)">' + sev.high + '</div>';
        if (sev.medium) html += '<div class="adopt-severity-seg" style="width:' + (sev.medium/sevTotal*100) + '%;background:var(--yellow)">' + sev.medium + '</div>';
        if (sev.low) html += '<div class="adopt-severity-seg" style="width:' + (sev.low/sevTotal*100) + '%;background:var(--green)">' + sev.low + '</div>';
        html += '</div>';
      }
      // Category list
      var cats = f.byCategory || {};
      Object.keys(cats).forEach(function(cat) {
        html += '<div class="adopt-cat-row"><span class="adopt-cat-label">[' + esc(cat) + ']</span><span class="adopt-cat-count">' + cats[cat] + '</span></div>';
      });
      // Top findings
      if (f.topFindings && f.topFindings.length > 0) {
        html += '<div style="margin-top:12px;padding-top:8px;border-top:1px solid var(--border)">';
        f.topFindings.forEach(function(tf) {
          html += '<div class="adopt-finding-row">';
          html += '<span class="adopt-finding-id">' + esc(tf.id) + '</span>';
          html += '<span class="adopt-finding-sev ' + esc(tf.severity) + '">' + esc(tf.severity) + '</span>';
          html += esc(tf.description);
          html += '</div>';
        });
        html += '</div>';
      }
      html += '</div>';
    } else {
      html += '<div class="adopt-card"><h3>Code Findings</h3><div class="empty-section">Run /sdd-reverse-engineer</div></div>';
    }

    // Reconciliation card
    var rec = adoption.reconciliation;
    if (rec && rec.present) {
      html += '<div class="adopt-card"><h3>Spec-Code Alignment</h3>';
      var alignColor = (rec.alignmentPercentage || 0) >= 80 ? "var(--green)" : (rec.alignmentPercentage || 0) >= 60 ? "var(--yellow)" : "var(--red)";
      html += '<div class="adopt-align-pct" style="color:' + alignColor + '">' + (rec.alignmentPercentage || 0).toFixed(1) + '%</div>';
      html += '<div style="font-size:12px;color:var(--text2);margin-bottom:8px">alignment</div>';
      if (rec.divergences) {
        var dv = rec.divergences;
        html += '<div style="font-size:13px;margin-bottom:8px">' + (dv.total || 0) + ' divergences (' + (dv.resolved || 0) + ' resolved, ' + (dv.pending || 0) + ' pending)</div>';
        if (dv.byType) {
          html += '<table class="adopt-div-table">';
          Object.keys(dv.byType).forEach(function(t) {
            html += '<tr><td>' + esc(t) + '</td><td>' + dv.byType[t] + '</td></tr>';
          });
          html += '</table>';
        }
      }
      if (rec.delta) {
        html += '<div style="margin-top:8px;font-size:11px;color:var(--text3)">';
        html += 'Delta: +' + (rec.delta.specsAdded || 0) + ' specs, ~' + (rec.delta.specsModified || 0) + ' modified, +' + (rec.delta.reqsAdded || 0) + ' reqs';
        html += '</div>';
      }
      html += '</div>';
    } else {
      html += '<div class="adopt-card"><h3>Spec-Code Alignment</h3><div class="empty-section">Run /sdd-reconcile</div></div>';
    }
    html += '</div>'; // end row-2b

    // Import card (full width)
    var imp = adoption.import;
    if (imp && imp.present) {
      html += '<div class="adopt-card"><h3>Imported Data</h3>';
      if (imp.sources && imp.sources.length > 0) {
        imp.sources.forEach(function(src) {
          html += '<div class="adopt-import-row">';
          html += '<span class="adopt-import-format">' + esc(src.format) + '</span>';
          html += '<span class="adopt-import-file">' + esc(src.file) + '</span>';
          html += '<span class="adopt-import-metric">' + (src.mappedCount || 0) + '/' + (src.itemCount || 0) + ' mapped</span>';
          html += '</div>';
        });
      }
      if (imp.totals) {
        html += '<div style="display:flex;gap:24px;margin-top:12px;padding-top:8px;border-top:1px solid var(--border);font-size:12px">';
        html += '<div><strong>' + (imp.totals.itemsProcessed || 0) + '</strong> <span style="color:var(--text2)">processed</span></div>';
        html += '<div><strong>' + (imp.totals.itemsMapped || 0) + '</strong> <span style="color:var(--text2)">mapped</span></div>';
        html += '<div><strong>' + (imp.totals.itemsSkipped || 0) + '</strong> <span style="color:var(--text2)">skipped</span></div>';
        html += '</div>';
      }
      if (imp.quality) {
        html += '<div style="display:flex;gap:24px;margin-top:8px;font-size:12px">';
        html += '<div>Completeness: <strong>' + (imp.quality.completeness || 0).toFixed(1) + '%</strong></div>';
        html += '<div>Duplicates: <strong>' + (imp.quality.duplicatesFound || 0) + '</strong></div>';
        html += '<div>Conflicts: <strong>' + (imp.quality.conflictsFound || 0) + '</strong></div>';
        html += '</div>';
      }
      if (imp.artifactsGenerated) {
        var ag = imp.artifactsGenerated;
        html += '<div style="margin-top:8px;font-size:11px;color:var(--text3)">Generated: ';
        html += (ag.requirements || 0) + ' requirements, ' + (ag.useCases || 0) + ' use cases, ' + (ag.apiContracts || 0) + ' API contracts';
        html += '</div>';
      }
      html += '</div>';
    }

    html += '</div>'; // end adopt-grid
    el.innerHTML = html;
  }

  function isStepDone(skillName, adoption) {
    if (skillName === "reverse-engineer" && adoption.reverseEngineering && adoption.reverseEngineering.present) return true;
    if (skillName === "reconcile" && adoption.reconciliation && adoption.reconciliation.present) return true;
    if (skillName === "import" && adoption.import && adoption.import.present) return true;
    if (skillName === "onboarding" && adoption.onboarding && adoption.onboarding.present) return true;
    return false;
  }

  // --- Adoption stat cards in Summary ---
  function addAdoptionStats() {
    var adoption = DATA.adoption || { present: false };
    var adoptStats = (DATA.statistics || {}).adoptionStats || {};
    if (adoption.present) {
      addStat("SDD Adoption", (adoptStats.overallAdoptionGrade || "\u2014") + " (" + (adoptStats.overallAdoptionScore || 0) + ")", "Adoption health grade", (adoptStats.overallAdoptionScore || 0) >= 60 ? "good" : "", "Overall SDD adoption score from onboarding assessment");
      var crit = adoptStats.criticalFindingsCount || 0;
      var high = adoptStats.highFindingsCount || 0;
      addStat("Code Findings", crit + high, crit + " critical, " + high + " high", (crit > 0) ? "warn" : "", "Critical and high-severity findings from reverse engineering");
    }
  }
  addAdoptionStats();

  // ==========================================
  // JSONP LIVE STATUS SYSTEM
  // ==========================================
  var LIVE_STATUS = null;
  var liveFailCount = 0;
  var liveInterval = null;
  var liveLastTimestamp = null;

  function updateActivityFeed(history) {
    var feed = $("activityFeed");
    if (!feed) return;
    if (!history || history.length === 0) {
      feed.innerHTML = '<div class="activity-empty">No live activity. Run a pipeline skill to see progress here.</div>';
      return;
    }
    feed.innerHTML = "";
    var entries = history.slice(-20);
    entries.forEach(function(entry) {
      var div = ce("div");
      div.className = "activity-entry";
      var iconCls = entry.type === "error" ? "error" : entry.type === "done" ? "done" : entry.type === "running" ? "running" : "info";
      var iconChar = entry.type === "error" ? "\u2717" : entry.type === "done" ? "\u2713" : entry.type === "running" ? "\u25B6" : "\u2022";
      div.innerHTML = '<span class="activity-icon ' + iconCls + '">' + iconChar + '</span>'
        + '<div class="activity-body">'
        + '<span class="activity-stage">' + esc(entry.stage || "") + '</span> '
        + '<span class="activity-msg">' + esc(entry.message || "") + '</span>'
        + '<div class="activity-time">' + timeAgo(entry.timestamp) + '</div>'
        + '</div>';
      feed.appendChild(div);
    });
    feed.scrollTop = feed.scrollHeight;
  }

  function updateLiveDots(active, stale) {
    var dots = document.querySelectorAll(".live-dot");
    dots.forEach(function(dot) {
      if (active) {
        dot.classList.remove("off");
        dot.classList.toggle("stale", !!stale);
      } else {
        dot.classList.add("off");
      }
    });
  }

  window.__SDD_LIVE_UPDATE = function(data) {
    if (!data) return;
    // Ignore older updates (race condition guard)
    if (liveLastTimestamp && data.lastHeartbeat && new Date(data.lastHeartbeat) < new Date(liveLastTimestamp)) return;
    liveLastTimestamp = data.lastHeartbeat || null;

    LIVE_STATUS = data;
    liveFailCount = 0;
    updateActivityFeed(data.history || []);

    // Check staleness
    var stale = false;
    if (data.lastHeartbeat && data.status === "running") {
      var hbAge = (Date.now() - new Date(data.lastHeartbeat).getTime()) / 1000;
      if (hbAge > 60) {
        stale = true;
        updateActivityFeed((data.history || []).concat([{
          timestamp: new Date().toISOString(), stage: data.currentStage || "", message: "Possibly stalled (no heartbeat for " + Math.floor(hbAge) + "s)", type: "error"
        }]));
      }
    }
    updateLiveDots(true, stale);
  };

  function pollLiveStatus() {
    // Remove previous script tag if any
    var prev = document.getElementById("sdd-live-script");
    if (prev) prev.remove();

    var script = ce("script");
    script.id = "sdd-live-script";
    script.src = "./live-status.js?_=" + Date.now();
    script.onerror = function() {
      liveFailCount++;
      if (liveFailCount >= 3) {
        updateLiveDots(false, false);
      }
      script.remove();
    };
    script.onload = function() {
      // __SDD_LIVE_UPDATE should have been called by the script
      script.remove();
    };
    try {
      document.head.appendChild(script);
    } catch(e) {
      liveFailCount++;
    }
  }

  function initLiveStatus() {
    pollLiveStatus();
    liveInterval = setInterval(pollLiveStatus, 5000);
  }

  // --- Initial render ---
  renderSummary();
  doFilter();
  renderCodeCoverage();
  renderAdoptionView();
  initLiveStatus();
})();
</script>
</body>
</html>
```

## Template Variables

| Variable | Description | Example |
|----------|-------------|---------|
| `{{DATA_JSON}}` | Serialized `traceability-graph.json` content (v3 schema) | `{"$schema":"traceability-graph-v3",...}` |
| `{{PROJECT_NAME}}` | Project name for title tag | `HackInHire` |

## Substitution Instructions

1. Read `dashboard/traceability-graph.json` as a string
2. Replace `{{DATA_JSON}}` with the raw JSON string (already valid JS object literal)
3. Replace `{{PROJECT_NAME}}` with the project name from the JSON
4. Write result to `dashboard/index.html`

## v5 Changes from v4

### Interactive Prompts (Phase 1)
- **Contextual Prompt Generation**: `getStagePrompt()` and `getNextAction()` produce Spanish-language, context-aware prompts based on pipeline state and coverage gaps
- **Copy-to-Clipboard**: All prompts have "Copy" buttons that write to clipboard with toast notification feedback
- **Next Action Card**: Prominent card at top of Summary view showing the single most important next step with copy-ready prompt
- **Hero Recommendation Copy Buttons**: Each recommendation in the Health Score hero now has a copy button with a full contextual prompt

### Pipeline Stage Popovers
- **Click-to-Open Popover**: Each pipeline stage shows a popover on click with status, last run date, artifact count, and stage-specific prompt
- **Popover Actions**: "Copy Prompt" button and "Filter by Stage" button within each popover
- **Click-Away Dismiss**: Clicking outside the popover or on another stage closes it

### Activity Feed & JSONP Live Status
- **Activity Feed Panel**: Scrollable feed in Summary view showing real-time pipeline activity entries with timestamps, stage names, and status icons
- **JSONP Polling**: Loads `./live-status.js` every 5 seconds via `<script>` tag injection (works with `file://` protocol)
- **`window.__SDD_LIVE_UPDATE(data)`**: Callback function that receives live status data and updates the activity feed
- **Live Dot Indicator**: Pulsing green dot when live status is active; yellow when stale; hidden when no live-status.js found
- **Stale Detection**: If heartbeat >60s and status=running, shows "Possibly stalled" warning
- **Graceful Degradation**: Silent no-op on file not found; live dot hidden after 3 failures; race condition guard via timestamp comparison

### New CSS Components
- `.toast`: Fixed bottom-right notification with slide-up animation and auto-dismiss
- `.copy-btn`: Inline copy button with clipboard icon and "Copied!" state
- `.next-action-card`: Accent-bordered card for the primary next action prompt
- `.prompt-block`: Monospace code block for prompt text with positioned copy button
- `.activity-panel` / `.activity-feed` / `.activity-entry`: Activity feed layout
- `.stage-popover`: Popover attached to pipeline stages with arrow indicator
- `.live-dot`: Pulsing indicator for live status with stale state

### New Reference Document
- `references/live-status-template.md`: JSONP schema, field reference, idle seed template, skill integration instructions

## v4 Changes from v3

### Bug Fixes & Visual Modernization
- 3 CRITICAL fixes (pipeline null crash, NaN stats, XSS)
- 4 HIGH fixes (undefined file, NaN gaps, filter conflict, ARIA)
- Inter font, shadow system, gradient bg, SVG health ring, CSS pipeline arrows
- View transitions, staggered fadeUp animations, custom tooltips, bento summary grid

### Adoption View (5th tab)
- Journey stepper, scenario card, health dimensions bars
- Findings severity+category, reconciliation alignment+divergences, import sources+quality
- Graceful empty states per sub-panel

## v3 Changes from v2

### Comprehension Dashboard (non-technical UX)
- **Executive Summary**: New default view with coverage progress bars, top gaps, artifact breakdown, and pipeline status
- **Health Score Hero**: Letter grade (A-F) with weighted score and actionable recommendations panel
- **Humanized Labels**: All abbreviations (UC, WF, BDD, INV, ADR) replaced with full human-readable names
- **Status Labels**: "Full" → "Complete", "Partial" → "In Progress", "Spec Only" → "Specified", "Untraced" → "Not Started"
- **Color Legend**: Visual legend below stats cards explaining status colors
- **WCAG Contrast Fixes**: Improved contrast ratios for --text2 (4.6:1), --text3, --yellow, --gray
- **Contextual Tooltips**: Stats cards and zero-count cells have explanatory tooltips
- **Responsive Hero**: Hero banner stacks vertically on mobile

### Status Calculation (unchanged)
- **Complete** (green): has UC + BDD + TASK + Code + Tests (all five)
- **In Progress** (yellow): has UC, AND (Code > 0 OR Tests > 0), but missing some
- **Specified** (orange): has UC but zero Code AND zero Tests
- **Not Started** (red): no UC

## v2 Changes from v1

### New Views
- **Matrix View**: Enhanced with Domain, Layer, Code, Tests columns. Status now includes code/test in calculation.
- **Classification View**: Groups REQs by business domain with progress bars and status dots.
- **Code Coverage View**: Lists source files with symbol-level traceability detail.

### Detail Panel (5 tabs)
- **Story**: Auto-generated natural language narrative about the artifact's implementation status.
- **Trace Chain**: Incoming/outgoing relationships (carried from v1).
- **Code**: Source code references (files, symbols, line numbers).
- **Tests**: Test references (files, test names, frameworks).
- **Documents**: All related artifacts grouped by type.

## Performance Notes

- Uses `textContent` instead of `innerHTML` for data rendering (XSS-safe)
- Event delegation via handler attachment during row creation
- Filter debounce at 150ms prevents layout thrashing
- CSS Grid for responsive stats and classification layouts
- Sticky header + filter bar for scroll context
- No external dependencies (zero network requests)
- Classification view renders only on filter change (lazy)
- Code coverage view renders once on load (static data)
- Summary view renders once on load (static data)
