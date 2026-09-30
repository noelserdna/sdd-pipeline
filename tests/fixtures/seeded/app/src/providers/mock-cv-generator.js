// Doble de CvGenerator para desarrollo y tests: redacta un resumen determinista sin llamar a ningún servicio.
import { asCvGenerator } from "../ports/cv-generator.js";

export function createMockCvGenerator() {
  return asCvGenerator({
    async generate({ perfil, respuestas = [] }) {
      const partes = [`${perfil.nombre}, ${perfil.titulo}.`];
      if (perfil.habilidades?.length) partes.push(`Trabaja con ${perfil.habilidades.join(", ")}.`);
      for (const r of respuestas) partes.push(`${r.respuesta}.`);
      return { resumen: partes.join(" ") };
    },
  });
}
