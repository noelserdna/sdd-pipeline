import { test } from "node:test";
import assert from "node:assert/strict";
import { render } from "../../src/routes.js";
import { appCon, cvDeLucia } from "../datos.js";

test("REQ-F-003 AC1 · el alumno ve que su CV sin confirmar está en revisión", () => {
  const res = render("/cv/estado", appCon({ cvs: [cvDeLucia("generado")] }));
  assert.equal(res.status, 200);
  // REQ-F-003 AC1: "GIVEN un CV generado que el staff aún no ha confirmado WHEN el alumno abre el estado de su CV THEN el usuario ve "En revisión""
  assert.ok(res.body.includes("En revisión"));
});

test("el estado de un alumno sin CV invita a generarlo", () => {
  const res = render("/cv/estado", appCon());
  assert.ok(res.body.includes("Todavía no has generado tu CV"));
});
