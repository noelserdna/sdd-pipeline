// junit.mjs — tolerant JUnit XML reader (sdd-pipeline). Node >= 18, no dependencies. Library only.
//
// Reads the JUnit dialects written by vitest, jest-junit, pytest (xunit1/xunit2), rspec_junit_formatter, playwright,
// minitest-reporters and mocha-junit-reporter. It is a small tag scanner, not a validating XML parser: it only needs
// <testsuite> (for a file attribute or a path-like name) and <testcase> with its <failure>/<error>/<skipped> children.
// Attachments of a testcase (screenshots, videos, traces) come from `[[ATTACHMENT|path]]` lines in its <system-out> /
// <system-err> and from `<property name="attachment" value="path">`; paths are kept as written (resolved by the ledger).
//
//   parseJUnit(xml, source?)  → [{ name, classname, file, time, status: pass|fail|error|skip, message, suite, source,
//                                  attachments: [path] }]
//   junitFiles(base, specs)   → absolute .xml paths for files, directories (recursive) and simple `*` globs
//   readJUnit(base, specs)    → { files: [{ path, mtimeMs, cases }], cases: [...] }
import { readFileSync, readdirSync, statSync, existsSync } from "node:fs";
import path from "node:path";

const ENTITIES = { lt: "<", gt: ">", amp: "&", quot: '"', apos: "'" };
export function decodeEntities(s) {
  return String(s ?? "").replace(/&(#x[0-9a-f]+|#\d+|[a-z]+);/gi, (all, e) => {
    if (e[0] === "#") {
      const code = e[1] === "x" || e[1] === "X" ? parseInt(e.slice(2), 16) : parseInt(e.slice(1), 10);
      return Number.isFinite(code) ? String.fromCodePoint(code) : all;
    }
    return ENTITIES[e.toLowerCase()] ?? all;
  });
}

function attrs(s) {
  const o = {};
  for (const m of String(s).matchAll(/([A-Za-z_:][\w:.-]*)\s*=\s*("([^"]*)"|'([^']*)')/g)) o[m[1]] = decodeEntities(m[3] ?? m[4]);
  return o;
}

const PATHLIKE = /[\\/]|\.(?:[cm]?[jt]sx?|py|rb|go|java|kt|cs|php|rs|feature|spec)$/i;
const cleanPath = (p) => String(p).replace(/\\/g, "/").replace(/^\.\//, "");

/** Text of an element body: CDATA unwrapped, tags removed, entities decoded. */
function bodyText(s) {
  return decodeEntities(String(s).replace(/<!\[CDATA\[([\s\S]*?)\]\]>/g, "$1").replace(/<[^>]+>/g, "")).trim();
}

/** Playwright (and Jenkins JUnit attachments) write `[[ATTACHMENT|path]]` lines in a testcase's <system-out>. */
const ATTACHMENT = /\[\[ATTACHMENT\|([^\]\r\n]+)\]\]/g;

export function parseJUnit(xml, source = null) {
  const text = String(xml).replace(/^\uFEFF/, "");
  const cases = [];
  const suites = [];
  let cur = null;
  // Tokens: comments, CDATA and processing instructions are skipped; element bodies of failure/error/skipped are
  // sliced directly so that their text (often CDATA with stack traces) never confuses the scanner.
  const re = /<!--[\s\S]*?-->|<!\[CDATA\[[\s\S]*?\]\]>|<\?[\s\S]*?\?>|<!DOCTYPE[^>]*>|<(\/?)([A-Za-z_][\w:.-]*)((?:\s+[^\s=/>]+\s*=\s*(?:"[^"]*"|'[^']*'))*)\s*(\/?)>/g;
  let m;
  while ((m = re.exec(text))) {
    if (!m[2]) continue;
    const closing = m[1] === "/", tag = m[2].toLowerCase().replace(/^.*:/, ""), selfClose = m[4] === "/";
    if (tag === "testsuite") {
      if (closing) { suites.pop(); continue; }
      const a = attrs(m[3]);
      if (!selfClose) suites.push(a);
      continue;
    }
    if (tag === "testcase") {
      if (closing) { if (cur) cases.push(cur); cur = null; continue; }
      if (cur) cases.push(cur);
      const a = attrs(m[3]);
      const suite = suites[suites.length - 1] || {};
      let file = a.file || a.filepath || suite.file || suite.filepath || null;
      if (!file && a.classname && PATHLIKE.test(a.classname) && !/\s/.test(a.classname)) file = a.classname;
      if (!file && suite.name && PATHLIKE.test(suite.name) && !/\s/.test(suite.name)) file = suite.name;
      cur = { name: a.name ?? "", classname: a.classname ?? null, file: file ? cleanPath(file) : null,
        time: a.time !== undefined && a.time !== "" ? Number(a.time) : null, status: "pass", message: null,
        suite: suite.name ?? null, source, attachments: [] };
      if (selfClose) { cases.push(cur); cur = null; }
      continue;
    }
    if (!cur || closing) continue;
    if (tag === "property") {
      const a = attrs(m[3]);
      if (String(a.name || "").toLowerCase() === "attachment" && a.value) cur.attachments.push(a.value.trim());
      continue;
    }
    if (tag === "system-out" || tag === "system-err") {
      if (selfClose) continue;
      const end = text.indexOf(`</${m[2]}`, re.lastIndex);
      if (end < 0) continue;
      const body = decodeEntities(text.slice(re.lastIndex, end).replace(/<!\[CDATA\[([\s\S]*?)\]\]>/g, "$1"));
      re.lastIndex = text.indexOf(">", end) + 1 || text.length;
      for (const x of body.matchAll(ATTACHMENT)) cur.attachments.push(x[1].trim());
      continue;
    }
    if (tag === "failure" || tag === "error" || tag === "skipped") {
      const a = attrs(m[3]);
      let body = "";
      if (!selfClose) {
        const end = text.indexOf(`</${m[2]}`, re.lastIndex);
        if (end >= 0) {
          body = text.slice(re.lastIndex, end);
          re.lastIndex = text.indexOf(">", end) + 1 || text.length;
        }
      }
      const status = tag === "failure" ? "fail" : tag === "error" ? "error" : "skip";
      // A failure outranks a skip; the first failure/error wins.
      if (cur.status === "pass" || (cur.status === "skip" && status !== "skip")) {
        cur.status = status;
        cur.message = (a.message || bodyText(body).split("\n")[0] || a.type || "").slice(0, 500) || null;
      }
    }
  }
  if (cur) cases.push(cur);
  return cases;
}

function globToRe(glob) {
  return new RegExp("^" + glob.split("*").map((s) => s.replace(/[.+?^${}()|[\]\\]/g, "\\$&")).join("[^/]*") + "$");
}
function walkXml(dir, acc) {
  for (const e of readdirSync(dir, { withFileTypes: true })) {
    const p = path.join(dir, e.name);
    if (e.isDirectory()) { if (e.name !== "node_modules" && e.name !== ".git") walkXml(p, acc); }
    else if (/\.xml$/i.test(e.name)) acc.push(p);
  }
  return acc;
}

/** Expand files, directories and `dir/*.xml`-style globs (a `*` matches within one path segment). */
export function junitFiles(base, specs) {
  const out = [];
  for (const spec of specs) {
    const abs = path.resolve(base, spec);
    if (spec.includes("*")) {
      const dir = path.dirname(abs), re = globToRe(path.basename(abs));
      if (dir.includes("*")) throw new Error(`glob only in the file name: ${spec}`);
      if (existsSync(dir)) for (const f of readdirSync(dir)) if (re.test(f) && statSync(path.join(dir, f)).isFile()) out.push(path.join(dir, f));
      continue;
    }
    if (!existsSync(abs)) throw new Error(`no such JUnit file or directory: ${spec}`);
    if (statSync(abs).isDirectory()) walkXml(abs, out); else out.push(abs);
  }
  return [...new Set(out)].sort();
}

export function readJUnit(base, specs) {
  const files = junitFiles(base, specs).map((p) => {
    const cases = parseJUnit(readFileSync(p, "utf8"), p);
    return { path: p, mtimeMs: statSync(p).mtimeMs, cases };
  });
  return { files, cases: files.flatMap((f) => f.cases) };
}
