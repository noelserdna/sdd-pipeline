# Audit Checklists por Tipo de Documento

> Checklists detallados para auditoría sistemática de cada tipo de documento SDD.

---

## Checklist: Glossary (domain/01-GLOSSARY.md)

### Completitud
- [ ] ¿Cada entidad del sistema tiene entrada en glosario?
- [ ] ¿Cada estado tiene definición?
- [ ] ¿Los acrónimos están expandidos?
- [ ] ¿Hay columna "NO usar" con sinónimos prohibidos?

### Consistencia
- [ ] ¿La definición es única y no circular?
- [ ] ¿El término se usa consistentemente en todos los docs?
- [ ] ¿Las variaciones (singular/plural) están documentadas?

### Preguntas de auditoría
```
- ¿Qué términos aparecen en otros docs pero no en glosario?
- ¿Qué sinónimos prohibidos aparecen en otros docs?
- ¿Hay definiciones que contradicen el uso real?
```

---

## Checklist: Entities (domain/02-ENTITIES.md)

### Estructura
- [ ] ¿Cada entidad tiene ID único?
- [ ] ¿Están definidos todos los atributos con tipos?
- [ ] ¿Están marcados los atributos required vs optional?
- [ ] ¿Hay aggregate root identificado?

### Relaciones
- [ ] ¿Las relaciones tienen cardinalidad (1:1, 1:N, N:M)?
- [ ] ¿Las FK están documentadas?
- [ ] ¿El ownership está claro (quién elimina a quién)?

### Preguntas de auditoría
```
- ¿Hay atributos sin tipo definido?
- ¿Hay relaciones sin cardinalidad?
- ¿Qué pasa cuando se elimina el parent?
- ¿Los defaults están especificados?
```

---

## Checklist: States (domain/04-STATES.md)

### Completitud
- [ ] ¿Cada entidad stateful tiene diagrama de estados?
- [ ] ¿Están definidos todos los estados posibles?
- [ ] ¿Hay estado inicial marcado?
- [ ] ¿Hay estados finales marcados?

### Transiciones
- [ ] ¿Cada transición tiene trigger definido?
- [ ] ¿Cada transición tiene guard conditions?
- [ ] ¿Cada transición tiene action?
- [ ] ¿Hay transiciones de error/timeout?

### Preguntas de auditoría
```
- ¿Hay estados sin transición de salida (dead states)?
- ¿Hay estados inalcanzables?
- ¿Qué pasa si el trigger falla?
- ¿Hay timeout definido por estado?
- ¿Qué eventos se emiten en cada transición?
```

---

## Checklist: Invariants (domain/05-INVARIANTS.md)

### Formato
- [ ] ¿Cada invariante tiene ID único (INV-{AREA}-{NNN})?
- [ ] ¿La regla está en forma declarativa?
- [ ] ¿Hay query/constraint de validación?

### Cobertura
- [ ] ¿Hay invariantes para límites de valores?
- [ ] ¿Hay invariantes para integridad referencial?
- [ ] ¿Hay invariantes para reglas de negocio críticas?
- [ ] ¿Hay invariantes para permisos/autorización?

### Preguntas de auditoría
```
- ¿Hay reglas en UCs que deberían ser invariantes?
- ¿Cada invariante tiene validación implementable?
- ¿Los rangos numéricos tienen ambos límites?
- ¿Qué invariantes no tienen constraint SQL?
```

---

## Checklist: Use Case (use-cases/UC-NNN.md)

### Metadata
- [ ] ¿Tiene ID único (UC-NNN)?
- [ ] ¿Tiene versión y fecha?
- [ ] ¿Están listados los actores?
- [ ] ¿Hay precondiciones?
- [ ] ¿Hay postcondiciones?

### Flujos
- [ ] ¿El flujo principal está completo?
- [ ] ¿Hay flujos alternativos para variaciones válidas?
- [ ] ¿Hay flujos de excepción para errores?
- [ ] ¿Cada paso tiene actor + acción + resultado?

### Input/Output
- [ ] ¿El input tiene schema YAML/TypeScript?
- [ ] ¿El output tiene schema?
- [ ] ¿Los campos tienen tipos y constraints?
- [ ] ¿Los campos optional están marcados?

### Errores
- [ ] ¿Cada error tiene código único?
- [ ] ¿Cada error tiene HTTP status?
- [ ] ¿Cada error indica cuándo ocurre?

### Trazabilidad
- [ ] ¿Hay referencia a REQ-XXX que origina el UC?
- [ ] ¿Hay referencia a WF-NNN si aplica?
- [ ] ¿Hay referencia a INV-XXX que aplican?
- [ ] ¿Hay referencia a BDD-feature que verifica?

### Preguntas de auditoría
```
- ¿Qué pasa si la precondición no se cumple?
- ¿Qué pasa si falla cada paso del flujo?
- ¿Los errores cubren todos los fallos posibles?
- ¿El output varía según el flujo tomado?
- ¿Hay side effects no documentados (eventos, logs)?
```

---

## Checklist: Workflow (workflows/WF-NNN.md)

### Metadata
- [ ] ¿Tiene ID único (WF-NNN)?
- [ ] ¿Tiene trigger definido?
- [ ] ¿Tiene timeout máximo total?

### Steps
- [ ] ¿Cada step tiene nombre único?
- [ ] ¿Cada step tiene tipo (http, activity, conditional)?
- [ ] ¿Cada step tiene timeout individual?
- [ ] ¿Cada step tiene retry policy?
- [ ] ¿Cada step tiene input/output schema?

### Error Handling
- [ ] ¿Cada step lista errores posibles?
- [ ] ¿Cada error tiene acción (retry, fallback, fail)?
- [ ] ¿Hay compensación si falla después de step N?

### Métricas
- [ ] ¿Hay métricas de duración?
- [ ] ¿Hay métricas de success rate?
- [ ] ¿Hay métricas por step?

### Preguntas de auditoría
```
- ¿Suma de timeouts de steps > timeout total?
- ¿Qué pasa si retry policy se agota?
- ¿Hay race conditions entre steps paralelos?
- ¿La compensación revierte todos los side effects?
- ¿Los eventos se emiten en el momento correcto?
```

---

## Checklist: API Contract (contracts/API-{module}.md)

### Endpoint
- [ ] ¿Tiene método HTTP y path?
- [ ] ¿Tiene authentication requirement?
- [ ] ¿Tiene rate limit?
- [ ] ¿Tiene version (v1, v2)?

### Request
- [ ] ¿Headers requeridos están listados?
- [ ] ¿Path params tienen tipo y validación?
- [ ] ¿Query params tienen tipo y default?
- [ ] ¿Body tiene schema completo?

### Response
- [ ] ¿Hay schema para success (200/201)?
- [ ] ¿Hay schema para cada error code?
- [ ] ¿Los error codes son únicos globalmente?

### Preguntas de auditoría
```
- ¿El rate limit es consistente con nfr/LIMITS.md?
- ¿Los error codes coinciden con UC correspondiente?
- ¿Hay campos en response no documentados?
- ¿El endpoint está en la lista de rutas del sistema?
- ¿Hay version strategy documentada?
```

---

## Checklist: ADR (adr/ADR-NNN.md)

### Metadata
- [ ] ¿Tiene ID único (ADR-NNN)?
- [ ] ¿Tiene estado (Proposed, Accepted, Deprecated, Superseded)?
- [ ] ¿Tiene fecha?
- [ ] ¿Si Superseded, referencia al nuevo ADR?

### Contenido
- [ ] ¿El contexto explica el problema?
- [ ] ¿La decisión es clara y específica?
- [ ] ¿Hay alternativas consideradas con pros/cons?
- [ ] ¿Las consecuencias incluyen positivas Y negativas?
- [ ] ¿Los riesgos están identificados?

### Preguntas de auditoría
```
- ¿Hay decisiones en otros docs sin ADR?
- ¿El ADR sigue siendo válido o necesita revisión?
- ¿Las consecuencias negativas se materializaron?
- ¿Hay ADRs "Proposed" por más de 30 días?
```

---

## Checklist: BDD Test (tests/BDD-{feature}.md)

### Formato
- [ ] ¿Tiene Feature con As/I want/So that?
- [ ] ¿Los scenarios tienen Given/When/Then?
- [ ] ¿Hay Background para setup común?

### Cobertura
- [ ] ¿Hay scenario para happy path?
- [ ] ¿Hay scenarios para cada flujo alternativo del UC?
- [ ] ¿Hay scenarios para cada flujo de excepción?
- [ ] ¿Hay scenarios para edge cases?

### Trazabilidad
- [ ] ¿Cada scenario referencia AC-XXX-NNN?
- [ ] ¿Los scenarios cubren todos los AC del UC?

### Preguntas de auditoría
```
- ¿Hay flujos del UC sin scenario correspondiente?
- ¿Hay scenarios que prueban comportamiento no especificado?
- ¿Los valores en Examples son representativos?
- ¿Los scenarios son independientes entre sí?
```

---

## Checklist: NFR - Security (nfr/SECURITY.md)

### Authentication
- [ ] ¿Está definido el método de auth (JWT, API key)?
- [ ] ¿Están definidos los claims/scopes?
- [ ] ¿Hay timeout de sesión?
- [ ] ¿Hay política de refresh token?

### Authorization
- [ ] ¿Hay matriz de permisos rol/recurso/acción?
- [ ] ¿Cada endpoint tiene permisos documentados?
- [ ] ¿Hay row-level security (tenant isolation)?

### Encryption
- [ ] ¿Está definido encryption at rest?
- [ ] ¿Está definido encryption in transit?
- [ ] ¿Hay key rotation policy?
- [ ] ¿Los campos PII están identificados?

### Audit
- [ ] ¿Hay lista de eventos auditables?
- [ ] ¿Hay retention policy para logs?
- [ ] ¿Hay formato de log definido?

### Preguntas de auditoría
```
- ¿Hay endpoints sin auth requirement definido?
- ¿La matriz de permisos está completa?
- ¿Todos los campos PII tienen encryption?
- ¿El key rotation tiene runbook?
```

---

## Checklist: NFR - Performance (nfr/PERFORMANCE.md)

### Latencia
- [ ] ¿Hay targets p50, p95, p99?
- [ ] ¿Están segmentados por endpoint/operación?
- [ ] ¿Hay condiciones (normal load, peak load)?

### Throughput
- [ ] ¿Hay RPS/TPS target?
- [ ] ¿Hay concurrent users target?
- [ ] ¿Hay batch size limits?

### Recursos
- [ ] ¿Hay limits de memoria/CPU?
- [ ] ¿Hay limits de conexiones DB?
- [ ] ¿Hay limits de file size?

### Preguntas de auditoría
```
- ¿Los targets son alcanzables con arquitectura actual?
- ¿Hay contradicciones con timeouts en WFs?
- ¿Los limits son consistentes entre docs?
- ¿Hay SLO correspondiente a cada target?
```

---

## Checklist: NFR - Limits (nfr/LIMITS.md)

### Completitud
- [ ] ¿Cada recurso tiene límite definido?
- [ ] ¿Cada límite tiene unidad?
- [ ] ¿Cada límite tiene justificación?
- [ ] ¿Hay comportamiento definido cuando se excede?

### Consistencia
- [ ] ¿Los límites coinciden con menciones en UCs?
- [ ] ¿Los límites coinciden con menciones en WFs?
- [ ] ¿Los límites coinciden con API contracts?

### Preguntas de auditoría
```
- ¿Hay recursos sin límite explícito?
- ¿Los límites son por user, org, o global?
- ¿Qué error code se retorna al exceder?
- ¿Hay rate limit que contradiga performance target?
```

---

## Checklist: Observability (nfr/OBSERVABILITY.md)

### SLOs
- [ ] ¿Cada SLO tiene ID único?
- [ ] ¿Cada SLO tiene objetivo numérico?
- [ ] ¿Cada SLO tiene ventana de tiempo?
- [ ] ¿Cada SLO deriva de un REQ?

### SLIs
- [ ] ¿Cada SLO tiene SLI correspondiente?
- [ ] ¿Cada SLI tiene query/fórmula?
- [ ] ¿El SLI es medible con telemetría actual?

### Alertas
- [ ] ¿Cada alerta tiene threshold?
- [ ] ¿Cada alerta tiene severidad?
- [ ] ¿Cada alerta tiene runbook?

### Preguntas de auditoría
```
- ¿Hay SLOs sin SLI implementable?
- ¿Los thresholds de alerta son coherentes con SLO?
- ¿Hay runbook para cada alerta critical?
- ¿El error budget está calculado?
```

---

## Checklist Cross-Document

### Trazabilidad REQ → Implementation
- [ ] ¿Cada REQ tiene al menos un UC?
- [ ] ¿Cada UC tiene BDD scenarios?
- [ ] ¿Cada INV tiene validación en código/DB?

### Consistencia de Valores
- [ ] ¿Timeouts son consistentes entre LIMITS, WF, API?
- [ ] ¿Rate limits son consistentes entre LIMITS, API, ADR?
- [ ] ¿File size limits son consistentes?
- [ ] ¿Retention periods son consistentes?

### Consistencia de Términos
- [ ] ¿Solo se usan términos del glosario?
- [ ] ¿No hay sinónimos prohibidos?
- [ ] ¿Capitalization es consistente?

### Referencias
- [ ] ¿Todas las referencias a otros docs son válidas?
- [ ] ¿Los IDs referenciados existen?
- [ ] ¿No hay referencias circulares problemáticas?

---

## Checklist: Regression Verification

> Use this checklist after fixes have been applied from a previous audit to verify no regressions were introduced.

### Modified Files Consistency
- [ ] ¿Los archivos modificados desde el último audit mantienen consistencia con sus dependencias?
- [ ] ¿Los enums/value-objects modificados están sincronizados en TODOS los documentos que los usan?
- [ ] ¿Las invariantes que referencian campos modificados siguen siendo válidas?
- [ ] ¿Los UCs que referencian estados modificados reflejan las transiciones actualizadas?
- [ ] ¿Los contratos API reflejan los cambios en el modelo de dominio?

### Cross-Reference Integrity
- [ ] ¿Las referencias cruzadas (INV-IDs, UC-IDs, ADR-IDs) siguen siendo válidas después de los cambios?
- [ ] ¿Los documentos que referencian valores modificados usan el valor actualizado?
- [ ] ¿Los permisos en PERMISSIONS-MATRIX.md reflejan los cambios en contratos API?

### Enum/VO Sync
- [ ] ¿Cada enum modificado tiene los mismos valores en todos los documentos que lo declaran?
- [ ] ¿Los Value Objects modificados mantienen los mismos campos/tipos en entities y contracts?
- [ ] ¿Los estados modificados tienen las mismas transiciones en STATES.md, UCs, y WFs?

### Preguntas de auditoría
```
- ¿Algún fix introdujo una nueva inconsistencia con un documento no tocado?
- ¿Los commits de fix tocaron todos los documentos dependientes?
- ¿Hay documentos que deberían haberse actualizado pero no lo fueron?
```

---

## Checklist: Baseline Management

> Use this checklist to manage the audit baseline file that prevents re-reporting of known findings.

### Existencia y Formato
- [ ] ¿Existe `AUDIT-BASELINE.md` en el directorio de auditorías?
- [ ] ¿El formato del baseline sigue la estructura esperada (3 tablas: Accepted, Deferred, Resolved)?
- [ ] ¿El baseline indica la fecha de última actualización y el audit de origen?

### Vigencia
- [ ] ¿Los hallazgos `accepted` siguen siendo válidos? (no hay cambios que los invaliden)
- [ ] ¿Los hallazgos `deferred` tienen fecha de re-evaluación?
- [ ] ¿Algún hallazgo `deferred` ha pasado su fecha de re-evaluación y debe revisarse?
- [ ] ¿Los hallazgos `resolved` corresponden a las últimas 2 versiones de audit?

### Actualización Post-Audit
- [ ] ¿Se movieron los hallazgos resueltos al baseline con estado `resolved`?
- [ ] ¿Se agregaron los hallazgos marcados como `wont_fix` por el usuario?
- [ ] ¿Se limpiaron los `resolved` que tienen más de 2 versiones de antigüedad?

### Preguntas de auditoría
```
- ¿Algún hallazgo aceptado debería re-evaluarse por cambios recientes en las specs?
- ¿El baseline refleja fielmente las decisiones tomadas en auditorías anteriores?
- ¿Hay hallazgos en el baseline que ya no aplican porque se eliminó la funcionalidad?
```
