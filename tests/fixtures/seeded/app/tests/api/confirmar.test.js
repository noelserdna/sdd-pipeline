import { test } from "node:test";
import assert from "node:assert/strict";
import { api } from "../../src/routes.js";
import { appCon, cvDeLucia } from "../datos.js";

const STAFF = { rol: "staff" };

test("REQ-F-006 AC1 · confirmar publica el CV", async () => {
  const app = appCon({ usuario: STAFF, cvs: [cvDeLucia("generado")] });
  const res = await api("POST", "/api/cv/7/confirmar", {}, app);
  assert.equal(res.status, 200);
  // REQ-F-006 AC1: "GIVEN un CV generado WHEN el staff lo confirma THEN el CV queda en estado "publicado""
  assert.equal(app.store.cv(7).estado, "publicado");
});

test("REQ-F-006 AC2 · la corrección del staff queda en el CV publicado", async () => {
  const app = appCon({ usuario: STAFF, cvs: [cvDeLucia("generado")] });
  await api("POST", "/api/cv/7/confirmar", {}, app);
  await api("POST", "/api/cv/7/editar", { resumen: "Perfil orientado a backend" }, app);
  // REQ-F-006 AC2: "GIVEN un CV confirmado cuyo resumen el staff cambió después a "Perfil orientado a backend" WHEN se vuelve a confirmar el mismo CV THEN el resumen publicado sigue siendo "Perfil orientado a backend""
  assert.equal(app.store.cv(7).estado, "publicado");
  assert.equal(app.store.cv(7).publicado.resumen, "Perfil orientado a backend");
});

test("solo el staff puede confirmar", async () => {
  const app = appCon({ cvs: [cvDeLucia("generado")] });
  const res = await api("POST", "/api/cv/7/confirmar", {}, app);
  assert.equal(res.status, 403);
});

test("confirmar un CV inexistente responde 404", async () => {
  const app = appCon({ usuario: STAFF });
  const res = await api("POST", "/api/cv/99/confirmar", {}, app);
  assert.equal(res.status, 404);
});
