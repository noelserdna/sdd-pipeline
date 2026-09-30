// Provider de CvGenerator sobre Vertex AI (Gemini). Construye la petición generateContent y la envía con un
// transporte inyectable; por defecto, un POST JSON a VERTEX_ENDPOINT.
import { asCvGenerator } from "../ports/cv-generator.js";

export const MODEL = "gemini-1.5-pro";

/** El prompt del resumen profesional. */
export function buildPrompt({ perfil }) {
  const lineas = [
    "Eres un orientador profesional. Redacta en español un resumen profesional de tres frases, en primera persona,",
    "para el CV de este alumno. No inventes experiencia que no aparezca en los datos.",
    "",
    `Nombre: ${perfil.nombre}`,
    `Perfil: ${perfil.titulo}`,
    `Habilidades: ${(perfil.habilidades ?? []).join(", ") || "—"}`,
    "Proyectos:",
    ...(perfil.proyectos ?? []).map((p) => `- ${p.nombre}: ${p.descripcion}`),
  ];
  return lineas.join("\n");
}

/** La petición generateContent de Vertex para un alumno. */
export function buildRequest(input) {
  return {
    model: MODEL,
    contents: [{ role: "user", parts: [{ text: buildPrompt(input) }] }],
    generationConfig: { temperature: 0.4, maxOutputTokens: 400 },
  };
}

function httpTransport(endpoint) {
  return async (request) => {
    if (!endpoint) throw new Error("VERTEX_ENDPOINT no está configurado");
    const res = await fetch(endpoint, { method: "POST", headers: { "content-type": "application/json" }, body: JSON.stringify(request) });
    if (!res.ok) throw new Error(`Vertex respondió ${res.status}`);
    return res.json();
  };
}

/** El texto de la primera candidata de una respuesta generateContent. */
export function parseResponse(body) {
  const parts = body?.candidates?.[0]?.content?.parts ?? [];
  return parts.map((p) => p.text ?? "").join("").trim();
}

export function createVertexCvGenerator({ endpoint, transport = httpTransport(endpoint) } = {}) {
  return asCvGenerator({
    async generate(input) {
      const body = await transport(buildRequest(input));
      return { resumen: parseResponse(body) };
    },
  });
}
