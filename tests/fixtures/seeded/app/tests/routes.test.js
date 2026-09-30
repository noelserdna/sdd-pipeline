import { test } from "node:test";
import assert from "node:assert/strict";
import { render, api } from "../src/routes.js";
import { appCon, cvDeLucia } from "./datos.js";

test("cada pantalla del alumno responde 200", () => {
  const app = appCon({ cvs: [cvDeLucia("publicado")] });
  for (const ruta of ["/cv", "/cv/estado", "/panel", "/cv/descargar"]) assert.equal(render(ruta, app).status, 200, ruta);
});

test("la revisión del staff responde 200 con el editor del resumen", () => {
  const res = render("/staff/cv/7", appCon({ usuario: { rol: "staff" }, cvs: [cvDeLucia("generado")] }));
  assert.equal(res.status, 200);
  assert.ok(res.body.includes('<textarea id="resumen" name="resumen">'));
});

test("un alumno no entra en la revisión del staff", () => {
  const res = render("/staff/cv/7", appCon({ cvs: [cvDeLucia("generado")] }));
  assert.equal(res.status, 403);
});

test("una ruta desconocida responde 404", async () => {
  assert.equal(render("/nada", appCon()).status, 404);
  assert.equal((await api("GET", "/api/nada", null, appCon())).status, 404);
});
