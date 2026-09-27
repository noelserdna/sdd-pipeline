#!/bin/bash
# H3: SDD Pipeline State Auto-Updater
# Hook type: PostToolUse (Write) | async: true | Timeout: 10s
# Detects writes to pipeline artifact directories and updates pipeline-state.json.
# Only marks pending/stale stages as "running" (never "done" — that's the skill's responsibility —
# and never reopens a done stage). Does nothing when pipeline-state.json does not exist.
# NOTE: The "summary" field in each stage is EXCLUSIVELY managed by skills on completion.
# This hook must NOT modify or remove the "summary" field. The jq/node updates below
# only touch status/lastRun/staleReason/currentStage/lastUpdated, preserving summary intact.
#
# Dos raíces (hooks/lib/sdd-common.sh): REL_PATH se clasifica respecto al toplevel git del
# fichero (worktree incluido); pipeline-state.json vive SIEMPRE en STATE_ROOT (raíz del .git
# común), así varios worktrees comparten un único estado. Lectura-modificación-escritura bajo
# sdd_lock (mkdir atómico) → jq a fichero temporal en el mismo directorio → mv (sdd_mark_running).

set -euo pipefail

SDD_LIB="$(dirname "${BASH_SOURCE[0]}")/lib/sdd-common.sh"
if [ ! -f "$SDD_LIB" ]; then echo "sdd-pipeline-state-updater: falta $SDD_LIB" >&2; exit 0; fi
# shellcheck source=lib/sdd-common.sh
. "$SDD_LIB"

INPUT=$(cat)

# Check if the write was successful
TOOL_SUCCESS=$(printf '%s' "$INPUT" | sdd_json_get - '.toolResponse.success // .tool_response.success // "true"') || TOOL_SUCCESS="true"
if [ "$TOOL_SUCCESS" = "false" ]; then
  exit 0
fi

# Extract file_path
FILE_PATH=$(printf '%s' "$INPUT" | sdd_json_get - '.toolInput.file_path // .tool_input.file_path // empty') || FILE_PATH=""
if [ -z "$FILE_PATH" ]; then
  exit 0
fi

sdd_roots "$INPUT" "$FILE_PATH"
PIPELINE_STATE="$STATE_ROOT/pipeline-state.json"

# Not under the project: skip
case "$REL_PATH" in
  /*|[A-Za-z]:/*) exit 0 ;;
esac

# Skip pipeline-state.json itself (avoid infinite loop)
if [ "$REL_PATH" = "pipeline-state.json" ]; then
  exit 0
fi

# Defensa: REL_PATH ya es relativo al worktree; si aun así llega una copia bajo .claude/worktrees/, ignorar
case "$REL_PATH" in
  .claude/worktrees/*) exit 0 ;;
esac

# Map path to pipeline stage (specific audit prefixes BEFORE the generic audits/* rule)
path_to_stage() {
  local path="$1"
  case "$path" in
    requirements/*)           echo "requirements-engineer" ;;
    spec/*)                   echo "specifications-engineer" ;;
    audits/SECURITY-*)        echo "security-auditor" ;;
    audits/GAP-*)             echo "gap-detector" ;;
    audits/UPSTREAM-IMPACT-*) echo "spec-auditor" ;;
    audits/*)                 echo "spec-auditor" ;;
    design/*)                 echo "tech-designer" ;;
    ux/*)                     echo "ux-designer" ;;
    test/*)                   echo "test-planner" ;;
    plan/*)                   echo "plan-architect" ;;
    task/*)                   echo "task-generator" ;;
    src/*|tests/*)            echo "task-implementer" ;;
    feedback/*)               echo "task-implementer" ;;
    *)                        echo "" ;;
  esac
}

# Código y tests declarados en el SDD Stack Profile de CLAUDE.md (code_paths/test_paths; por defecto
# src y tests) → task-implementer ANTES del case: web/app/..., o test/models/... con Minitest en la
# raíz. Los .md de primer nivel de test/ siguen siendo de test-planner (sdd_is_impl_path).
if sdd_is_impl_path "$REL_PATH"; then
  STAGE="task-implementer"
else
  STAGE=$(path_to_stage "$REL_PATH")
fi

# If path doesn't map to a stage, skip
if [ -z "$STAGE" ]; then
  exit 0
fi

# pipeline-state.json lo crea sdd-setup. Sin él, este repositorio no usa SDD (los hooks del plugin
# son globales): no se crea nada, o el upstream guard empezaría a denegar ediciones en cualquier repo
# (p. ej. spec/**/*_spec.rb de Rails).
[ -f "$PIPELINE_STATE" ] || exit 0

# pending/stale → running bajo sdd_lock; done, error y running no se tocan (hooks/lib/sdd-common.sh).
# Skills set "done" explicitly on completion (writing to pipeline-state.json, which H3 skips).
sdd_mark_running "$PIPELINE_STATE" "$STAGE" write
exit 0
