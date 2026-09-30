// Pantalla /panel: el panel del alumno con sus avisos.
import { esc, pagina } from "./html.js";

export function avisos({ cv }) {
  const lista = [];
  if (cv?.estado === "publicado") lista.push("Tu CV ya está publicado");
  return lista;
}

export function renderPanel({ alumno, cv }) {
  const items = avisos({ cv }).map((a) => `<li class="aviso">${esc(a)}</li>`).join("");
  const bloqueAvisos = items ? `<ul class="avisos">${items}</ul>` : `<p class="sin-avisos">No tienes avisos</p>`;
  return pagina("Panel", `<main class="panel"><h1>Hola, ${esc(alumno.perfil.nombre)}</h1>${bloqueAvisos}<a href="/cv">Mi CV</a></main>`);
}
