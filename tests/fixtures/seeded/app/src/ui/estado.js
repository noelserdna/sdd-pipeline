// Pantalla /cv/estado: en qué punto está el CV del alumno.
import { esc, pagina } from "./html.js";

const TEXTOS = {
  ninguno: "Todavía no has generado tu CV",
  generado: "En revisión",
  publicado: "Publicado",
};

export function renderEstado({ cv }) {
  const clave = cv?.estado ?? "ninguno";
  const texto = TEXTOS[clave] ?? TEXTOS.ninguno;
  return pagina("Estado de tu CV", `<main class="estado"><h1>Tu CV</h1><p class="estado-${esc(clave)}">${esc(texto)}</p></main>`);
}
