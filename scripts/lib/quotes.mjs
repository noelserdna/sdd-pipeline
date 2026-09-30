// quotes.mjs — the literal lint (sdd-pipeline 5.1, `sdd lint --quotes`): does the test that verifies a criterion carry
// the criterion's letter? Node >= 18, no dependencies. Library only: no console output, no process.exit.
//
// Pairs. A test file is a source file under the Stack Profile's test_paths (default tests). It names a criterion when its
// code (comments removed) carries `REQ-X-NNN ACn`, or a scenario id AC-NNN-NN that a BDD tag of spec/tests/BDD-*.md
// binds to `[REQ-X-NNN ACn]` (the same index as the acceptance ledger). Each (criterion, file) is one pair.
//
// Findings per pair:
//   Q-01 warn   the file has no quote comment `REQ-X-NNN ACn: "…"` (tdd-workflow.md, "The criterion's letter sits
//               above its assert").
//   Q-02 error  a quote comment for the criterion is not the criterion's current text: normalized (whitespace
//               collapsed, the quote marks ' " « » “ ” ‘ ’ ` made equal, case kept), each fragment between `…` must be
//               a substring of the criterion, in order. A forged quote, or one left behind by a MODIFY.
//   Q-03 error  a literal of the criterion does not appear in the file's code outside comments (same normalization).
//               A literal in a comment (the quote itself) does not count.
//
// What counts as a literal of the criterion:
//   - the text between "…", '…', «…», “…” or ‘…’ anywhere in the criterion (a single quote opens and closes only
//     next to a non-letter, so an apostrophe — user's — is not a quote);
//   - the text between backticks only in the THEN part (from the first THEN / ENTONCES): an expected output or message
//     such as `No tasks`. A backtick span before THEN is the command or route the test drives (`todo add "Buy milk"`,
//     `/projects`); a helper builds it, so it is not required verbatim, and quotes inside it are not literals either;
//   - empty literals ("") are ignored.
// A literal a helper builds (never verbatim in the file) is a false positive: a person records
// `sdd accept record literal-exception --req ID --ac N --literal TEXT --reason …`, which holds while the
// requirement's text keeps its reqHash.
import { readFileSync, readdirSync, statSync } from "node:fs";
import path from "node:path";
import { stackProfile } from "./git-log.mjs";
import { testKeys, reqHash, acNumber, scenarioIndex } from "./acceptance.mjs";

export const LITERAL_MODES = ["off", "warn", "enforce"];
export const QUOTE_CODES = { missingQuote: "Q-01", staleQuote: "Q-02", missingLiteral: "Q-03" };

/** Stack Profile `literal_gate`: off | warn | enforce; default and any other value: enforce. */
export function literalGate(root) {
  const v = String(stackProfile(root).literal_gate || "").trim().toLowerCase();
  return LITERAL_MODES.includes(v) ? v : "enforce";
}

// ------------------------------------------------------------------ normalization
const QUOTE_CHARS = /["'«»“”‘’„‚`´]/g;
/** Whitespace collapsed, every quote mark made `"`, escaped quotes unescaped; case kept. */
export function normLiteral(s) {
  return String(s ?? "").normalize("NFC").replace(/\\(["'`])/g, "$1").replace(QUOTE_CHARS, '"').replace(/\s+/g, " ").trim();
}

// ------------------------------------------------------------------ literals of a criterion
const mask = (s, from, len) => s.slice(0, from) + " ".repeat(len) + s.slice(from + len);

/** Literals of one criterion: [{ literal, kind: "quote" | "code" }], unique by normalized text. */
export function criterionLiterals(text) {
  const s = String(text || "");
  let thenAt = s.search(/\b(?:THEN|ENTONCES)\b/);
  if (thenAt < 0) thenAt = s.search(/\b(?:then|entonces)\b/i);
  if (thenAt < 0) thenAt = 0;
  const found = [];
  let rest = s;
  for (const m of s.matchAll(/`([^`]*)`/g)) {
    if (m.index >= thenAt) found.push({ at: m.index, literal: m[1], kind: "code" });
    rest = mask(rest, m.index, m[0].length);
  }
  // Outer pairs first: an inner quote (“the title 'X'”) is part of the outer literal, which is the stronger check.
  for (const re of [/«([^»]*)»/g, /“([^”]*)”/g, /"([^"]*)"/g, /‘([^’]*)’/g, /(?<![\p{L}\p{N}])'([^'\n]*?)'(?![\p{L}\p{N}])/gu]) {
    for (const m of [...rest.matchAll(re)]) {
      found.push({ at: m.index, literal: m[1], kind: "quote" });
      rest = mask(rest, m.index, m[0].length);
    }
  }
  const seen = new Set(), out = [];
  for (const f of found.sort((a, b) => a.at - b.at)) {
    const k = normLiteral(f.literal);
    if (!k || seen.has(k)) continue;
    seen.add(k);
    out.push({ literal: f.literal.trim(), kind: f.kind });
  }
  return out;
}

/** True when `quote` (a test's quote comment) is the criterion's text: each fragment between ellipses is a substring
 *  of the criterion, in order. */
export function quoteMatches(quote, criterion) {
  const c = normLiteral(criterion);
  const parts = normLiteral(quote).split(/…|\.\.\./).map((p) => p.trim()).filter(Boolean);
  if (!parts.length) return false;
  let from = 0;
  for (const p of parts) {
    const i = c.indexOf(p, from);
    if (i < 0) return false;
    from = i + p.length;
  }
  return true;
}

// ------------------------------------------------------------------ source files
const HASH_COMMENTS = new Set([".rb", ".py", ".sh", ".bash", ".feature", ".ex", ".exs", ".r", ".pl", ".yml", ".yaml", ".toml", ".cr", ".nim"]);
const SOURCE_EXT = new Set([".js", ".mjs", ".cjs", ".jsx", ".ts", ".mts", ".cts", ".tsx", ".vue", ".svelte", ".rb", ".py", ".go", ".java",
  ".kt", ".kts", ".scala", ".groovy", ".cs", ".fs", ".php", ".rs", ".swift", ".dart", ".ex", ".exs", ".feature", ".sh", ".bash",
  ".c", ".cc", ".cpp", ".h", ".hpp", ".m", ".clj", ".cr", ".nim", ".r", ".pl"]);
const MAX_BYTES = 2 * 1024 * 1024;

/**
 * Split a source file into code and comments. Returns { code, comments: [{ line, text }] }: `code` keeps every
 * character outside comments (comments become spaces, newlines stay, so line numbers hold); each comment line is one
 * entry (a block comment gives one per line, leading `*` removed). Strings are skipped so that `//` or `#` inside
 * them is not a comment; a '…' or "…" string ends at the end of its line (Rust lifetimes, stray apostrophes).
 * Comment syntax by extension: `#` for Ruby, Python, shell, Gherkin, Elixir…; `//` and `/* … *\/` otherwise.
 */
export function splitComments(text, file = "") {
  const ext = path.extname(file).toLowerCase();
  const hash = HASH_COMMENTS.has(ext);
  const py = ext === ".py";
  const src = String(text);
  let code = "";
  const comments = [];
  let line = 1, i = 0;
  const n = src.length;
  const addComment = (from, to, startLine) => {
    const body = src.slice(from, to);
    body.split("\n").forEach((l, k) => {
      const t = l.replace(/^\s*(?:\/\/+|#+|\/\*+|\*+(?!\/))\s?/, "").replace(/\s*\*+\/\s*$/, "").trim();
      if (t) comments.push({ line: startLine + k, text: t });
    });
    code += body.replace(/[^\n]/g, " ");
  };
  while (i < n) {
    const ch = src[i];
    if (ch === "\n") { code += ch; line++; i++; continue; }
    // Comments.
    if (hash ? ch === "#" : (ch === "/" && src[i + 1] === "/")) {
      let j = src.indexOf("\n", i); if (j < 0) j = n;
      addComment(i, j, line); i = j; continue;
    }
    if (!hash && ch === "/" && src[i + 1] === "*") {
      let j = src.indexOf("*/", i + 2); j = j < 0 ? n : j + 2;
      const start = line;
      addComment(i, j, start);
      line += (src.slice(i, j).match(/\n/g) || []).length;
      i = j; continue;
    }
    // Strings.
    if (py && (src.startsWith('"""', i) || src.startsWith("'''", i))) {
      const q = src.slice(i, i + 3);
      let j = src.indexOf(q, i + 3); j = j < 0 ? n : j + 3;
      const s = src.slice(i, j); code += s; line += (s.match(/\n/g) || []).length; i = j; continue;
    }
    if (ch === '"' || ch === "'" || ch === "`") {
      let j = i + 1;
      while (j < n && src[j] !== ch) {
        if (src[j] === "\\") { j += 2; continue; }
        if (src[j] === "\n" && ch !== "`") break;
        j++;
      }
      j = Math.min(n, src[j] === ch ? j + 1 : j);
      const s = src.slice(i, j); code += s; line += (s.match(/\n/g) || []).length; i = j; continue;
    }
    code += ch; i++;
  }
  return { code, comments };
}

/** Quote comments of a file: [{ req, ac, quote, line }]. A quote opens with ' " « “ ‘ right after `REQ-X-NNN ACn:` and
 *  closes at the last matching mark of its comment line, or of a following comment line (a quote wrapped over
 *  several comment lines); unclosed, it runs to the end of the line. */
export function findQuotes(comments) {
  const CLOSE = { '"': '"', "'": "'", "«": "»", "“": "”", "‘": "’" };
  const out = [];
  comments.forEach((c, k) => {
    for (const m of c.text.matchAll(/(?<![A-Za-z0-9])(REQ-[A-Z]+(?:-[A-Z0-9]+)*-\d+)[\s_-]+AC0*(\d+)(?!\d)\s*:\s*(["'«“‘])/g)) {
      const close = CLOSE[m[3]];
      let body = c.text.slice(m.index + m[0].length);
      let end = body.lastIndexOf(close);
      for (let j = k + 1; end < 0 && j < comments.length && j <= k + 10 && comments[j].line === comments[j - 1].line + 1; j++) {
        body += " " + comments[j].text;
        end = body.lastIndexOf(close);
      }
      out.push({ req: m[1], ac: Number(m[2]), quote: (end < 0 ? body : body.slice(0, end)).trim(), line: c.line });
    }
  });
  return out;
}

const profileList = (v) => String(v || "").split(",").map((s) => s.trim().replace(/^\.\//, "").replace(/\/+$/, "")).filter(Boolean);
/** The Stack Profile's test_paths (default tests). */
export function testPathsOf(root) {
  const t = profileList(stackProfile(root).test_paths);
  return t.length ? t : ["tests"];
}

/** Source files under the test paths: [{ abs, rel }] (posix rel), skipping dot directories and node_modules. */
export function testFiles(root, testPaths = testPathsOf(root)) {
  const out = [], seen = new Set();
  const walk = (abs) => {
    let st;
    try { st = statSync(abs); } catch { return; }
    if (st.isDirectory()) {
      let entries = [];
      try { entries = readdirSync(abs); } catch { return; }
      for (const e of entries.sort()) if (!e.startsWith(".") && e !== "node_modules" && e !== "__snapshots__") walk(path.join(abs, e));
    } else if (st.isFile() && SOURCE_EXT.has(path.extname(abs).toLowerCase()) && st.size <= MAX_BYTES && !seen.has(abs)) {
      seen.add(abs);
      out.push({ abs, rel: path.relative(root, abs).split(path.sep).join("/") });
    }
  };
  for (const p of testPaths) walk(path.resolve(root, p));
  return out.sort((a, b) => a.rel.localeCompare(b.rel));
}

// ------------------------------------------------------------------ lint
/** Literal exceptions of decisions.jsonl that still hold: same reqHash as the requirement's current text. */
export function literalExceptions(records, reqs) {
  const byId = new Map(reqs.map((r) => [r.id, r]));
  return (records || []).filter((r) => r.type === "literal-exception").map((r) => {
    const req = byId.get(r.req);
    return { ...r, current: Boolean(req) && !req.deprecated && r.reqHash === reqHash(req) };
  });
}

/**
 * Run the lint. opts: { root, reqs, scenarios, records (decisions), scope: Set of REQ ids | null, testPaths }.
 * Returns { findings: [{ code, severity: warn|error|excepted, req, ac, file, line, message, literal?, quote?, exception? }],
 *           summary: { files, test_files, pairs, criteria, errors, warnings, excepted }, pairs: [{ req, ac, file }] }.
 */
export function lintQuotes({ root, reqs, scenarios = [], records = [], scope = null, testPaths } = {}) {
  const byId = new Map(reqs.map((r) => [r.id, r]));
  const { byScenario } = scenarioIndex(scenarios);
  const exceptions = literalExceptions(records, reqs).filter((e) => e.current);
  const files = testFiles(root, testPaths || testPathsOf(root));
  const findings = [], pairs = [];
  let filesWithPairs = 0;
  for (const f of files) {
    let text;
    try { text = readFileSync(f.abs, "utf8"); } catch { continue; }
    if (!/AC[-_ ]?\d/i.test(text)) continue;
    const { code, comments } = splitComments(text, f.rel);
    // Criteria this file names in its code, with the first line that names each.
    const named = new Map();
    code.split("\n").forEach((l, k) => {
      const keys = testKeys(l);
      const hits = [...keys.reqAcs];
      for (const sid of keys.scenarios) for (const t of byScenario.get(sid) || []) if (t.n > 0) hits.push({ req: t.req, ac: t.n });
      for (const h of hits) {
        const req = byId.get(h.req);
        if (!req || req.deprecated || h.ac < 1 || h.ac > req.criteria.length) continue;
        if (scope && !scope.has(h.req)) continue;
        const key = `${h.req}#${h.ac}`;
        if (!named.has(key)) named.set(key, { req, ac: h.ac, line: k + 1 });
      }
    });
    if (!named.size) continue;
    filesWithPairs++;
    const quotes = findQuotes(comments);
    const codeNorm = normLiteral(code);
    for (const { req, ac, line } of [...named.values()].sort((a, b) => a.line - b.line)) {
      pairs.push({ req: req.id, ac, file: f.rel });
      const text = req.criteria[ac - 1];
      const mine = quotes.filter((q) => q.req === req.id && q.ac === ac);
      const base = { req: req.id, ac, file: f.rel };
      if (!mine.length)
        findings.push({ code: "Q-01", severity: "warn", ...base, line, message: `no quote comment \`${req.id} AC${ac}: "…"\` above the assert (sdd req show ${req.id} --ac ${ac})` });
      for (const q of mine.filter((x) => !quoteMatches(x.quote, text)))
        findings.push({ code: "Q-02", severity: "error", ...base, line: q.line, quote: q.quote, message: `the quote is not the current text of ${req.id} AC${ac} (forged, or left behind by a MODIFY): quote it again with sdd req show ${req.id} --ac ${ac}` });
      const at = mine.length ? mine[0].line : line;
      for (const lit of criterionLiterals(text)) {
        if (codeNorm.includes(normLiteral(lit.literal))) continue;
        const ex = exceptions.find((e) => e.req === req.id && acNumber(e.ac) === ac && normLiteral(e.literal) === normLiteral(lit.literal));
        findings.push({ code: "Q-03", severity: ex ? "excepted" : "error", ...base, line: at, literal: lit.literal,
          message: `the literal "${lit.literal}" of ${req.id} AC${ac} is not in the test's code (a comment does not count)${ex ? ` — excepted by ${ex.by} (${ex.role}), acceptance/decisions.jsonl:${ex.line}` : ""}`,
          ...(ex ? { exception: { line: ex.line, by: ex.by, role: ex.role, reason: ex.reason } } : {}) });
      }
    }
  }
  const order = { "Q-01": 1, "Q-02": 2, "Q-03": 3 };
  findings.sort((a, b) => a.file.localeCompare(b.file) || a.line - b.line || order[a.code] - order[b.code]);
  const count = (s) => findings.filter((x) => x.severity === s).length;
  return {
    findings, pairs,
    summary: { test_files: files.length, files: filesWithPairs, pairs: pairs.length, criteria: new Set(pairs.map((p) => `${p.req}#${p.ac}`)).size,
      errors: count("error"), warnings: count("warn"), excepted: count("excepted") },
  };
}

/** Per criterion `REQ#n` → the gaps a ledger counts: Q-02 and Q-03 errors not excepted. */
export function literalGapsByCriterion(result) {
  const m = new Map();
  for (const f of result.findings) {
    if (f.severity !== "error") continue;
    const k = `${f.req}#${f.ac}`;
    if (!m.has(k)) m.set(k, []);
    m.get(k).push({ code: f.code, file: f.file, line: f.line, ...(f.literal !== undefined ? { literal: f.literal } : {}), ...(f.quote !== undefined ? { quote: f.quote } : {}) });
  }
  return m;
}

/** Whether `literal` is a literal of the criterion (for `accept record literal-exception`). */
export function isCriterionLiteral(text, literal) {
  const want = normLiteral(literal);
  return criterionLiterals(text).some((l) => normLiteral(l.literal) === want);
}
