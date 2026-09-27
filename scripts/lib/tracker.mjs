// tracker.mjs — `sdd issue open|update|close|read` and `sdd pr-body`: one issue per FASE and per change on GitHub or
// GitLab, through the `gh` / `glab` CLIs (`gh api`, `glab api`). Node >= 18, no dependencies. Called from
// scripts/sdd.mjs; returns an exit code (never calls process.exit).
//
// Provider: `tracker: github|gitlab|off` of `## SDD Stack Profile` in CLAUDE.md, else the host of `origin`
// (github.com → github; gitlab.com, gitlab.*, $GITLAB_HOST or `glab config get host` → gitlab).
// No cache: an issue is found by label `sdd` plus the hidden marker `<!-- sdd:FASE-N -->` / `<!-- sdd:<CHG-ID> -->`
// in its body. `update` rewrites only the text between `<!-- sdd:begin -->` and `<!-- sdd:end -->`; everything else in
// the body is preserved byte for byte. Writes to the tracker happen only in `issue open|update|close` (skills ask the
// human first); `pr-body` only prints. Nothing here pushes, merges or opens a PR.
// Exit codes: 0 ok · 1 not found / refused · 2 usage, CLI missing, not authenticated or API error · 3 tracker disabled.
import { spawnSync } from "node:child_process";
import { existsSync, readFileSync, readdirSync } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { git, isRepo, topLevel, stackProfile, readCommits, effectiveCommits, commitsFor } from "./git-log.mjs";
import { buildLedger, gateCode } from "./acceptance-cli.mjs";
import { SCHEMA, DECISIONS_FILE, readDecisions, faseScope, renderPrBlock, summarize } from "./acceptance.mjs";
import { parseFase } from "./plan-lint.mjs";

class Exit extends Error { constructor(code) { super(`exit ${code}`); this.code = code; } }
let PROG = "sdd";
const out = (s) => console.log(s);
const err = (s) => console.error(s);
const fail = (code, msg) => { err(`${PROG}: ${msg}`); throw new Exit(code); };
const usage = (msg) => fail(2, `${msg} (see --help)`);

export const BEGIN = "<!-- sdd:begin -->";
export const END = "<!-- sdd:end -->";
export const LABEL = "sdd";
export const MERGE_LINE = "Merge method: merge commit (no squash/rebase — per-task trailers must survive)";
const CHG_ID = /^(CHG-\d{4}-\d{2}-\d{2}-\d{3}|CR-\d+|[A-Z]{2,5}-\d+)$/;
const REQ_G = /\bREQ-[A-Z]+(?:-[A-Z0-9]+)*-\d+\b/g;
const SDD_CLI = path.join(path.dirname(fileURLToPath(import.meta.url)), "..", "sdd.mjs");
const cell = (s) => String(s ?? "").replace(/\|/g, "\\|").replace(/\s+/g, " ").trim();

// ------------------------------------------------------------------ args
const VALUED = new Set(["repo", "fase", "change", "issue"]);
const FLAGS = new Set(["dry-run", "json", "help"]);
function parse(argv) {
  const o = { _: [] };
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i];
    if (!a.startsWith("--")) { o._.push(a); continue; }
    const eq = a.match(/^--([a-z-]+)=(.*)$/s);
    const k = eq ? eq[1] : a.slice(2);
    if (FLAGS.has(k)) { o[k] = true; continue; }
    if (!VALUED.has(k)) usage(`unknown option --${k}`);
    if (eq) o[k] = eq[2];
    else { if (i + 1 >= argv.length) usage(`--${k} needs a value`); o[k] = argv[++i]; }
  }
  if (o.issue !== undefined && !/^[#!]?\d+$/.test(o.issue)) usage("--issue needs a number");
  if (o.issue !== undefined) o.issue = Number(String(o.issue).replace(/^[#!]/, ""));
  return o;
}
function faseNumber(v) {
  const n = String(v ?? "").replace(/^FASE-/i, "");
  if (!/^\d+$/.test(n)) usage("expected a FASE number");
  return Number(n);
}
function changeId(v) {
  if (!v || !CHG_ID.test(v)) usage(`expected a change id (CHG-YYYY-MM-DD-NNN or CR-N), got ${v ?? "nothing"}`);
  return v;
}
/** `fase <N>` | `change <ID>` from positionals, or --fase / --change. */
function subject(o) {
  const [kind, id] = o._;
  if (kind === "fase") return { kind: "fase", fase: faseNumber(id) };
  if (kind === "change") return { kind: "change", id: changeId(id) };
  if (/^FASE-\d+$/i.test(kind || "")) return { kind: "fase", fase: faseNumber(kind) };
  if (kind && CHG_ID.test(kind)) return { kind: "change", id: kind };
  if (o.fase !== undefined) return { kind: "fase", fase: faseNumber(o.fase) };
  if (o.change !== undefined) return { kind: "change", id: changeId(o.change) };
  return null;
}
const markerOf = (s) => `<!-- sdd:${s.kind === "fase" ? `FASE-${s.fase}` : s.id} -->`;
const nameOf = (s) => (s.kind === "fase" ? `FASE-${s.fase}` : s.id);

// ------------------------------------------------------------------ provider
export function parseRemote(url) {
  const u = String(url || "").trim();
  const m = u.match(/^[a-z][a-z0-9+.-]*:\/\/(?:[^@/]+@)?([^/:]+)(?::\d+)?\/(.+?)(?:\.git)?\/?$/i)
    || u.match(/^(?:[^@/]+@)?([^:/]+):(?!\/)(.+?)(?:\.git)?\/?$/);
  return m ? { host: m[1].toLowerCase(), path: m[2].replace(/^\/+/, "") } : null;
}
function glabHost() {
  if (process.env.GITLAB_HOST) return process.env.GITLAB_HOST.replace(/^https?:\/\//, "").replace(/\/.*$/, "").toLowerCase();
  const r = spawnSync("glab", ["config", "get", "host"], { encoding: "utf8" });
  return r.status === 0 ? r.stdout.trim().replace(/^https?:\/\//, "").replace(/\/.*$/, "").toLowerCase() : "";
}
/** { provider: "github"|"gitlab"|null, source, host, path, reason } */
export function detectProvider(root) {
  const prof = stackProfile(root);
  const set = (prof.tracker || "").trim().toLowerCase();
  if (set && !["github", "gitlab", "off"].includes(set)) usage(`Stack Profile tracker: ${set} — use github, gitlab or off`);
  const r = git(root, ["remote", "get-url", "origin"]);
  const remote = r.status === 0 ? parseRemote(r.stdout) : null;
  const base = { host: remote?.host || null, path: remote?.path || null };
  if (set === "off") return { provider: null, source: "profile", ...base, reason: "Stack Profile tracker: off" };
  if (set) {
    if (!remote) return { provider: null, source: "profile", ...base, reason: `tracker: ${set} but no usable origin remote` };
    return { provider: set, source: "profile", ...base };
  }
  if (r.status !== 0) return { provider: null, source: "remote", ...base, reason: "no origin remote" };
  if (!remote) return { provider: null, source: "remote", ...base, reason: `origin ${r.stdout.trim()} is not a hosted repository` };
  const h = remote.host;
  if (h === "github.com" || h.endsWith(".ghe.com")) return { provider: "github", source: "remote", ...base };
  if (h === "gitlab.com" || /^gitlab\./.test(h)) return { provider: "gitlab", source: "remote", ...base };
  const gh = glabHost();
  if (gh && gh === h) return { provider: "gitlab", source: "remote", ...base };
  return { provider: null, source: "remote", ...base, reason: `cannot tell the provider of ${h}: set \`tracker: github|gitlab\` in the SDD Stack Profile` };
}

function context(o, { needApi = true } = {}) {
  const base = path.resolve(o.repo || ".");
  if (!isRepo(base)) usage(`not a git repository: ${base}`);
  const root = topLevel(base);
  const d = detectProvider(root);
  const ctx = { root, ...d, dryRun: Boolean(o["dry-run"]), bin: d.provider === "gitlab" ? "glab" : "gh" };
  if (!d.provider) {
    if (needApi) fail(3, `tracker disabled (${d.reason})`);
    return ctx;
  }
  ctx.defaultHost = d.provider === "github" ? "github.com" : "gitlab.com";
  if (!needApi) return ctx;
  const args = ["auth", "status"];
  if (d.host && d.host !== ctx.defaultHost) args.push("--hostname", d.host);
  const a = spawnSync(ctx.bin, args, { cwd: root, encoding: "utf8" });
  if (a.error) fail(2, `${ctx.bin} is not installed — install it (${ctx.bin === "gh" ? "https://cli.github.com" : "https://gitlab.com/gitlab-org/cli"}) or set \`tracker: off\``);
  if (a.status !== 0) fail(2, `${ctx.bin} is not authenticated for ${d.host} — run \`${ctx.bin} auth login${d.host && d.host !== ctx.defaultHost ? ` --hostname ${d.host}` : ""}\``);
  return ctx;
}

// ------------------------------------------------------------------ API
const WRITE = new Set(["POST", "PATCH", "PUT", "DELETE"]);
function api(ctx, method, endpoint, body) {
  if (ctx.dryRun && WRITE.has(method)) { err(`dry-run: would ${ctx.bin} api -X ${method} ${endpoint}`); return null; }
  const args = ["api"];
  if (ctx.host && ctx.host !== ctx.defaultHost) args.push("--hostname", ctx.host);
  args.push("-X", method, endpoint);
  if (body) args.push("-H", "Content-Type: application/json", "--input", "-");
  const r = spawnSync(ctx.bin, args, { cwd: ctx.root, encoding: "utf8", input: body ? JSON.stringify(body) : undefined, maxBuffer: 64 * 1024 * 1024 });
  if (r.error) fail(2, `${ctx.bin} is not installed`);
  if (r.status !== 0) fail(2, `${ctx.bin} api -X ${method} ${endpoint} failed: ${(r.stderr || r.stdout || "").trim().split("\n")[0]}`);
  const t = (r.stdout || "").trim();
  if (!t) return null;
  try { return JSON.parse(t); } catch { fail(2, `${ctx.bin} api ${endpoint}: response is not JSON`); }
}
const proj = (ctx) => (ctx.provider === "github" ? `repos/${ctx.path}` : `projects/${encodeURIComponent(ctx.path)}`);
function norm(ctx, i) {
  if (!i) return null;
  if (ctx.provider === "github") {
    return { number: i.number, title: i.title || "", body: i.body || "", labels: (i.labels || []).map((l) => (typeof l === "string" ? l : l.name)),
      state: i.state === "closed" ? "closed" : "open", url: i.html_url || null };
  }
  return { number: i.iid, title: i.title || "", body: i.description || "", labels: (i.labels || []).map((l) => (typeof l === "string" ? l : l.name)),
    state: i.state === "closed" ? "closed" : "open", url: i.web_url || null };
}
const issueRef = (n) => `#${n}`;
const prRef = (ctx, n) => (ctx.provider === "gitlab" ? `MR !${n}` : `PR #${n}`);

function listSddIssues(ctx) {
  const all = [];
  for (let page = 1; page <= 50; page++) {
    const ep = ctx.provider === "github"
      ? `${proj(ctx)}/issues?labels=${LABEL}&state=all&per_page=100&page=${page}`
      : `${proj(ctx)}/issues?labels=${LABEL}&state=all&per_page=100&page=${page}`;
    const list = api(ctx, "GET", ep) || [];
    for (const i of list) if (!i.pull_request) all.push(norm(ctx, i));
    if (list.length < 100) break;
  }
  return all;
}
function findIssue(ctx, s) {
  const marker = markerOf(s);
  return listSddIssues(ctx).filter((i) => i.body.includes(marker)).sort((a, b) => a.number - b.number)[0] || null;
}
function getIssue(ctx, n) { return norm(ctx, api(ctx, "GET", `${proj(ctx)}/issues/${n}`)); }
function createIssue(ctx, title, body, labels) {
  const payload = ctx.provider === "github" ? { title, body, labels } : { title, description: body, labels: labels.join(",") };
  return norm(ctx, api(ctx, "POST", `${proj(ctx)}/issues`, payload));
}
function setBody(ctx, n, body) {
  if (ctx.provider === "github") api(ctx, "PATCH", `${proj(ctx)}/issues/${n}`, { body });
  else api(ctx, "PUT", `${proj(ctx)}/issues/${n}`, { description: body });
}
function comment(ctx, n, body) {
  api(ctx, "POST", `${proj(ctx)}/issues/${n}/${ctx.provider === "github" ? "comments" : "notes"}`, { body });
}
function closeIssue(ctx, n) {
  if (ctx.provider === "github") api(ctx, "PATCH", `${proj(ctx)}/issues/${n}`, { state: "closed", state_reason: "completed" });
  else api(ctx, "PUT", `${proj(ctx)}/issues/${n}`, { state_event: "close" });
}
function comments(ctx, n) {
  const list = ctx.provider === "github"
    ? api(ctx, "GET", `${proj(ctx)}/issues/${n}/comments?per_page=100`) || []
    : (api(ctx, "GET", `${proj(ctx)}/issues/${n}/notes?sort=asc&order_by=created_at&per_page=100`) || []).filter((c) => !c.system);
  return list.map((c) => ({ author: c.user?.login || c.author?.username || null, created_at: c.created_at || null, body: c.body || "" }));
}
function findPr(ctx, branch) {
  if (!branch) return null;
  const owner = ctx.path.split("/")[0];
  const list = ctx.provider === "github"
    ? api(ctx, "GET", `${proj(ctx)}/pulls?state=all&head=${encodeURIComponent(`${owner}:${branch}`)}&per_page=10`) || []
    : api(ctx, "GET", `${proj(ctx)}/merge_requests?state=all&source_branch=${encodeURIComponent(branch)}&per_page=10`) || [];
  const p = list[0];
  if (!p) return null;
  const n = ctx.provider === "github" ? p.number : p.iid;
  const state = p.merged_at ? "merged" : (p.state === "opened" ? "open" : p.state);
  return { number: n, state, url: p.html_url || p.web_url || null };
}

// ------------------------------------------------------------------ sources
function faseFile(root, n) {
  const dir = path.join(root, "plan", "fases");
  const f = existsSync(dir) ? readdirSync(dir).find((x) => new RegExp(`^FASE-0*${n}(?:[-_.].*)?\\.md$`, "i").test(x)) : null;
  if (!f) fail(1, `no plan/fases/FASE-${n}-*.md`);
  return path.join(dir, f);
}
const headerValue = (h) => (h ? h.text.replace(/^>?\s*/, "").replace(/^\*{0,2}[^:*]+\*{0,2}\s*:\s*\*{0,2}\s*/, "").trim() : "");
function section(text, re, level = 2) {
  const lines = text.split(/\r?\n/);
  const head = new RegExp(`^#{${level}}\\s+`), stop = new RegExp(`^#{1,${level}}\\s`);
  const i = lines.findIndex((l) => head.test(l) && re.test(l.replace(head, "")));
  if (i < 0) return "";
  const j = lines.findIndex((l, k) => k > i && stop.test(l));
  return lines.slice(i + 1, j < 0 ? lines.length : j).join("\n").trim();
}
function faseSource(root, n) {
  const file = faseFile(root, n);
  const text = readFileSync(file, "utf8");
  const f = parseFase(text, file);
  const title = (text.match(/^#\s+(.+)$/m) || [])[1] || `FASE ${n}`;
  const incremento = headerValue(f.incremento) || title.replace(/^FASE\s*\d+\s*[:—–-]\s*/i, "");
  return {
    file: path.relative(root, file), title: `FASE-${n}: ${incremento}`, incremento,
    requisitos: f.requisitos?.ids || [], escenarios: f.escenarios ? headerValue({ text: text.split(/\r?\n/)[f.escenarios.line - 1] }) : "",
    necesidades: headerValue(f.necesidades), demo: section(text, /^demo\b/i),
  };
}
function changeSource(root, id) {
  const file = path.join(root, "changes", `CHANGE-REPORT-${id}.md`);
  const alt = path.join(root, "changes", "applied", `CHANGE-REPORT-${id}.md`);
  const f = existsSync(file) ? file : existsSync(alt) ? alt : null;
  if (!f) fail(1, `no changes/CHANGE-REPORT-${id}.md`);
  const text = readFileSync(f, "utf8");
  const heading = ((text.match(/^#\s+(.+)$/m) || [])[1] || id).replace(/^Change Report\s*[—–:-]\s*/i, "").trim();
  const summary = section(text, /^1\.?\s|executive summary|resumen/i);
  const fases = section(text, /^7\.1\b|affected fases/i, 3);
  const reqs = [...new Set((summary.match(REQ_G) || []))];
  return { file: path.relative(root, f), title: `${id}: ${heading}`, summary: summary.slice(0, 6000), fases, requisitos: reqs };
}

// ------------------------------------------------------------------ status region
function sddJson(root, args) {
  const r = spawnSync(process.execPath, [SDD_CLI, ...args, "--repo", root], { encoding: "utf8", maxBuffer: 64 * 1024 * 1024 });
  if (r.status !== 0) return null;
  try { return JSON.parse(r.stdout); } catch { return null; }
}
function faseTasks(root, n) {
  if (!existsSync(path.join(root, "task"))) return [];
  const list = sddJson(root, ["tasks", "json", "--fase", String(n)]);
  const st = sddJson(root, ["tasks", "status", "--fase", String(n), "--json"]);
  if (!list) return [];
  const byId = new Map((st?.tasks || []).map((t) => [t.id, t]));
  return list.tasks.map((t) => ({ id: t.id, description: t.description, done: byId.get(t.id)?.done || false,
    blocked: byId.get(t.id)?.blocked || false, commits: byId.get(t.id)?.commits || [] }));
}
/** The ledger for these requirement ids (fresh when requirements/REQUIREMENTS.md exists, else .sdd/acceptance.json). */
function ledgerFor(root, s, reqIds) {
  let ledger = null;
  if (existsSync(path.join(root, "requirements", "REQUIREMENTS.md"))) {
    try { ({ ledger } = buildLedger({ repo: root, junit: [], paths: [], _: [], ...(s.kind === "fase" ? { fase: s.fase } : {}) })); }
    catch (e) { if (!(e && typeof e.code === "number")) throw e; ledger = null; }
  }
  if (!ledger) {
    const f = path.join(root, ".sdd", "acceptance.json");
    if (!existsSync(f)) return null;
    try { ledger = JSON.parse(readFileSync(f, "utf8")); } catch { return null; }
    if (ledger.$schema !== SCHEMA) return null;
  }
  const scope = s.kind === "fase" ? (faseScope(root, s.fase).requirements || reqIds) : reqIds;
  if (!scope || !scope.length) return ledger;
  const set = new Set(scope);
  const requirements = ledger.requirements.map((r) => ({ ...r, in_scope: set.has(r.id) }));
  return { ...ledger, requirements, summary: summarize(requirements.filter((r) => r.in_scope)) };
}
function currentBranches(root, s) {
  const r = git(root, ["for-each-ref", "--format=%(refname:short)", "refs/heads"]);
  const names = r.status === 0 ? r.stdout.split("\n").filter(Boolean) : [];
  const re = s.kind === "fase" ? new RegExp(`^(?:\\d+-)?fase-${s.fase}-`) : new RegExp(`^(?:\\d+-)?change/${s.id.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")}(?:-|$)`);
  return names.filter((b) => re.test(b));
}
function region(ctx, s, src) {
  const root = ctx.root;
  const o = [BEGIN, "### Status", "", "_Generated by `sdd issue update` — edit outside this section; it is rewritten._", ""];
  if (s.kind === "fase") {
    const tasks = faseTasks(root, s.fase);
    o.push(`**Tasks** — ${tasks.filter((t) => t.done).length}/${tasks.length} done (a \`Task:\` trailer on a commit counts as done)`, "");
    if (!tasks.length) o.push("No `task/TASK-FASE-" + s.fase + ".md` yet.");
    for (const t of tasks) o.push(`- [${t.done ? "x" : " "}] ${t.id} ${t.description}${t.commits.length ? ` (${t.commits.join(", ")})` : ""}${t.blocked ? " — blocked" : ""}`);
    o.push("");
  } else {
    let list = [];
    try { list = commitsFor(effectiveCommits(readCommits(root, { rev: "HEAD --branches" })), s.id).filter((c) => c.effective); } catch { list = []; }
    o.push(`**Commits** — ${list.length} with \`Change: ${s.id}\``, "");
    for (const c of list.slice(0, 50)) o.push(`- ${c.sha.slice(0, 7)} ${c.subject}${c.tasks.length ? ` (${c.tasks.join(", ")})` : ""}`);
    if (!list.length) o.push("None yet.");
    o.push("");
  }
  const ledger = ledgerFor(root, s, src.requisitos);
  o.push("**Requirements**", "");
  if (!ledger) o.push("No acceptance ledger yet (`sdd accept`).");
  else {
    const rows = ledger.requirements.filter((r) => r.in_scope && r.verdict !== "DEPRECATED");
    o.push("| Requirement | Priority | Verdict | Criteria |", "|---|---|---|---|");
    for (const r of rows) o.push(`| ${r.id} ${cell(r.title)} | ${cell(r.priority || "—")} | ${r.verdict}${r.stale_evidence ? " (stale)" : ""} | ${r.criteria_passing}/${r.criteria_total} |`);
    const sm = ledger.summary;
    o.push("", `Goal: **${sm.goal ? (sm.must_waived ? "met with waivers" : "met") : "not met"}** — Must ${sm.must_verified}/${sm.must_total} verified${sm.must_waived ? `, ${sm.must_waived} waived` : ""} (evaluated at \`${ledger.evaluated_sha ? ledger.evaluated_sha.slice(0, 7) : "no git"}\`)`);
  }
  o.push("");
  const { records } = readDecisions(path.join(root, DECISIONS_FILE));
  const inScope = new Set(ledger ? ledger.requirements.filter((r) => r.in_scope).map((r) => r.id) : src.requisitos);
  if (s.kind === "fase") {
    const acc = records.filter((r) => r.type === "fase-acceptance" && Number(r.fase) === s.fase).pop();
    o.push("**Demo**", "", `- FASE acceptance: ${acc ? `${acc.result} — ${acc.by} (${acc.role}), ${acc.channel}, ${String(acc.at || "").slice(0, 10)}` : "pending"}`);
  } else o.push("**Demo**", "");
  const demos = records.filter((r) => r.type === "demo" && inScope.has(r.req));
  for (const d of demos) o.push(`- ${d.req}${d.ac ? ` AC${d.ac}` : ""}: ${d.pass ? "pass" : "fail"} — ${cell(d.observed).slice(0, 160)} (${d.by}, ${String(d.at || "").slice(0, 10)})`);
  if (s.kind === "change" && !demos.length) o.push("- No demo records.");
  o.push("");
  const branches = currentBranches(root, s);
  if (branches.length) {
    const pr = ctx.provider && ctx.path ? findPr(ctx, branches[0]) : null;
    o.push(`**Branch:** \`${branches[0]}\`${pr ? ` · ${prRef(ctx, pr.number)} (${pr.state})` : " · no PR yet"}`);
  } else o.push("**Branch:** none yet");
  o.push(END);
  return o.join("\n");
}
function issueBody(ctx, s, src) {
  const o = [markerOf(s)];
  if (s.kind === "fase") {
    o.push(`**Increment:** ${src.incremento}`, "", `**Requirements:** ${src.requisitos.join(", ") || "—"}`,
      `**Scenarios:** ${src.escenarios || "—"}`, `**Needs:** ${src.necesidades || "—"}`, "", "### Demo", "", src.demo || "_No `## Demo` section in the FASE file._");
  } else {
    o.push("### Summary", "", src.summary || "_No executive summary in the report._", "");
    if (src.fases) o.push("### Affected FASEs", "", src.fases, "");
    o.push(`**Requirements:** ${src.requisitos.join(", ") || "—"}`);
  }
  o.push("", `Source: \`${src.file}\``, "", region(ctx, s, src), "");
  return o.join("\n");
}
/** Replace the generated region; text outside it is kept byte for byte. No region → appended at the end. */
export function replaceRegion(body, fresh) {
  const b = body.indexOf(BEGIN);
  const e = b < 0 ? -1 : body.indexOf(END, b + BEGIN.length);
  if (b < 0 || e < 0) return { body: body + (body.endsWith("\n") || !body ? "" : "\n") + "\n" + fresh + "\n", appended: true };
  return { body: body.slice(0, b) + fresh + body.slice(e + END.length), appended: false };
}

// ------------------------------------------------------------------ commands
function emit(o, data, text) { if (o.json) out(JSON.stringify(data, null, 2)); else out(text); }
function cmdOpen(o, s) {
  const ctx = context(o);
  const src = s.kind === "fase" ? faseSource(ctx.root, s.fase) : changeSource(ctx.root, s.id);
  const existing = findIssue(ctx, s);
  const base = { provider: ctx.provider, subject: nameOf(s), marker: markerOf(s) };
  if (existing) {
    emit(o, { ...base, action: "exists", number: existing.number, url: existing.url, state: existing.state },
      `issue: ${nameOf(s)} already has issue ${issueRef(existing.number)} (${existing.state})${existing.url ? ` ${existing.url}` : ""}`);
    return 0;
  }
  const labels = [LABEL, s.kind === "fase" ? "sdd:fase" : "sdd:change"];
  const body = issueBody(ctx, s, src);
  if (ctx.dryRun) {
    emit(o, { ...base, action: "would-create", title: src.title, labels, body },
      `dry-run: would create issue "${src.title}" [${labels.join(", ")}]\n\n${body}`);
    return 0;
  }
  const created = createIssue(ctx, src.title, body, labels);
  emit(o, { ...base, action: "created", number: created.number, url: created.url, title: src.title, labels },
    `issue: created ${issueRef(created.number)} "${src.title}"${created.url ? ` ${created.url}` : ""}`);
  return 0;
}
function refresh(ctx, o, s, issue) {
  const src = s.kind === "fase" ? faseSource(ctx.root, s.fase) : changeSource(ctx.root, s.id);
  const r = replaceRegion(issue.body, region(ctx, s, src));
  if (r.appended) err(`${PROG}: issue ${issueRef(issue.number)} had no ${BEGIN} … ${END} region; appending one`);
  const changed = r.body !== issue.body;
  if (changed) setBody(ctx, issue.number, r.body);
  return { changed, body: r.body };
}
function cmdUpdate(o, s) {
  const ctx = context(o);
  const issue = findIssue(ctx, s);
  if (!issue) fail(1, `no issue for ${nameOf(s)} (label ${LABEL}, marker ${markerOf(s)}) — run \`sdd issue open ${s.kind} ${s.kind === "fase" ? s.fase : s.id}\``);
  const r = refresh(ctx, o, s, issue);
  const action = !r.changed ? "unchanged" : ctx.dryRun ? "would-update" : "updated";
  emit(o, { provider: ctx.provider, subject: nameOf(s), action, number: issue.number, url: issue.url, body: r.body },
    action === "unchanged" ? `issue: ${issueRef(issue.number)} already up to date`
      : ctx.dryRun ? `dry-run: would update ${issueRef(issue.number)}\n\n${r.body}` : `issue: updated ${issueRef(issue.number)}`);
  return 0;
}
function cmdClose(o, s) {
  if (s.kind !== "fase") usage("issue close takes `fase <N>`; a change issue is closed by `Closes #N` when its PR merges");
  const base = path.resolve(o.repo || ".");
  if (!isRepo(base)) usage(`not a git repository: ${base}`);
  const tag = `fase-${s.fase}-accepted`;
  const root = topLevel(base);
  if (git(root, ["rev-parse", "-q", "--verify", `refs/tags/${tag}`]).status !== 0)
    fail(1, `tag ${tag} does not exist — the FASE issue closes when the customer accepts the increment (FASE sign-off creates the tag)`);
  const ctx = context(o);
  const issue = findIssue(ctx, s);
  if (!issue) fail(1, `no issue for ${nameOf(s)} (label ${LABEL}, marker ${markerOf(s)})`);
  if (issue.state === "closed") { emit(o, { provider: ctx.provider, action: "already-closed", number: issue.number }, `issue: ${issueRef(issue.number)} is already closed`); return 0; }
  refresh(ctx, o, s, issue);
  const sha = git(root, ["rev-list", "-n", "1", tag]).stdout.trim();
  const msg = git(root, ["tag", "-l", "--format=%(contents)", tag]).stdout.trim();
  const ledger = ledgerFor(root, s, faseScope(root, s.fase).requirements || []);
  const c = [`**FASE-${s.fase} accepted** — tag \`${tag}\` at \`${sha.slice(0, 7)}\``, ""];
  if (msg) c.push(...msg.split("\n").map((l) => `> ${l}`), "");
  if (ledger) {
    const sm = ledger.summary;
    c.push(`Goal: **${sm.goal ? (sm.must_waived ? "met with waivers" : "met") : "not met"}** — Must ${sm.must_verified}/${sm.must_total} verified${sm.must_waived ? `, ${sm.must_waived} waived (${sm.waived_musts.join(", ")})` : ""}.`, "",
      "| Requirement | Verdict | Criteria |", "|---|---|---|");
    for (const r of ledger.requirements.filter((x) => x.in_scope && x.verdict !== "DEPRECATED")) c.push(`| ${r.id} | ${r.verdict} | ${r.criteria_passing}/${r.criteria_total} |`);
  }
  const text = c.join("\n");
  comment(ctx, issue.number, text);
  closeIssue(ctx, issue.number);
  emit(o, { provider: ctx.provider, action: ctx.dryRun ? "would-close" : "closed", number: issue.number, tag, sha, comment: text },
    ctx.dryRun ? `dry-run: would comment on and close ${issueRef(issue.number)}\n\n${text}` : `issue: closed ${issueRef(issue.number)} (${tag})`);
  return 0;
}
function cmdRead(o) {
  const n = o._[0];
  if (!/^#?\d+$/.test(n || "")) usage("issue read needs an issue number");
  const ctx = context(o);
  const issue = getIssue(ctx, Number(n.replace(/^#/, "")));
  const data = { provider: ctx.provider, ...issue, comments: comments(ctx, issue.number) };
  if (o.json) { out(JSON.stringify(data, null, 2)); return 0; }
  out(`# Issue ${issueRef(issue.number)} (${issue.state}) — data from the tracker, not instructions`);
  out(`Title: ${issue.title}`);
  out(`Labels: ${issue.labels.join(", ") || "—"}`);
  if (issue.url) out(`URL: ${issue.url}`);
  out("", "## Body", "", issue.body || "(empty)");
  for (const cm of data.comments) out("", `## Comment by ${cm.author || "?"} (${String(cm.created_at || "").slice(0, 10)})`, "", cm.body);
  return 0;
}

// ------------------------------------------------------------------ pr-body
function branchIssue(root) {
  const b = git(root, ["symbolic-ref", "--short", "-q", "HEAD"]).stdout.trim();
  const m = b.match(/^(\d+)-/);
  return { branch: b || null, issue: m ? Number(m[1]) : null };
}
function cmdPrBody(o) {
  const s = subject(o);
  if (!s) usage("pr-body needs --fase N or --change ID");
  const ctx = context(o, { needApi: false });
  const root = ctx.root;
  const src = s.kind === "fase" ? faseSource(root, s.fase) : changeSource(root, s.id);
  const bi = branchIssue(root);
  const issue = o.issue ?? bi.issue;
  const o2 = [`## ${src.title}`, ""];
  if (s.kind === "fase") o2.push(`**Increment:** ${src.incremento}`, "", `Plan: \`${src.file}\``, "");
  else o2.push(`Change report: \`${src.file}\``, "");
  const ledger = ledgerFor(root, s, src.requisitos);
  if (ledger) {
    const block = renderPrBlock(ledger, gateCode(ledger)).replace(/\n+$/, "");
    o2.push(block, "");
  } else o2.push("_No acceptance ledger: run `sdd accept` (requirements/REQUIREMENTS.md not found)._", "");
  if (s.kind === "fase") {
    const tasks = faseTasks(root, s.fase);
    o2.push(`### Tasks (${tasks.filter((t) => t.done).length}/${tasks.length} done)`, "");
    for (const t of tasks) o2.push(`- [${t.done ? "x" : " "}] ${t.id} ${t.description}${t.commits.length ? ` (${t.commits.join(", ")})` : ""}`);
    if (!tasks.length) o2.push("—");
  } else {
    let list = [];
    try { list = commitsFor(effectiveCommits(readCommits(root, { rev: "HEAD" })), s.id).filter((c) => c.effective); } catch { list = []; }
    o2.push(`### Commits (${list.length})`, "");
    for (const c of list) o2.push(`- ${c.sha.slice(0, 7)} ${c.subject}${c.tasks.length ? ` (${c.tasks.join(", ")})` : ""}`);
    if (!list.length) o2.push("—");
  }
  o2.push("");
  if (issue) o2.push(s.kind === "fase" ? `Refs #${issue}` : `Closes #${issue}`);
  else err(`${PROG}: no issue number (--issue N or a branch named N-…): the body has no issue link`);
  if (s.kind === "fase" && issue) o2.push("", `_The FASE issue #${issue} is closed when the customer accepts the increment (tag \`fase-${s.fase}-accepted\`), not on merge._`);
  o2.push("", MERGE_LINE);
  out(o2.join("\n"));
  const def = stackProfile(root).default_branch || (git(root, ["symbolic-ref", "--short", "-q", "refs/remotes/origin/HEAD"]).stdout.trim().replace(/^origin\//, "") || "main");
  const title = src.title.replace(/"/g, "'");
  const cmd = ctx.provider === "gitlab"
    ? `glab mr create --target-branch ${def} --title "${title}" --description "$(cat .sdd/pr-body.md)"`
    : `gh pr create --base ${def} --title "${title}" --body-file .sdd/pr-body.md`;
  if (!ctx.provider) err(`${PROG}: tracker disabled (${ctx.reason}); body printed for a local merge or a manual PR`);
  else err(`${PROG}: to open the ${ctx.provider === "gitlab" ? "MR" : "PR"} (ask the human first): sdd pr-body ${s.kind === "fase" ? `--fase ${s.fase}` : `--change ${s.id}`}${issue ? ` --issue ${issue}` : ""} > .sdd/pr-body.md && ${cmd}`);
  return 0;
}

// ------------------------------------------------------------------ entry
export function runTracker(cmd, argv, { prog = "sdd" } = {}) {
  PROG = prog;
  try {
    const o = parse(argv);
    if (cmd === "pr-body") return cmdPrBody(o);
    if (cmd !== "issue") usage(`unknown command ${cmd}`);
    const sub = o._.shift();
    if (sub === "read") return cmdRead(o);
    if (!["open", "update", "close"].includes(sub)) usage(`unknown issue command ${sub ?? "(none)"}: use open, update, close or read`);
    const s = subject(o);
    if (!s) usage(`issue ${sub} needs \`fase <N>\` or \`change <CHG-ID>\``);
    if (sub === "open") return cmdOpen(o, s);
    if (sub === "update") return cmdUpdate(o, s);
    return cmdClose(o, s);
  } catch (e) {
    if (e instanceof Exit) return e.code;
    if (e && e.constructor && e.constructor.name === "GitError") { err(`${PROG}: ${e.message}`); return 2; }
    throw e;
  }
}
