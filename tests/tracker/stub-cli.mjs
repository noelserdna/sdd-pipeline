// stub-cli.mjs — fake `gh` / `glab` for tests/tracker/run.sh. Usage: node stub-cli.mjs <gh|glab> ARGS…
// Logs argv to $STUB_LOG (one line per call) and serves a tiny stateful issue tracker from $STUB_STATE (JSON).
// $STUB_AUTH_FAIL=1 → `auth status` fails. $STUB_GLAB_HOST → `glab config get host`. No network.
import { readFileSync, writeFileSync, appendFileSync, existsSync } from "node:fs";

const [bin, ...args] = process.argv.slice(2);
if (process.env.STUB_LOG) appendFileSync(process.env.STUB_LOG, `${bin} ${args.join(" ")}\n`);
const stateFile = process.env.STUB_STATE;
const load = () => (stateFile && existsSync(stateFile) ? JSON.parse(readFileSync(stateFile, "utf8")) : {});
const save = (s) => writeFileSync(stateFile, JSON.stringify(s, null, 2));
const done = (obj, code = 0) => { if (obj !== undefined) process.stdout.write(JSON.stringify(obj)); process.exit(code); };

if (args[0] === "auth" && args[1] === "status") {
  if (process.env.STUB_AUTH_FAIL === "1") { process.stderr.write("You are not logged into any hosts\n"); process.exit(1); }
  process.stderr.write("Logged in\n"); process.exit(0);
}
if (bin === "glab" && args[0] === "config" && args[1] === "get") {
  if (process.env.STUB_GLAB_HOST) { process.stdout.write(process.env.STUB_GLAB_HOST + "\n"); process.exit(0); }
  process.exit(1);
}
if (args[0] !== "api") { process.stderr.write(`stub: unsupported ${bin} ${args.join(" ")}\n`); process.exit(9); }

let method = "GET", endpoint = null, input = false;
for (let i = 1; i < args.length; i++) {
  const a = args[i];
  if (a === "-X" || a === "--method") method = args[++i];
  else if (a === "-H" || a === "--hostname") i++;
  else if (a === "--input") { input = true; i++; }
  else if (!a.startsWith("-")) endpoint = a;
}
const body = input ? JSON.parse(readFileSync(0, "utf8") || "{}") : null;
const [p, qs = ""] = endpoint.split("?");
const q = Object.fromEntries(new URLSearchParams(qs));
const s = load();
const T = (s[bin] ||= { issues: [], comments: {}, pulls: [], next: 1 });
const gh = bin === "gh";
const parts = p.split("/");
// gh: repos/O/R/<rest…> · glab: projects/<ENC>/<rest…>
const rest = gh ? parts.slice(3) : parts.slice(2);
const view = (i) => (gh
  ? { number: i.n, title: i.title, body: i.body, labels: i.labels.map((name) => ({ name })), state: i.state, html_url: `https://github.com/x/${i.n}`, ...(i.pr ? { pull_request: {} } : {}) }
  : { iid: i.n, title: i.title, description: i.body, labels: i.labels, state: i.state === "open" ? "opened" : "closed", web_url: `https://gitlab.example.com/x/-/issues/${i.n}` });
const find = (n) => T.issues.find((i) => i.n === Number(n));

if (rest[0] === "issues" && rest.length === 1) {
  if (method === "GET") {
    const list = T.issues.filter((i) => !q.labels || i.labels.includes(q.labels));
    const per = Number(q.per_page || 30), page = Number(q.page || 1);
    done(list.slice((page - 1) * per, page * per).map(view));
  }
  if (method === "POST") {
    const labels = gh ? body.labels : String(body.labels || "").split(",").filter(Boolean);
    const i = { n: T.next++, title: body.title, body: gh ? body.body : body.description, labels, state: "open" };
    T.issues.push(i); save(s); done(view(i));
  }
}
if (rest[0] === "issues" && rest.length === 2) {
  const i = find(rest[1]);
  if (!i) { process.stderr.write("HTTP 404\n"); process.exit(1); }
  if (method === "GET") done(view(i));
  if (method === "PATCH" || method === "PUT") {
    if (gh && body.body !== undefined) i.body = body.body;
    if (!gh && body.description !== undefined) i.body = body.description;
    if (body.state === "closed" || body.state_event === "close") i.state = "closed";
    save(s); done(view(i));
  }
}
if (rest[0] === "issues" && rest.length === 3 && ["comments", "notes"].includes(rest[2])) {
  const list = (T.comments[rest[1]] ||= []);
  if (method === "GET") done(list.map((c) => (gh ? { user: { login: "ana" }, body: c, created_at: "2026-09-27T00:00:00Z" } : { author: { username: "ana" }, body: c, created_at: "2026-09-27T00:00:00Z", system: false })));
  if (method === "POST") { list.push(body.body); save(s); done({ id: list.length }); }
}
if (rest[0] === "pulls" || rest[0] === "merge_requests") {
  const branch = gh ? String(q.head || "").split(":").pop() : q.source_branch;
  done(T.pulls.filter((x) => x.branch === branch).map((x) => (gh ? { number: x.n, state: "open", html_url: "u" } : { iid: x.n, state: "opened", web_url: "u" })));
}
process.stderr.write(`stub: unsupported ${method} ${endpoint}\n`);
process.exit(9);
