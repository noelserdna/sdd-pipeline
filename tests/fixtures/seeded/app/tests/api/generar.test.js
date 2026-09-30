import { test } from "node:test";
import assert from "node:assert/strict";
import { api } from "../../src/routes.js";
import { appCon } from "../datos.js";

test("REQ-F-005 AC1 · el resumen generado recoge las respuestas del cuestionario", async () => {
  const app = appCon();
  const res = await api("POST", "/api/cv/generar", {}, app);
  assert.equal(res.status, 201);
  assert.equal(res.body.estado, "generado");
  // REQ-F-005 AC1: "GIVEN un alumno que respondió "Me motiva la ciberseguridad" a la pregunta "¿Qué te motiva?" WHEN genera su CV THEN el resumen del CV recoge "Me motiva la ciberseguridad""
  assert.equal(app.store.alumno(1).respuestas[0].pregunta, "¿Qué te motiva?");
  assert.ok(res.body.borrador.resumen.includes("Me motiva la ciberseguridad"));
});

test("generar de nuevo sustituye el borrador del mismo CV", async () => {
  const app = appCon();
  const primero = await api("POST", "/api/cv/generar", {}, app);
  const segundo = await api("POST", "/api/cv/generar", {}, app);
  assert.equal(segundo.body.id, primero.body.id);
});
