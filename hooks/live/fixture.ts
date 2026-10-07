export const DATA = {
 "project": {
  "name": "Citas del Taller Ruiz",
  "lang": "es",
  "repo": {
   "provider": "github",
   "web": "https://github.com/taller-ruiz/citas"
  }
 },
 "where": {
  "phase": "build",
  "phases": [
   {
    "id": "understand",
    "state": "done"
   },
   {
    "id": "agree",
    "state": "done"
   },
   {
    "id": "design",
    "state": "skipped",
    "reason": "La aplicación es pequeña y los requisitos ya traen ejemplos claros, así que pasamos directamente a planificar las entregas. Lo confirmó Lucía Gómez el 4 de septiembre."
   },
   {
    "id": "plan",
    "state": "done"
   },
   {
    "id": "build",
    "state": "current"
   },
   {
    "id": "verify",
    "state": "pending"
   },
   {
    "id": "deliver",
    "state": "pending"
   }
  ],
  "fase": {
   "n": 2,
   "of": 3,
   "title": "Ver las citas del día siguiente"
  },
  "now": "Estamos terminando la pantalla con las citas de mañana y arreglando la cancelación de citas, que un revisor encontró que no libera la hora.",
  "next": "Cuando esté lista, te enseñaremos la entrega 2 en el taller para que la pruebes con tu propio móvil.",
  "needFromYou": [
   {
    "text": "Decide si una cita cancelada con menos de 24 horas de antelación pierde la señal o se devuelve.",
    "anchor": "REQ-F-004"
   },
   {
    "text": "Lee la explicación de la nueva función de bonos de revisión y dinos si es lo que querías.",
    "anchor": "REQ-F-005"
   },
   {
    "text": "Mándanos una foto del cartel de horarios del taller para comprobar las horas de los sábados.",
    "anchor": "REQ-F-002"
   }
  ]
 },
 "technical": {
  "gate": {
   "code": 1,
   "label": "FASE-2: 2 requisitos sin verificar (REQ-F-003 weakened, REQ-F-004 FAILING)"
  }
 },
 "page": {
  "url": null,
  "comments": true
 },
 "requirements": [
  {
   "id": "REQ-F-001",
   "title": "Pedir cita desde el móvil",
   "plain": "Tu cliente abre un enlace en el móvil, elige el tipo de arreglo y deja su nombre y teléfono. La cita queda guardada y le aparece una confirmación en pantalla.",
   "status": "shown",
   "fase": 1,
   "warnings": []
  },
  {
   "id": "REQ-F-002",
   "title": "Elegir una hora libre",
   "plain": "Al pedir cita, tu cliente solo ve las horas en que el taller está abierto y queda sitio. Así nunca se juntan dos bicis a la misma hora.",
   "status": "building",
   "fase": 1,
   "warnings": [
    {
     "code": "unshown"
    },
    {
     "code": "stale"
    }
   ]
  },
  {
   "id": "REQ-F-003",
   "title": "Ver las citas de mañana",
   "plain": "Cada tarde puedes ver en una sola pantalla las citas del día siguiente, ordenadas por hora, con el arreglo que pidió cada cliente.",
   "status": "building",
   "fase": 2,
   "warnings": [
    {
     "code": "weakened"
    }
   ]
  },
  {
   "id": "REQ-F-004",
   "title": "Cancelar una cita",
   "plain": "Tu cliente puede cancelar su cita desde el mismo enlace. La hora vuelve a quedar libre para otra persona.",
   "status": "failing",
   "fase": 2,
   "warnings": [
    {
     "code": "challenge"
    },
    {
     "code": "failing"
    }
   ]
  },
  {
   "id": "REQ-F-005",
   "title": "Comprar un bono de revisiones",
   "plain": null,
   "status": "pending",
   "fase": 3,
   "warnings": []
  },
  {
   "id": "REQ-F-006",
   "title": "Aviso de bici lista",
   "plain": "Cuando marcas una reparación como terminada, tu cliente recibe un mensaje para que pase a recogerla.",
   "status": "deferred",
   "fase": null,
   "warnings": []
  },
  {
   "id": "REQ-F-007",
   "title": "Pagar la señal con tarjeta",
   "plain": "Tu cliente iba a pagar 5 € de señal con tarjeta al reservar. Lo quitamos porque prefieres cobrar en el taller.",
   "status": "deprecated",
   "fase": null,
   "warnings": []
  },
  {
   "id": "REQ-NF-001",
   "title": "La página de cita carga rápido",
   "plain": "La página para pedir cita se abre en menos de 2 segundos en un móvil con datos normales, para que nadie se canse de esperar.",
   "status": "shown",
   "fase": 1,
   "warnings": []
  },
  {
   "id": "REQ-C-001",
   "title": "Datos guardados en Europa",
   "plain": "Los datos de tus clientes se guardan en servidores dentro de la Unión Europea y nunca se copian fuera.",
   "status": "shown",
   "fase": 1,
   "warnings": []
  }
 ],
 "journal": [
  {
   "at": "2026-09-22T09:00:00+02:00",
   "kind": "start",
   "text": "Empezamos a construir la entrega 2."
  },
  {
   "at": "2026-09-29T19:40:00+02:00",
   "kind": "evidence",
   "text": "Un revisor independiente comprobó que, al cancelar una cita, la hora no vuelve a quedar libre. Lo estamos arreglando."
  },
  {
   "at": "2026-10-01T09:30:00+02:00",
   "kind": "done",
   "text": "Terminamos la lista de citas de mañana; falta grabar su vídeo."
  }
 ]
}
