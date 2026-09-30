// Pantalla /cv: el CV del alumno (cabecera, resumen, habilidades y proyectos).
import { esc, pagina } from "./html.js";

function seccionProyectos(proyectos) {
  if (!proyectos?.length) return "";
  const items = proyectos.map((p) => `<li><strong>${esc(p.nombre)}</strong> — ${esc(p.descripcion)}</li>`).join("");
  return `<section class="cv-proyectos"><h2>Proyectos</h2><ul>${items}</ul></section>`;
}

export function renderCv({ alumno, cv }) {
  const { perfil } = alumno;
  const resumen = cv?.publicado?.resumen ?? cv?.editado?.resumen ?? "";
  const cuerpo = [
    `<header class="cv-cabecera"><h1>${esc(perfil.nombre)}</h1><p class="cv-email">${esc(perfil.email)}</p><p>${esc(perfil.titulo)}</p></header>`,
    resumen ? `<section class="cv-resumen"><h2>Resumen</h2><p>${esc(resumen)}</p></section>` : "",
    perfil.habilidades?.length ? `<section class="cv-habilidades"><h2>Habilidades</h2><p>${esc(perfil.habilidades.join(" · "))}</p></section>` : "",
    seccionProyectos(perfil.proyectos),
    `<a class="boton" href="/cv/descargar">Descargar</a>`,
  ].join("");
  return pagina(`CV de ${perfil.nombre}`, `<main class="cv">${cuerpo}</main>`);
}
