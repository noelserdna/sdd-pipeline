// Almacén en memoria de alumnos y CVs. Cada CV guarda el borrador que redactó el generador, la versión que el staff
// tiene en el editor y la versión publicada.

export function createStore({ alumnos = [], cvs = [] } = {}) {
  const alumnosById = new Map(alumnos.map((a) => [a.id, structuredClone(a)]));
  const cvsById = new Map(cvs.map((c) => [c.id, structuredClone(c)]));
  let nextId = cvs.reduce((m, c) => Math.max(m, c.id), 0) + 1;

  return {
    alumno(id) {
      return alumnosById.get(id) ?? null;
    },
    cv(id) {
      return cvsById.get(id) ?? null;
    },
    cvDeAlumno(alumnoId) {
      return [...cvsById.values()].find((c) => c.alumnoId === alumnoId) ?? null;
    },
    guardarCv(cv) {
      const id = cv.id ?? nextId++;
      const guardado = { ...cv, id };
      cvsById.set(id, guardado);
      return guardado;
    },
  };
}
