# Perfilado de una etapa: `sdd-spec-auditor` (2026-08-25)

Herramienta: `scripts/sdd-profile.sh` (ejecuta la skill con `claude -p --output-format stream-json --verbose` y desglosa el flujo de eventos; `--analyze FILE.jsonl` sobre una captura existente).

Caso: re-auditoría de `spec/` del todo-app (7 UC, 4 contratos, 7 ADR, dominio, NFR) en modo solo auditoría.

| Métrica | Valor |
|---|---|
| Duración total | **21,4 min**, de los que **21,1 min son tiempo de API** (el modelo generando o leyendo; los hooks y el disco son despreciables) |
| Turnos | 57 (56 llamadas a herramientas, todas `Bash`: `cat`/`echo` en modo `-p`) |
| Tokens de salida | **112.093** |
| Tokens de entrada nuevos | 5.161 · caché leída 3,64 M · caché creada 375 k |
| Leído por herramientas | 423.102 chars (~106 k tokens): los ficheros de `spec/` completos, uno a uno (resultados de hasta 28 k chars) |
| Escrito | 94.565 chars (el informe `AUDIT-BASELINE.md` y auxiliares) |
| Coste | ~16,8 $ |

## Dónde se va el tiempo

1. **Generación de salida (dominante).** 112 k tokens de salida a la velocidad típica del modelo explican por sí solos la mayor parte de los 21 min. El informe de auditoría de un proyecto de 10 requisitos ocupa ~95 k caracteres: la plantilla de la skill pide demasiado texto (restituye contenido de las specs, tablas exhaustivas por documento, hallazgos bajos redactados en extenso).
2. **Lectura completa del corpus.** ~106 k tokens de specs entran en contexto antes de escribir nada. Es caché (barato en tiempo por turno), pero obliga a 57 turnos con un contexto de ~64 k tokens y a que la primera pasada sea secuencial.
3. **Secuencialidad.** La auditoría por dimensiones (DOM/UC/CON/NFR) que la skill ya describe como "protocolo multi-agente" no se activa en modo `-p`: todo lo hace un único hilo.

## Recortes recomendados (estimación)

| Acción | Dónde | Ganancia estimada |
|---|---|---|
| Plantilla de informe compacta: solo hallazgos P0-P2 en detalle, P3 como tabla de una línea, sin restituir specs, sin secciones vacías | `skills/sdd-spec-auditor` (y misma revisión en test-planner, plan-architect, specifications-engineer, que también generan >80 k chars) | −40…−60 % de salida → −8…−12 min |
| Lectura por índice: leer primero IDs/títulos y solo abrir las secciones que cada dimensión necesita | referencias de las skills de auditoría | −30…−50 % de contexto; menos `cache_create` |
| Fan-out por dimensión con subagentes (Workflow) también en `-p`: 4 auditores en paralelo con contexto pequeño + consolidación | `sdd-spec-auditor` Mode multi-agente por defecto cuando `spec/` > N ficheros | tiempo de pared ≈ la dimensión más lenta (5-7 min) |
| Modelo más rápido para etapas mecánicas (`test-planner` matrices, `task-generator`, subagentes `[P]`) vía `CLAUDE_CODE_SUBAGENT_MODEL` / `--model` | ejecución | ×2-3 en esas etapas |
| Medir siempre: `scripts/sdd-profile.sh` en `tests/e2e` para cada release y guardar aquí la tabla | proceso | evita regresiones de coste |

Orden sugerido: 1 (mayor ganancia, solo texto de skills) → 3 → 2 → 4.
