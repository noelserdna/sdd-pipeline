// Pantalla /staff/cv/:id: revisión del CV por el staff (editor del resumen y acciones).
import { esc, pagina } from "./html.js";

export function renderRevision({ alumno, cv }) {
  const resumen = cv.estado === "publicado" ? cv.publicado.resumen : cv.editado.resumen;
  const cuerpo = [
    `<h1>Revisión del CV de ${esc(alumno.perfil.nombre)}</h1>`,
    `<p class="estado">Estado: ${esc(cv.estado)}</p>`,
    `<form method="post" action="/api/cv/${cv.id}/editar" class="editor">`,
    `<label for="resumen">Resumen</label>`,
    `<textarea id="resumen" name="resumen">${esc(resumen)}</textarea>`,
    `<button type="submit">Guardar</button>`,
    `</form>`,
    `<form method="post" action="/api/cv/${cv.id}/confirmar"><button type="submit">Confirmar y publicar</button></form>`,
  ].join("");
  return pagina(`Revisión · ${alumno.perfil.nombre}`, `<main class="revision">${cuerpo}</main>`);
}
