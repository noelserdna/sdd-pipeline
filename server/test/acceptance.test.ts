// sdd_coverage y sdd_context leen .sdd/acceptance.json (sdd-acceptance-v1) cuando existe: el veredicto sale del
// libro de aceptación, no de si hay enlaces en el grafo. Sin libro, vuelven a la lógica de enlaces.
import { test } from "node:test";
import assert from "node:assert/strict";
import { mkdtempSync, mkdirSync, copyFileSync, writeFileSync } from "node:fs";
import os from "node:os";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { executeCoverage } from "../src/tools/coverage.js";
import { executeContext } from "../src/tools/context.js";
import { loadAcceptance, findAcceptanceFile } from "../src/acceptance.js";
import { getNextStepHint } from "../src/hints.js";
import type { GraphIndex } from "../src/graph-loader.js";
import { emptyGraph } from "../src/graph-loader.js";

const AQUI = path.dirname(fileURLToPath(import.meta.url));
const LEDGER = path.join(AQUI, "fixtures", "acceptance", "acceptance.json");

function proyecto(conLibro = true): string {
  const dir = mkdtempSync(path.join(os.tmpdir(), "sdd-acc-"));
  if (conLibro) {
    mkdirSync(path.join(dir, ".sdd"));
    copyFileSync(LEDGER, path.join(dir, ".sdd", "acceptance.json"));
  }
  mkdirSync(path.join(dir, "src", "api"), { recursive: true });
  return dir;
}

function indiceVacio(): GraphIndex {
  return { byId: new Map(), byType: new Map(), byFile: new Map(), relBySource: new Map(), relByTarget: new Map(), codeRefsByFile: new Map() };
}

/** Las tools devuelven JSON con una pista de markdown pegada detrás. */
function parsear(salida: string): any {
  const corte = salida.indexOf("\n\n---\n");
  return JSON.parse(corte === -1 ? salida : salida.slice(0, corte));
}

test("findAcceptanceFile sube desde un subdirectorio hasta .sdd/acceptance.json", () => {
  const dir = proyecto();
  assert.equal(findAcceptanceFile(path.join(dir, "src", "api")), path.join(dir, ".sdd", "acceptance.json"));
  assert.equal(loadAcceptance(path.join(dir, "src"))?.ledger.$schema, "sdd-acceptance-v1");
});

test("un fichero de otro esquema se ignora (no se inventan veredictos)", () => {
  const dir = proyecto(false);
  mkdirSync(path.join(dir, ".sdd"));
  writeFileSync(path.join(dir, ".sdd", "acceptance.json"), JSON.stringify({ $schema: "otra-cosa", requirements: [] }));
  assert.equal(loadAcceptance(dir), null);
});

test("sdd_coverage con libro: totales por veredicto y objetivo de los Must", () => {
  const dir = proyecto();
  const salida = executeCoverage({}, emptyGraph(), indiceVacio(), dir);
  const j = parsear(salida);
  assert.equal(j.source, "acceptance");
  assert.equal(j.evaluated_sha, "0123456789abcdef0123456789abcdef01234567");
  assert.deepEqual(j.byVerdict, { VERIFIED: 1, FAILING: 1, MISSING: 6, WAIVED: 0, DEPRECATED: 1 });
  assert.equal(j.totalReqs, 8, "los deprecados no cuentan como activos");
  assert.deepEqual(j.deprecated, ["REQ-F-004"]);
  assert.equal(j.must.total, 6);
  assert.equal(j.must.verified, 1);
  assert.equal(j.must.goal, false);
  const f1 = j.requirements.find((r: any) => r.id === "REQ-F-001");
  assert.equal(f1.verdict, "FAILING");
  assert.equal(f1.criteria, "1/2");
  assert.ok(j.open.some((r: any) => r.id === "REQ-C-001"), "los abiertos incluyen MISSING");
  assert.equal(j.byPriority.Must.total, 6);
  assert.ok(salida.includes("/sdd-acceptance --loop"), "la pista apunta a sdd-acceptance");
});

test("sdd_coverage con libro no infiere estado de los enlaces del grafo", () => {
  const dir = proyecto();
  // Un grafo que diría "Complete" para REQ-F-001 (UC, BDD, código y tests enlazados) no cambia el veredicto.
  const idx = indiceVacio();
  const req = { id: "REQ-F-001", type: "REQ", category: null, title: "x", file: "r.md", line: 1, priority: "Must", stage: "requirements",
    classification: { businessDomain: "Tasks", technicalLayer: "Backend", functionalCategory: "CRUD" },
    codeRefs: [{ file: "src/a.ts", line: 1, symbol: "a", symbolType: "function", refIds: ["REQ-F-001"] }],
    testRefs: [{ file: "t.ts", line: 1, testName: "t", framework: "vitest", refIds: ["REQ-F-001"] }], commitRefs: [] };
  idx.byId.set(req.id, req as any);
  idx.byType.set("REQ", [req as any]);
  const j = parsear(executeCoverage({ domain: "tasks" }, emptyGraph(), idx, dir));
  assert.equal(j.source, "acceptance");
  assert.equal(j.requirements.length, 1, "el filtro de dominio usa la clasificación del grafo");
  assert.equal(j.requirements[0].verdict, "FAILING");
});

test("sdd_coverage sin libro vuelve a la lógica de enlaces", () => {
  const dir = proyecto(false);
  const salida = executeCoverage({}, emptyGraph(), indiceVacio(), dir);
  const j = parsear(salida);
  assert.equal(j.source, "graph-links");
  assert.equal(j.totalReqs, 0);
  assert.ok(salida.includes("/sdd-acceptance --check"));
});

test("sdd_context de un requisito: veredicto y evidencia por criterio aunque no esté en el grafo", () => {
  const dir = proyecto();
  const j = parsear(executeContext({ artifact_id: "REQ-F-001" }, emptyGraph(), indiceVacio(), dir));
  assert.equal(j.coverageStatus, "FAILING");
  assert.equal(j.acceptance.criteria, "1/2");
  assert.equal(j.acceptance.perCriterion.length, 2);
  assert.equal(j.acceptance.perCriterion[1].state, "fail");
  assert.deepEqual(j.acceptance.perCriterion[0].scenarios, ["AC-001-01"]);
  assert.ok(j.gaps.some((g: string) => g.startsWith("FAILING_AC2")));

  const c1 = parsear(executeContext({ artifact_id: "REQ-C-001" }, emptyGraph(), indiceVacio(), dir));
  assert.equal(c1.coverageStatus, "MISSING");
  assert.ok(c1.gaps.some((g: string) => g.startsWith("MISSING_AC1")));

  const f5 = parsear(executeContext({ artifact_id: "REQ-F-005" }, emptyGraph(), indiceVacio(), dir));
  assert.ok(f5.gaps.some((g: string) => g.startsWith("NO_SCENARIO_AC2")), "criterio sin escenario");
});

test("sdd_context de un requisito que está en el grafo: enlaces del grafo, estado del libro", () => {
  const dir = proyecto();
  const idx = indiceVacio();
  const req = { id: "REQ-F-002", type: "REQ", category: null, title: "List", file: "r.md", line: 1, priority: "Must", stage: "requirements",
    classification: null, codeRefs: [], testRefs: [], commitRefs: [] };
  const uc = { ...req, id: "UC-002", type: "UC", title: "List UC" };
  idx.byId.set(req.id, req as any);
  idx.byId.set(uc.id, uc as any);
  idx.relByTarget.set("REQ-F-002", [{ source: "UC-002", target: "REQ-F-002", type: "implements", sourceFile: "spec/use-cases/UC-002.md", line: 3 }]);
  const j = parsear(executeContext({ artifact_id: "REQ-F-002" }, emptyGraph(), idx, dir));
  assert.equal(j.coverageStatus, "VERIFIED", "sin código ni tests en el grafo, el libro manda");
  assert.equal(j.downstream[0].id, "UC-002");
  assert.deepEqual(j.gaps, [], "un requisito VERIFIED no tiene huecos aunque el grafo no tenga enlaces de código");
});

test("sdd_context sin libro conserva la lógica de enlaces", () => {
  const dir = proyecto(false);
  const idx = indiceVacio();
  const req = { id: "REQ-F-002", type: "REQ", category: null, title: "List", file: "r.md", line: 1, priority: "Must", stage: "requirements",
    classification: null, codeRefs: [], testRefs: [], commitRefs: [] };
  idx.byId.set(req.id, req as any);
  const j = parsear(executeContext({ artifact_id: "REQ-F-002" }, emptyGraph(), idx, dir));
  assert.equal(j.coverageStatus, "Not Started");
  assert.equal(j.acceptance, undefined);
  assert.ok(j.gaps.includes("MISSING_TESTS: No test references found"));
});

test("evidencia visual: un criterio unshown sale como hueco UNSHOWN y el motivo acompaña al veredicto", () => {
  const dir = proyecto(false);
  mkdirSync(path.join(dir, ".sdd"));
  const shot = { path: "evidencias/FASE-1/AC-001-01.png", sha256: "sha256:ab", bytes: 3, kind: "image", present: true };
  const ledger = {
    $schema: "sdd-acceptance-v1", evaluated_sha: "abc", dirty: false, untracked_paths: [], generatedAt: "2026-09-30T00:00:00Z", scope: null,
    visual_evidence: "required", evidence_dir: "evidencias", videos: null,
    requirements: [{
      id: "REQ-F-001", type: "F", title: "Create", priority: "Must", needs: [], verification: "test", verdict: "MISSING",
      reason: "no visual evidence", criteria_total: 2, criteria_passing: 1, waiver: null, stale_evidence: false,
      criteria: [
        { n: 1, text: "a", scenarios: ["AC-001-01"], state: "pass", visual: "shown", evidence: [{ kind: "test", status: "pass", fresh: true, attachments: [shot] }] },
        { n: 2, text: "b", scenarios: ["AC-001-02"], state: "unshown", visual: "missing", evidence: [{ kind: "test", status: "pass", fresh: true, attachments: [] }] },
      ],
    }],
    summary: { active: 1, deprecated: 0, by_verdict: { VERIFIED: 0, FAILING: 0, MISSING: 1, WAIVED: 0, DEPRECATED: 0 }, by_priority: {},
      must_total: 1, must_verified: 0, must_waived: 0, goal: false, waived_musts: [], stale_evidence: 0, unshown: 1, missing_videos: [] },
  };
  writeFileSync(path.join(dir, ".sdd", "acceptance.json"), JSON.stringify(ledger));
  const ctx = parsear(executeContext({ artifact_id: "REQ-F-001" }, emptyGraph(), indiceVacio(), dir));
  assert.equal(ctx.acceptance.reason, "no visual evidence");
  assert.equal(ctx.acceptance.perCriterion[1].visual, "missing");
  assert.ok(ctx.gaps.some((g: string) => g.startsWith("UNSHOWN_AC2")), "el criterio sin captura es un hueco");
  assert.ok(!ctx.gaps.some((g: string) => g.includes("AC1")), "el criterio con captura no lo es");
  const cov = parsear(executeCoverage({}, emptyGraph(), indiceVacio(), dir));
  assert.equal(cov.open[0].reason, "no visual evidence");
});

test("la pista de sdd_trace apunta a sdd-acceptance, no a traceability-check", () => {
  const h = getNextStepHint("sdd_trace");
  assert.ok(h.includes("/sdd-acceptance"));
  assert.ok(!h.includes("traceability-check"));
});
