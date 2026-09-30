import { test } from "node:test";
import assert from "node:assert/strict";
import { render } from "../../src/routes.js";
import { appCon, cvDeLucia } from "../datos.js";

test("REQ-F-001 AC1 · la cabecera del CV muestra el nombre y el email de la alumna", () => {
  const res = render("/cv", appCon({ cvs: [cvDeLucia("publicado")] }));
  assert.equal(res.status, 200);
  const cabecera = res.body.match(/<header class="cv-cabecera">(.*?)<\/header>/)[1];
  // REQ-F-001 AC1: "GIVEN la alumna "Lucía Pérez" con email "lucia@campus.test" WHEN abre su CV THEN el usuario ve "Lucía Pérez" y "lucia@campus.test" en la cabecera"
  assert.ok(cabecera.includes("Lucía Pérez"));
  assert.ok(cabecera.includes("lucia@campus.test"));
});

test("REQ-F-002 AC1 · el CV lista los proyectos del alumno en su sección", () => {
  const res = render("/cv", appCon({ cvs: [cvDeLucia("publicado")] }));
  assert.equal(res.status, 200);
  const seccion = res.body.match(/<section class="cv-proyectos">(.*?)<\/section>/)[1];
  // REQ-F-002 AC1: "GIVEN un alumno con el proyecto "Agenda P2P" WHEN abre su CV THEN el usuario ve una sección titulada "Proyectos personales" que contiene "Agenda P2P""
  assert.ok(seccion.includes("<h2>Proyectos</h2>"));
  assert.ok(seccion.includes("Agenda P2P"));
});
