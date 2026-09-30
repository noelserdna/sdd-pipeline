// Operaciones de escritura sobre los CVs: generar (alumno), editar y confirmar (staff).

export class ApiError extends Error {
  constructor(status, message) {
    super(message);
    this.status = status;
  }
}

function cvOr404(store, id) {
  const cv = store.cv(id);
  if (!cv) throw new ApiError(404, `cv ${id} no existe`);
  return cv;
}

/** Redacta el borrador del CV del alumno con el generador y lo deja en estado `generado`. */
export async function generar(store, generator, { alumnoId }) {
  const alumno = store.alumno(alumnoId);
  if (!alumno) throw new ApiError(404, `alumno ${alumnoId} no existe`);
  const { resumen } = await generator.generate({ perfil: alumno.perfil, respuestas: alumno.respuestas ?? [] });
  const previo = store.cvDeAlumno(alumnoId);
  const borrador = { resumen };
  return store.guardarCv({
    ...(previo ? { id: previo.id } : {}),
    alumnoId,
    estado: "generado",
    borrador,
    editado: { ...borrador },
    publicado: null,
  });
}

/** El staff corrige el CV. Antes de publicarlo trabaja sobre la versión del editor; una vez publicado, retoca
 *  directamente la versión publicada. */
export function editar(store, id, cambios) {
  const cv = cvOr404(store, id);
  if (cv.estado === "publicado") return store.guardarCv({ ...cv, publicado: { ...cv.publicado, ...cambios } });
  return store.guardarCv({ ...cv, editado: { ...cv.editado, ...cambios } });
}

/** Publica la versión del editor. */
export function confirmar(store, id) {
  const cv = cvOr404(store, id);
  return store.guardarCv({ ...cv, estado: "publicado", publicado: { ...cv.editado }, confirmadoEn: new Date().toISOString() });
}
