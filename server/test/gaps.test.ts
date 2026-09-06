// El lector de gaps entiende las dos formas que existen, y dice algo util ante una tercera.
import { test } from "node:test";
import assert from "node:assert/strict";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { executeGaps } from "../src/tools/gaps.js";

const AQUI = path.dirname(fileURLToPath(import.meta.url));
const fixture = (nombre: string) => path.join(AQUI, "fixtures", "gaps", nombre);

/** `executeGaps` devuelve JSON con una pista de markdown pegada detras. */
function parsear(salida: string): any {
  const corte = salida.indexOf("\n\n---\n");
  return JSON.parse(corte === -1 ? salida : salida.slice(0, corte));
}

// ---------------------------------------------------------------------------
// La forma que escribe la skill (sdd-gap-analysis-v1)
// ---------------------------------------------------------------------------

test("v1: las tres rutas responden en vez de reventar", () => {
  // Antes de este arreglo, `data.findings` era undefined con esta forma y las
  // tres llamadas lanzaban TypeError: la del filtro, la de detail y la de
  // summary. No era solo el filtro.
  for (const args of [
    { category: "all" as const, format: "summary" as const },
    { category: "all" as const, format: "detail" as const },
    { category: "missing" as const, format: "detail" as const },
  ]) {
    const salida = parsear(executeGaps(args, fixture("v1")));
    assert.equal(salida.error, undefined, `no debe fallar con ${JSON.stringify(args)}`);
  }
});

test("v1: traduce endpoints y escenarios BDD a hallazgos", () => {
  const salida = parsear(executeGaps({ category: "all", format: "detail" }, fixture("v1")));
  const ids = salida.findings.map((f: any) => f.id);

  assert.ok(ids.includes("API-012"), "endpoint especificado y no implementado");
  assert.ok(ids.includes("API-003"), "mismatch");
  assert.ok(ids.includes("BDD-020"), "escenario BDD sin fichero de prueba");
  assert.equal(salida.findings.length, 6); // 1 missing + 2 orphan + 1 mismatch + 2 bdd
});

test("v1: el identificador de un huerfano sale de metodo y ruta, no del indice", () => {
  // Del indice del array cambiaria entre ejecuciones en cuanto se anadiera o
  // quitara una ruta, y un identificador que se mueve solo no sirve para
  // seguirle la pista a un hallazgo.
  const salida = parsear(executeGaps({ category: "orphan", format: "detail" }, fixture("v1")));
  const ids = salida.findings.map((f: any) => f.id).sort();
  assert.deepEqual(ids, ["ORPHAN-GET-/api/legacy", "ORPHAN-GET-/api/otra"]);

  // Y es estable: la misma entrada da el mismo identificador.
  const otraVez = parsear(executeGaps({ category: "orphan", format: "detail" }, fixture("v1")));
  assert.deepEqual(otraVez.findings.map((f: any) => f.id).sort(), ids);
});

test("v1: un escenario BDD no se hace pasar por un endpoint", () => {
  // Comparten la categoria "missing" porque las dos cosas faltan, pero no son lo
  // mismo: uno es una ruta sin implementar y el otro una prueba sin escribir.
  // Esconder la diferencia haria que "faltan 3 endpoints" fuera mentira.
  const salida = parsear(executeGaps({ category: "missing", format: "detail" }, fixture("v1")));
  const bdd = salida.findings.find((f: any) => f.id === "BDD-020");
  assert.ok(/escenario BDD/i.test(bdd.description), "la descripcion lo dice");
  assert.equal(bdd.artifact, null, "no tiene fichero de especificacion de endpoint");

  assert.deepEqual(salida.desglose, { endpoints: 1, escenariosBdd: 2 });
});

test("v1: las estadisticas de origen se conservan aparte", () => {
  const salida = parsear(executeGaps({ category: "all", format: "summary" }, fixture("v1")));
  assert.equal(salida.estadisticasOrigen.endpointCoveragePercent, 90);
  assert.equal(salida.estadisticasOrigen.bddCoveragePercent, 84);
  assert.equal(salida.projectFramework, "express");
});

// ---------------------------------------------------------------------------
// La forma canonica, que ya funcionaba y tiene que seguir funcionando
// ---------------------------------------------------------------------------

test("findings: la forma canonica sigue leyendose igual", () => {
  const salida = parsear(executeGaps({ category: "all", format: "detail" }, fixture("findings")));
  assert.equal(salida.projectName, "proyecto-canonico");
  assert.equal(salida.totalFindings, 3);
  assert.deepEqual(salida.summary, { total: 3, missing: 1, orphan: 1, mismatch: 1 });
});

test("findings: el filtro por categoria funciona", () => {
  const salida = parsear(executeGaps({ category: "mismatch", format: "detail" }, fixture("findings")));
  assert.equal(salida.findings.length, 1);
  assert.equal(salida.findings[0].id, "G-003");
});

// ---------------------------------------------------------------------------
// Una tercera forma
// ---------------------------------------------------------------------------

test("desconocida: falla con un mensaje que NOMBRA lo que encontro", () => {
  // Un "no se pudo leer" obliga a abrir el fichero para saber por que. Nombrar
  // las claves halladas convierte el error en un diagnostico.
  const salida = parsear(executeGaps({ category: "all", format: "summary" }, fixture("desconocida")));
  assert.equal(salida.error, true);
  assert.ok(salida.message.includes("resultados"), "nombra las claves que hay");
  assert.ok(salida.message.includes("totales"));
  assert.ok(salida.clavesEncontradas.includes("version"));
});

test("sin fichero: sigue diciendo que hay que correr el detector", () => {
  const salida = parsear(executeGaps({ category: "all" }, path.join(AQUI, "fixtures")));
  assert.equal(salida.error, true);
  assert.match(salida.message, /sdd-gap-detector/);
});
