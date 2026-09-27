#!/bin/bash
# H3: SDD Pipeline State Auto-Updater
# Hook type: PreToolUse (Skill) | UserPromptExpansion | PostToolUse (Write) — async: true | Timeout: 5-10s
# Marks a stage "running" in pipeline-state.json in two situations:
#   - its skill starts: PreToolUse Skill (tool_input.skill) or a typed /command (UserPromptExpansion
#     command_name, which does not go through PreToolUse). Mode `skill`: pending/stale/done → running,
#     because an explicitly started skill is a (re-)run. A skill that writes through Bash heredocs
#     (common in `claude -p`) never triggers the Write path, so this is what marks its stage.
#   - a file under its directory is written (PostToolUse Write). Mode `write`: only pending/stale →
#     running (never "done" — that's the skill's responsibility — and never reopens a done stage).
# Does nothing when pipeline-state.json does not exist, and never fails (exit 0).
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
[ -n "$INPUT" ] || exit 0

# ── Skill start: PreToolUse Skill / UserPromptExpansion ─────────────────────────────────────────
# The event and skill name come out of the JSON with a bash regex (no jq/node process); names with
# escapes are not pipeline skills anyway. `plugin:` prefix and a leading `/` are dropped.
EVENT=""
if [[ "$INPUT" =~ \"hook_event_name\"[[:space:]]*:[[:space:]]*\"([^\"]*)\" ]]; then EVENT="${BASH_REMATCH[1]}"; fi
if [ "$EVENT" = "PreToolUse" ] || [ "$EVENT" = "UserPromptExpansion" ]; then
  SKILL_NAME=""
  if [ "$EVENT" = "UserPromptExpansion" ]; then
    if [[ "$INPUT" =~ \"command_name\"[[:space:]]*:[[:space:]]*\"([^\"]*)\" ]]; then SKILL_NAME="${BASH_REMATCH[1]}"; fi
  elif [[ "$INPUT" =~ \"skill\"[[:space:]]*:[[:space:]]*\"([^\"]*)\" ]]; then
    SKILL_NAME="${BASH_REMATCH[1]}"
  fi
  SKILL_NAME=${SKILL_NAME#/}; SKILL_NAME=${SKILL_NAME##*:}
  case "$SKILL_NAME" in
    sdd-requirements-engineer)   STAGE=requirements-engineer ;;
    sdd-specifications-engineer) STAGE=specifications-engineer ;;
    sdd-spec-auditor)            STAGE=spec-auditor ;;
    sdd-test-planner)            STAGE=test-planner ;;
    sdd-plan-architect)          STAGE=plan-architect ;;
    sdd-task-generator)          STAGE=task-generator ;;
    sdd-task-implementer)        STAGE=task-implementer ;;
    sdd-acceptance)              STAGE=acceptance ;;
    sdd-security-auditor)        STAGE=security-auditor ;;
    sdd-tech-designer)           STAGE=tech-designer ;;
    sdd-ux-designer)             STAGE=ux-designer ;;
    sdd-gap-detector)            STAGE=gap-detector ;;
    sdd-req-change)              STAGE=req-change ;;
    *) exit 0 ;;
  esac
  sdd_roots "$INPUT"
  # An explicitly started skill reopens its done stage (re-run); error and running are left alone.
  sdd_mark_running "$STATE_ROOT/pipeline-state.json" "$STAGE" skill
  exit 0
fi

# ── File write: PostToolUse Write ────────────────────────────────────────────────────────────────
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
