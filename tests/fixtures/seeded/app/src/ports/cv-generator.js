// Puerto CvGenerator: redacta el resumen profesional del CV de un alumno.
//
//   generate({ perfil, respuestas }) → Promise<{ resumen: string }>
//
//   perfil      { nombre, email, titulo, habilidades: string[], proyectos: [{ nombre, descripcion }] }
//   respuestas  [{ pregunta, respuesta }] del cuestionario del alumno
//
// Implementaciones: src/providers/mock-cv-generator.js (doble) y src/providers/vertex-cv-generator.js (Vertex AI).

/** Comprueba que un objeto implementa el puerto; devuelve el mismo objeto. */
export function asCvGenerator(impl) {
  if (!impl || typeof impl.generate !== "function") throw new TypeError("CvGenerator: falta generate()");
  return impl;
}
