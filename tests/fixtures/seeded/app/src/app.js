// Composición de la aplicación: almacén, generador de CV según el entorno y usuario de la sesión.
import { createStore } from "./store.js";
import { createMockCvGenerator } from "./providers/mock-cv-generator.js";
import { createVertexCvGenerator } from "./providers/vertex-cv-generator.js";

/** CV_GENERATOR=mock usa el doble; cualquier otro valor (o ninguno) usa Vertex con VERTEX_ENDPOINT. */
export function generatorFromEnv(env = process.env) {
  if (env.CV_GENERATOR === "mock") return createMockCvGenerator();
  return createVertexCvGenerator({ endpoint: env.VERTEX_ENDPOINT });
}

export function createApp({ env = process.env, datos = {}, usuario = null, generator = generatorFromEnv(env) } = {}) {
  return { store: createStore(datos), generator, usuario };
}
