// Tests unitarios de graph-loader: degradación sin grafo y forma del grafo vacío.
// La carga real de un grafo se cubre en smoke.test.ts (subproceso), porque loadGraph registra un fs.watchFile
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
