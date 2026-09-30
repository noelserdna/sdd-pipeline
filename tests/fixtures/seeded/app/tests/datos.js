// Datos de prueba compartidos por los tests.
import { createApp } from "../src/app.js";
import { createMockCvGenerator } from "../src/providers/mock-cv-generator.js";

export const LUCIA = {
  id: 1,
  perfil: {
    nombre: "Lucía Pérez",
    email: "lucia@campus.test",
    titulo: "Desarrolladora web",
    habilidades: ["JavaScript", "Node.js", "SQL"],
    proyectos: [{ nombre: "Agenda P2P", descripcion: "agenda compartida sin servidor central" }],
  },
  respuestas: [{ pregunta: "¿Qué te motiva?", respuesta: "Me motiva la ciberseguridad" }],
};

export const DIEGO = {
  id: 2,
  perfil: { nombre: "Diego Ramos", email: "diego@campus.test", titulo: "Desarrollador junior", habilidades: [], proyectos: [] },
  respuestas: [],
};

/** Una app con Lucía y Diego, el generador doble y el usuario indicado. */
export function appCon({ usuario = { rol: "alumno", alumnoId: LUCIA.id }, cvs = [] } = {}) {
  return createApp({ datos: { alumnos: [LUCIA, DIEGO], cvs }, usuario, generator: createMockCvGenerator() });
}

/** Un CV de Lucía en el estado indicado. */
export function cvDeLucia(estado = "generado", resumen = "Lucía Pérez, Desarrolladora web.") {
  return {
    id: 7,
    alumnoId: LUCIA.id,
    estado,
    borrador: { resumen },
    editado: { resumen },
    publicado: estado === "publicado" ? { resumen } : null,
  };
}
