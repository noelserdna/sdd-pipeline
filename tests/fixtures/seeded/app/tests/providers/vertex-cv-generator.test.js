import { test } from "node:test";
import assert from "node:assert/strict";
import { buildRequest, createVertexCvGenerator, MODEL, parseResponse } from "../../src/providers/vertex-cv-generator.js";
import { generatorFromEnv } from "../../src/app.js";
import { LUCIA } from "../datos.js";

test("la petición a Vertex lleva el modelo y el perfil del alumno", () => {
  const req = buildRequest({ perfil: LUCIA.perfil, respuestas: LUCIA.respuestas });
  assert.equal(req.model, MODEL);
  const prompt = req.contents[0].parts[0].text;
  assert.ok(prompt.includes("Lucía Pérez"));
  assert.ok(prompt.includes("Desarrolladora web"));
  assert.ok(prompt.includes("JavaScript, Node.js, SQL"));
  assert.ok(prompt.includes("Agenda P2P"));
});

test("el provider de Vertex devuelve el texto de la primera candidata como resumen", async () => {
  let enviada = null;
  const transport = async (request) => {
    enviada = request;
    return { candidates: [{ content: { parts: [{ text: "Soy desarrolladora web. " }, { text: "Me gusta el backend." }] } }] };
  };
  const gen = createVertexCvGenerator({ transport });
  const { resumen } = await gen.generate({ perfil: LUCIA.perfil, respuestas: LUCIA.respuestas });
  assert.equal(resumen, "Soy desarrolladora web. Me gusta el backend.");
  assert.equal(enviada.model, MODEL);
});

test("una respuesta sin candidatas da un resumen vacío", () => {
  assert.equal(parseResponse({}), "");
});

test("CV_GENERATOR=mock elige el doble y cualquier otro valor el provider de Vertex", async () => {
  const mock = generatorFromEnv({ CV_GENERATOR: "mock" });
  const { resumen } = await mock.generate({ perfil: LUCIA.perfil, respuestas: [] });
  assert.ok(resumen.startsWith("Lucía Pérez"));
  const vertex = generatorFromEnv({ CV_GENERATOR: "vertex" });
  await assert.rejects(vertex.generate({ perfil: LUCIA.perfil, respuestas: [] }), /VERTEX_ENDPOINT/);
});
