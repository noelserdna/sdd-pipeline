import { test } from "node:test";
import assert from "node:assert/strict";
import { renderComparativa } from "../../src/ui/comparativa.js";

test("REQ-F-004 AC1 · la revisión muestra el resumen de antes y el de después", () => {
  const html = renderComparativa({ antes: "Desarrollador junior", despues: "Desarrolladora full-stack junior" });
  // REQ-F-004 AC1: "GIVEN el CV 7 con resumen generado "Desarrollador junior" y resumen editado "Desarrolladora full-stack junior" WHEN el staff abre la revisión del CV 7 THEN el usuario ve "Antes: Desarrollador junior" y "Después: Desarrolladora full-stack junior""
  assert.ok(html.includes("Antes: Desarrollador junior"));
  assert.ok(html.includes("Después: Desarrolladora full-stack junior"));
});

test("la comparativa escapa el texto del resumen", () => {
  const html = renderComparativa({ antes: "<b>x</b>", despues: "a & b" });
  assert.ok(html.includes("Antes: &lt;b&gt;x&lt;/b&gt;"));
  assert.ok(html.includes("Después: a &amp; b"));
});
