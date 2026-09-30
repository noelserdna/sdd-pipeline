// Router: qué pantalla monta cada ruta (render) y qué operación atiende cada endpoint (api).
// app = { store, generator, usuario }; usuario = { rol: "alumno", alumnoId } | { rol: "staff" }.
import { renderCv } from "./ui/cv.js";
import { renderEstado } from "./ui/estado.js";
import { renderPanel } from "./ui/panel.js";
import { renderRevision } from "./ui/revision.js";
import { descargarCv } from "./ui/descarga.js";
import { ApiError, generar, editar, confirmar } from "./api/cv.js";

const html = (body) => ({ status: 200, contentType: "text/html; charset=utf-8", body });
const noEncontrado = () => ({ status: 404, contentType: "text/plain; charset=utf-8", body: "No encontrado" });
const prohibido = () => ({ status: 403, contentType: "text/plain; charset=utf-8", body: "Prohibido" });

function datosAlumno(app) {
  const alumno = app.store.alumno(app.usuario?.alumnoId);
  return alumno ? { alumno, cv: app.store.cvDeAlumno(alumno.id) } : null;
}

const pantallasAlumno = {
  "/cv": (d) => html(renderCv(d)),
  "/cv/estado": (d) => html(renderEstado(d)),
  "/panel": (d) => html(renderPanel(d)),
  "/cv/descargar": (d) => {
    if (d.cv?.estado !== "publicado") return noEncontrado();
    const f = descargarCv(d);
    return { status: 200, contentType: f.contentType, filename: f.filename, body: f.body };
  },
};

/** La respuesta de una pantalla: { status, contentType, body, filename? }. */
export function render(ruta, app) {
  if (pantallasAlumno[ruta]) {
    if (app.usuario?.rol !== "alumno") return prohibido();
    const d = datosAlumno(app);
    return d ? pantallasAlumno[ruta](d) : noEncontrado();
  }
  const revision = ruta.match(/^\/staff\/cv\/(\d+)$/);
  if (revision) {
    if (app.usuario?.rol !== "staff") return prohibido();
    const cv = app.store.cv(Number(revision[1]));
    if (!cv) return noEncontrado();
    return html(renderRevision({ alumno: app.store.alumno(cv.alumnoId), cv }));
  }
  return noEncontrado();
}

/** Un endpoint JSON: { status, body }. */
export async function api(metodo, ruta, body, app) {
  try {
    if (metodo === "POST" && ruta === "/api/cv/generar") {
      const alumnoId = app.usuario?.rol === "alumno" ? app.usuario.alumnoId : body?.alumnoId;
      return { status: 201, body: await generar(app.store, app.generator, { alumnoId }) };
    }
    const m = ruta.match(/^\/api\/cv\/(\d+)\/(editar|confirmar)$/);
    if (metodo === "POST" && m) {
      if (app.usuario?.rol !== "staff") return { status: 403, body: { error: "solo staff" } };
      const id = Number(m[1]);
      const cv = m[2] === "editar" ? editar(app.store, id, body ?? {}) : confirmar(app.store, id);
      return { status: 200, body: cv };
    }
    return { status: 404, body: { error: "no encontrado" } };
  } catch (e) {
    if (e instanceof ApiError) return { status: e.status, body: { error: e.message } };
    throw e;
  }
}
