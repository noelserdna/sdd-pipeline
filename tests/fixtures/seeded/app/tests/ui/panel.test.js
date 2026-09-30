import { test } from "node:test";
import assert from "node:assert/strict";
import { render } from "../../src/routes.js";
import { appCon, cvDeLucia } from "../datos.js";

test("REQ-F-007 AC1 · el panel avisa de que el CV está publicado", () => {
  const res = render("/panel", appCon({ cvs: [cvDeLucia("publicado")] }));
  assert.equal(res.status, 200);
  // REQ-F-007 AC1: "GIVEN un CV publicado WHEN el alumno abre su panel THEN el usuario ve el aviso "Tu CV ya está publicado""
  assert.ok(res.body.includes('<li class="aviso">Tu CV ya está publicado</li>'));
});

test("el panel no muestra el aviso mientras el CV está en revisión", () => {
  const res = render("/panel", appCon({ cvs: [cvDeLucia("generado")] }));
  assert.ok(res.body.includes("No tienes avisos"));
});
