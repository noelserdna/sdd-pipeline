---
description: "Una línea por pipeline SDD vivo, aunque corra en otro proceso (claude -p) y otro proyecto. Sin argumentos recorre el índice global; con una ruta, ese checkout."
argument-hint: "[ruta del checkout principal]"
allowed-tools: Bash
---

Runs vivos (índice `~/.claude/sdd/active-runs.json`, escrito por el hook de actividad):

!`bash "${CLAUDE_PLUGIN_ROOT}/scripts/sdd-watch.sh" --brief $ARGUMENTS < /dev/null`

Muestra esas líneas al usuario tal cual (una por run: proyecto, etapas hechas, etapa en curso con su
reloj, subagentes vivos y preguntas abiertas). Sin salida: no hay ningún run registrado — el pipeline
no ha arrancado, o corre en un proyecto sin `pipeline-state.json`. Para el panel completo y en vivo:
`bash "${CLAUDE_PLUGIN_ROOT}/scripts/sdd-watch.sh" --root <proyecto>`.
