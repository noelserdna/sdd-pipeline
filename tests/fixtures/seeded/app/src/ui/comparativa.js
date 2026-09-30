// Componente de la revisión del staff: el resumen generado frente al resumen editado.
import { esc } from "./html.js";

export function renderComparativa({ antes, despues }) {
  return [
    `<section class="comparativa">`,
    `<h2>Cambios en el resumen</h2>`,
    `<div class="comparativa-antes"><span>Antes: ${esc(antes)}</span></div>`,
    `<div class="comparativa-despues"><span>Después: ${esc(despues)}</span></div>`,
    `</section>`,
  ].join("");
}
