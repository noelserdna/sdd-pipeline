// Tests unitarios de graph-loader: degradación sin grafo y forma del grafo vacío.
// La carga real de un grafo se cubre en smoke.spec.ts (subproceso), porque loadGraph registra un fs.watchFile
// que mantendría vivo el proceso de tests.
import { test } from "node:test";
import assert from "node:assert/strict";
import { mkdtempSync } from "node:fs";
import os from "node:os";
import path from "node:path";
import { loadGraph, emptyGraph } from "../src/graph-loader.js";

test("loadGraph devuelve null cuando no hay dashboard/traceability-graph.json en ningún nivel", () => {
  const dir = mkdtempSync(path.join(os.tmpdir(), "sdd-gl-"));
  assert.equal(loadGraph(dir), null);
});

test("emptyGraph tiene la forma mínima del esquema v3", () => {
  const g = emptyGraph();
  assert.equal(g.$schema, "traceability-graph-v3");
  assert.deepEqual(g.artifacts, []);
  assert.deepEqual(g.relationships, []);
  assert.equal(g.statistics.totalArtifacts, 0);
  assert.ok(g.pipeline && Array.isArray(g.pipeline.stages));
});

test("sdd_coverage cuenta como inferido todo origin distinto de direct (grafo v6)", async () => {
  const { executeCoverage } = await import("../src/tools/coverage.js");
  const req = (id: string, origin?: string) => ({
    id, type: "REQ", category: null, title: id, file: "r.md", line: 1, priority: null, stage: "requirements",
    classification: null, testRefs: [], commitRefs: [],
    codeRefs: [{ file: "src/a.ts", line: 1, symbol: "a", symbolType: "function", refIds: [id], ...(origin ? { origin } : {}) }],
  });
  const artifacts = [req("REQ-F-001"), req("REQ-F-002", "blame-inferred"), req("REQ-F-003", "propagated"),
    req("REQ-F-004", "task-inferred"), req("REQ-F-005", "llm-verified")];
  const g = { ...emptyGraph(), artifacts } as unknown as import("../src/graph-loader.js").TraceabilityGraph;
  const index = {
    byId: new Map(artifacts.map((a) => [a.id, a])), byType: new Map([["REQ", artifacts]]), byFile: new Map(),
    relBySource: new Map(), relByTarget: new Map(), codeRefsByFile: new Map(),
  } as unknown as import("../src/graph-loader.js").GraphIndex;
  const raw = executeCoverage({}, g, index);
  const out = JSON.parse(raw.slice(0, raw.indexOf("\n") === -1 ? raw.length : raw.indexOf("\n")));
  const b = out.codeInferenceBreakdown;
  assert.equal(b.directRefs, 1);
  assert.equal(b.inferredTotal, 4);
  assert.equal(b.reqsWithDirectCode, 1);
  assert.equal(b.reqsWithInferredCodeOnly, 4);
  assert.equal(b.blameInferred + b.propagated + b.taskInferred + b.llmVerified, 4);
  assert.ok(!("hookCaptured" in b) && !("codeIndex" in b), "retired origins are not counted");
  assert.ok(!("codeIntelligence" in out), "no codeIntelligence block");
});

test("sdd://pipeline/status: una etapa skipped sale del denominador y nunca es la siguiente acción", async () => {
  const { readResource } = await import("../src/resources.js");
  const st = (name: string, status: string, extra = {}) => ({ name, status, lastRun: null, artifactCount: 0, ...extra });
  const g = {
    ...emptyGraph(),
    pipeline: {
      currentStage: "plan-architect",
      stages: [st("requirements-engineer", "done"), st("specifications-engineer", "skipped", { skipReason: "6 REQ-F" }),
        st("spec-auditor", "skipped"), st("test-planner", "skipped"), st("plan-architect", "pending"),
        st("task-generator", "pending"), st("task-implementer", "pending")],
    },
  } as unknown as import("../src/graph-loader.js").TraceabilityGraph;
  const out = JSON.parse(readResource("sdd://pipeline/status", g, {} as never).contents[0].text);
  assert.equal(out.progress, "1/4 stages complete, 3 skipped");
  assert.equal(out.nextAction, "Continue with /sdd-plan-architect");
  assert.deepEqual(out.skippedStages[0], { name: "specifications-engineer", reason: "6 REQ-F" });
});
