import { test } from "node:test";
import assert from "node:assert/strict";
import { render } from "../../src/routes.js";
import { appCon, cvDeLucia } from "../datos.js";

test("REQ-F-008 AC1 · la descarga se llama como la alumna", () => {
  const res = render("/cv/descargar", appCon({ cvs: [cvDeLucia("publicado")] }));
  assert.equal(res.status, 200);
  // REQ-F-008 AC1: "GIVEN la alumna "Lucía Pérez" con el CV publicado WHEN descarga su CV THEN recibe un fichero llamado "cv-lucia-perez.txt""
  assert.equal(res.filename, "cv-lucia-perez.txt");
  assert.match(res.contentType, /^text\/plain/);
});

test("REQ-F-008 AC2 · el fichero descargado empieza por el nombre de la alumna", () => {
  const res = render("/cv/descargar", appCon({ cvs: [cvDeLucia("publicado")] }));
  // REQ-F-008 AC2: "GIVEN la alumna "Lucía Pérez" con el CV publicado WHEN descarga su CV THEN la primera línea del fichero es "Lucía Pérez""
  assert.equal(res.body.split("\n")[0], "Lucía Pérez");
});

test("no hay descarga mientras el CV no está publicado", () => {
  const res = render("/cv/descargar", appCon({ cvs: [cvDeLucia("generado")] }));
  assert.equal(res.status, 404);
});
