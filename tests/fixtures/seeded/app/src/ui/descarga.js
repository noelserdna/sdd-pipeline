// /cv/descargar: el CV publicado como fichero de texto plano.

export function slug(texto) {
  return String(texto)
    .normalize("NFD")
    .replace(/[̀-ͯ]/g, "")
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-+|-+$/g, "");
}

export function descargarCv({ alumno, cv }) {
  const { perfil } = alumno;
  const lineas = [perfil.nombre, perfil.email, perfil.titulo, ""];
  const resumen = cv?.publicado?.resumen;
  if (resumen) lineas.push("RESUMEN", resumen, "");
  if (perfil.habilidades?.length) lineas.push("HABILIDADES", perfil.habilidades.join(", "), "");
  if (perfil.proyectos?.length) {
    lineas.push("PROYECTOS");
    for (const p of perfil.proyectos) lineas.push(`- ${p.nombre}: ${p.descripcion}`);
  }
  return {
    filename: `cv-${slug(perfil.nombre)}.txt`,
    contentType: "text/plain; charset=utf-8",
    body: lineas.join("\n").trimEnd() + "\n",
  };
}
