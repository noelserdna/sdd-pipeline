# Detection Patterns for Automated Audit

> Patrones de búsqueda para detectar defectos automáticamente en especificaciones.

---

## CAT-01: Ambigüedades - Palabras Sospechosas

### Grep Patterns

```bash
# Cuantificadores vagos
grep -rniE "(apropiado|adecuado|razonable|suficiente|normal|típico)" spec/

# Tiempo indefinido
grep -rniE "(pronto|rápido|inmediato|cuando sea posible|en breve)" spec/

# Frecuencia indefinida
grep -rniE "(frecuentemente|regularmente|periódicamente|ocasionalmente)" spec/

# Cantidad indefinida
grep -rniE "(varios|algunos|muchos|pocos|la mayoría|casi todos)" spec/

# Condicionales ambiguos
grep -rniE "(si es necesario|cuando corresponda|según sea apropiado)" spec/

# Comparativos sin referencia
grep -rniE "(mejor|peor|más rápido|más lento|mayor|menor)" spec/

# "etc" y listas incompletas
grep -rniE "(etc\.|y otros|entre otros|y similares)" spec/
```

### Palabras a Investigar

| Palabra | Problema | Pregunta |
|---------|----------|----------|
| "apropiado" | Sin criterio definido | ¿Qué lo hace apropiado? |
| "razonable" | Subjetivo | ¿Cuál es el valor numérico? |
| "normalmente" | Implica excepciones | ¿Qué pasa en casos anormales? |
| "debería" | No es obligatorio | ¿Es MUST o SHOULD? |
| "puede" | Opcional o capacidad? | ¿Es MAY o CAN? |
| "etc." | Lista incompleta | ¿Cuáles son todos los casos? |

---

## CAT-02: Reglas Implícitas - Patrones

### Grep Patterns

```bash
# Validaciones implícitas
grep -rniE "(válido|inválido|correcto|incorrecto)" spec/ | grep -v "validación"

# Asunciones de unicidad
grep -rniE "(único|duplicado|ya existe)" spec/

# Orden implícito
grep -rniE "(primero|después|antes de|luego)" spec/

# Defaults no especificados
grep -rniE "por defecto|default" spec/

# Permisos implícitos
grep -rniE "(puede|no puede|tiene acceso|sin acceso)" spec/
```

### Señales de Reglas Implícitas

```markdown
- "El usuario ingresa su email" → ¿Se valida formato? ¿Unicidad?
- "Se guarda el archivo" → ¿Dónde? ¿Con qué nombre? ¿Permisos?
- "Se envía notificación" → ¿A quién? ¿Qué canal? ¿Inmediato?
- "Se actualiza el estado" → ¿Quién puede? ¿Se registra audit?
```

---

## CAT-03: Silencios Peligrosos - Detección

### Grep Patterns

```bash
# Buscar flujos sin manejo de error
grep -rniE "^(When|Cuando)" spec/use-cases/ | grep -v -i "error\|excep\|falla"

# Steps sin timeout
grep -rniE "^### Step" spec/workflows/ -A 10 | grep -v "timeout"

# Estados sin transición de error
grep -rniE "status.*=" spec/domain/04-STATES.md | grep -v "failed\|error"

# Operaciones sin rollback
grep -rniE "(crear|insertar|guardar|actualizar|eliminar)" spec/ | grep -v "rollback\|compensar\|revert"
```

### Checklist de Silencios

```markdown
Para cada operación, verificar:
- [ ] ¿Qué pasa si falla?
- [ ] ¿Qué pasa si hay timeout?
- [ ] ¿Qué pasa si hay datos parciales?
- [ ] ¿Qué pasa si hay duplicados?
- [ ] ¿Qué pasa si no hay datos?
- [ ] ¿Qué pasa si el usuario cancela?
- [ ] ¿Qué pasa concurrentemente?
```

---

## CAT-04: Ambigüedades Semánticas - Detección

### Grep Patterns

```bash
# Extraer términos del glosario
TERMS=$(grep -oE "^\| \*\*[^*]+\*\*" spec/domain/01-GLOSSARY.md | sed 's/| \*\*//;s/\*\*//')

# Buscar sinónimos prohibidos
grep -rniE "(job|task|proceso)" spec/ --include="*.md" | grep -v GLOSSARY

# Buscar variaciones de capitalización
grep -rn "extraction" spec/ | grep -v "Extraction"

# Buscar términos no definidos
grep -rnoE "\b[A-Z][a-z]+[A-Z][a-z]+\b" spec/ | sort -u
# (CamelCase terms that might need glossary entry)
```

### Matriz de Sinónimos Comunes

| Término Canónico | Sinónimos a Detectar |
|------------------|---------------------|
| Extraction | job, task, proceso, extracción |
| CV | resume, curriculum, hoja de vida |
| Organización | tenant, empresa, company, cliente |
| JobOffer | vacancy, position, puesto, oferta |
| MatchResult | match, score, resultado |
| User | usuario, member, account |

---

## CAT-05: Contradicciones - Detección

### Grep Patterns para Valores

```bash
# Buscar todos los timeouts
grep -rniE "timeout.*[0-9]+" spec/ | sort

# Buscar todos los límites de tamaño
grep -rniE "(size|tamaño).*[0-9]+" spec/ | sort

# Buscar todos los rate limits
grep -rniE "rate.*limit.*[0-9]+" spec/ | sort

# Buscar todos los retention periods
grep -rniE "retention.*[0-9]+" spec/ | sort

# Comparar valores del mismo concepto
grep -rniE "max_file_size|file.size.limit" spec/
```

### Valores Críticos a Cruzar

| Concepto | Documentos a Revisar |
|----------|---------------------|
| Timeout extracción | LIMITS.md, WF-001.md, API-extraction.md |
| Max file size | LIMITS.md, UC-001.md, API-upload.md |
| Rate limit | LIMITS.md, API-*.md, ADR-025.md |
| Session timeout | SECURITY.md, LIMITS.md |
| Retention period | SECURITY.md, GDPR docs, LIMITS.md |

---

## CAT-06: Especificaciones Incompletas - Detección

### Grep Patterns

```bash
# TODOs pendientes
grep -rniE "(TODO|TBD|FIXME|PENDING|WIP)" spec/

# Secciones vacías (solo heading sin contenido)
grep -rniE "^##" spec/ -A 1 | grep -B 1 "^--$"

# Placeholders
grep -rniE "(\{.*\}|<.*>|\[.*\])" spec/ | grep -v "código\|example"

# Referencias a documentos que no existen
grep -rnoE "(UC-[0-9]+|WF-[0-9]+|ADR-[0-9]+|INV-[A-Z]+-[0-9]+)" spec/ | sort -u

# Campos sin valor
grep -rniE ":\s*$" spec/
```

### Secciones Requeridas por Tipo

```yaml
use-case:
  required:
    - Actores
    - Precondiciones
    - Postcondiciones
    - Flujo Principal
    - Flujos de Excepción
    - Errores
    - Trazabilidad

workflow:
  required:
    - Trigger
    - Timeout
    - Steps (con timeout individual)
    - Error handling
    - Compensación
    - Métricas

invariant:
  required:
    - ID
    - Regla declarativa
    - Validación (SQL o Zod)
```

---

## CAT-07: Invariantes Débiles - Detección

### Grep Patterns

```bash
# Buscar restricciones en UCs que no son INV
grep -rniE "(debe|no debe|siempre|nunca|máximo|mínimo)" spec/use-cases/ | grep -v "INV-"

# Invariantes sin validación
grep -rniE "^### INV-" spec/domain/05-INVARIANTS.md -A 10 | grep -v "CHECK\|Zod\|validate"

# Rangos sin ambos límites
grep -rniE "entre [0-9]+ y" spec/
grep -rniE "> [0-9]+[^0-9]" spec/ | grep -v "<"

# Buscar "debe ser único" sin constraint UNIQUE
grep -rniE "único|unique" spec/ | grep -v "UNIQUE\|constraint"
```

### Invariantes que Suelen Faltar

```markdown
- [ ] Unicidad de identificadores naturales (email, slug)
- [ ] Rangos de valores numéricos (score, percentage)
- [ ] Integridad referencial (FK constraints)
- [ ] Constraints temporales (start_date < end_date)
- [ ] Constraints de estado (solo ciertas transiciones válidas)
- [ ] Constraints de tenant isolation
- [ ] Constraints de soft delete (no eliminar si tiene dependencias)
```

---

## CAT-08: Riesgos de Evolución - Detección

### Grep Patterns

```bash
# Enums hardcodeados
grep -rniE "enum|type.*=.*\|" spec/

# Valores hardcodeados
grep -rniE "= ['\"]?[a-z_]+['\"]?" spec/domain/

# Versiones de API sin estrategia
grep -rniE "/v[0-9]+/" spec/contracts/ | head -5

# Campos sin nullable strategy
grep -rniE "required.*true" spec/ | grep -v "optional"
```

### Señales de Riesgo de Evolución

```markdown
- Enum cerrado sin estado "other" o "unknown"
- ID secuencial en lugar de UUID
- Campos not null sin default
- API sin versionado
- Schemas sin additionalProperties handling
- Estados sin transición a "deprecated" o "archived"
```

---

## CAT-09: Decisiones Sin ADR - Detección

### Grep Patterns

```bash
# Tecnologías mencionadas sin ADR
TECHS="R2|D1|KV|Workers|Cloudflare|Redis|PostgreSQL|MongoDB|JWT|OAuth"
grep -rniE "$TECHS" spec/ | grep -v "adr/"

# Patrones arquitectónicos sin justificación
grep -rniE "(saga|cqrs|event.sourcing|microservic)" spec/ | grep -v "adr/"

# Decisiones de seguridad sin ADR
grep -rniE "(encryption|AES|RSA|SHA|bcrypt|argon)" spec/ | grep -v "adr/"

# Trade-offs mencionados
grep -rniE "(trade.off|compromise|alternativa)" spec/
```

### Decisiones que Requieren ADR

```markdown
- [ ] Elección de base de datos
- [ ] Elección de storage (R2, S3, etc.)
- [ ] Estrategia de autenticación
- [ ] Estrategia de encriptación PII
- [ ] Modelo de multi-tenancy
- [ ] Estrategia de rate limiting
- [ ] Modelo de fallback (LLM)
- [ ] Estrategia de retry/backoff
- [ ] Formato de IDs (UUID vs sequential)
- [ ] Estrategia de versionado de API
```

---

## Scripts de Auditoría Automatizada

### Script: Buscar Todas las Ambigüedades

```bash
#!/bin/bash
# audit-ambiguities.sh

echo "=== Ambiguity Detection Report ==="
echo ""

echo "## Vague Quantifiers"
grep -rniE "(apropiado|adecuado|razonable|suficiente)" spec/ --include="*.md"

echo ""
echo "## Undefined Time"
grep -rniE "(pronto|rápido|inmediato|cuando sea posible)" spec/ --include="*.md"

echo ""
echo "## Incomplete Lists (etc.)"
grep -rniE "(etc\.|y otros|entre otros)" spec/ --include="*.md"

echo ""
echo "## Modal Verbs (should/may)"
grep -rniE "\b(debería|podría|puede que)\b" spec/ --include="*.md"
```

### Script: Validar Consistencia de Valores

```bash
#!/bin/bash
# audit-values.sh

echo "=== Value Consistency Report ==="
echo ""

echo "## All Timeouts"
grep -rniE "timeout.*[0-9]+" spec/ --include="*.md" | sort

echo ""
echo "## All Size Limits"
grep -rniE "(size|tamaño).*[0-9]+\s*(mb|kb|bytes)" spec/ --include="*.md" | sort

echo ""
echo "## All Rate Limits"
grep -rniE "rate.*[0-9]+.*(min|hour|day|sec)" spec/ --include="*.md" | sort
```

### Script: Verificar Referencias

```bash
#!/bin/bash
# audit-references.sh

echo "=== Reference Validation Report ==="
echo ""

# Extract all referenced IDs
echo "## Referenced Use Cases"
grep -rhoE "UC-[0-9]+" spec/ | sort -u | while read uc; do
  if [ ! -f "spec/use-cases/${uc}*.md" ]; then
    echo "MISSING: $uc"
  fi
done

echo ""
echo "## Referenced Workflows"
grep -rhoE "WF-[0-9]+" spec/ | sort -u | while read wf; do
  if ! ls spec/workflows/${wf}*.md 2>/dev/null; then
    echo "MISSING: $wf"
  fi
done

echo ""
echo "## Referenced ADRs"
grep -rhoE "ADR-[0-9]+" spec/ | sort -u | while read adr; do
  if ! ls spec/adr/${adr}*.md 2>/dev/null; then
    echo "MISSING: $adr"
  fi
done
```

### Script: Detectar Silencios en Workflows

```bash
#!/bin/bash
# audit-workflow-silences.sh

echo "=== Workflow Silence Detection ==="
echo ""

for wf in spec/workflows/WF-*.md; do
  echo "## Checking: $wf"

  # Check for steps without timeout
  if ! grep -q "timeout" "$wf"; then
    echo "  WARNING: No timeout found"
  fi

  # Check for missing error handling
  if ! grep -qi "error\|excep\|fail" "$wf"; then
    echo "  WARNING: No error handling found"
  fi

  # Check for missing compensation
  if ! grep -qi "compensat\|rollback\|revert" "$wf"; then
    echo "  WARNING: No compensation strategy found"
  fi

  echo ""
done
```

---

## Uso de Patrones en Auditoría

### Flujo Recomendado

```
1. Ejecutar scripts de detección automática
2. Revisar output y filtrar falsos positivos
3. Para cada hallazgo real:
   - Determinar categoría (CAT-XX)
   - Asignar severidad
   - Formular pregunta de resolución
4. Agregar al informe de auditoría
```

### Ejemplo de Uso

```bash
# Detectar todas las ambigüedades en un directorio
cd spec/
grep -rniE "(apropiado|razonable|adecuado)" . --include="*.md" > /tmp/ambiguities.txt

# Revisar manualmente y clasificar
# Para cada línea válida, crear hallazgo:
# AMB-001: {ubicación} - {problema} - {pregunta}
```

---

## Regression Detection Patterns

> Patterns for detecting regressions introduced by previous audit fixes.

### Identify Modified Files Since Last Audit

```bash
# Using git tag from last audit
git diff --name-only AUDIT-vX.Y-resolved..HEAD -- spec/

# Using date of last audit report
git log --since="YYYY-MM-DD" --name-only --pretty=format: -- spec/ | sort -u | grep -v "^$"

# Show files with their change stats
git diff --stat AUDIT-vX.Y-resolved..HEAD -- spec/
```

### Find All Documents Referencing a Modified File

```bash
# Given a modified entity file, find all documents that reference its entities
MODIFIED_FILE="domain/02-ENTITIES.md"

# Extract entity names from the modified file
ENTITIES=$(grep -oE "^### [A-Z][a-zA-Z]+" "spec/$MODIFIED_FILE" | sed 's/^### //')

# For each entity, find all documents that reference it
for entity in $ENTITIES; do
  echo "=== References to $entity ==="
  grep -rniE "\b$entity\b" spec/ --include="*.md" | grep -v "$MODIFIED_FILE"
done
```

### Verify Enum Synchronization Between Files

```bash
# Extract all enum-like definitions (TypeScript union types or markdown lists)
# from a specific document and cross-check everywhere

# Step 1: Find all enum/type definitions in domain files
grep -rniE "(type|enum|status).*=.*\|" spec/domain/ --include="*.md"

# Step 2: For a specific enum value, verify it appears consistently
ENUM_VALUE="selection_started"
echo "=== Occurrences of '$ENUM_VALUE' ==="
grep -rni "$ENUM_VALUE" spec/ --include="*.md"

# Step 3: Compare enum values between two files
# Extract values from file A
grep -oE "'[a-z_]+'" spec/domain/04-STATES.md | sort -u > /tmp/states-a.txt
# Extract values from file B
grep -oE "'[a-z_]+'" spec/domain/03-VALUE-OBJECTS.md | sort -u > /tmp/states-b.txt
# Find differences
diff /tmp/states-a.txt /tmp/states-b.txt
```

### Detect High-Coupling Document Drift

```bash
# Check if high-coupling documents were modified together
# These document groups should always be updated atomically

echo "=== Domain Core (should change together) ==="
git log --oneline --since="YYYY-MM-DD" -- \
  spec/domain/02-ENTITIES.md \
  spec/domain/03-VALUE-OBJECTS.md \
  spec/domain/04-STATES.md \
  spec/domain/05-INVARIANTS.md

echo ""
echo "=== Permissions Hub (should change together) ==="
git log --oneline --since="YYYY-MM-DD" -- \
  spec/contracts/PERMISSIONS-MATRIX.md \
  spec/contracts/API-*.md

echo ""
echo "=== Business Rules (should change together) ==="
git log --oneline --since="YYYY-MM-DD" -- \
  spec/CLARIFICATIONS.md \
  spec/use-cases/
```

### Script: Full Regression Scan

```bash
#!/bin/bash
# audit-regression.sh
# Run after fixes to detect regressions

LAST_AUDIT_TAG="${1:-AUDIT-v8.0-resolved}"

echo "=== Regression Scan (since $LAST_AUDIT_TAG) ==="
echo ""

# 1. List all modified spec files
echo "## Modified Files"
MODIFIED=$(git diff --name-only "$LAST_AUDIT_TAG"..HEAD -- spec/ 2>/dev/null)
if [ -z "$MODIFIED" ]; then
  echo "No files modified since $LAST_AUDIT_TAG"
  exit 0
fi
echo "$MODIFIED"
echo ""

# 2. Check enum consistency
echo "## Enum Sync Check"
for file in $MODIFIED; do
  if echo "$file" | grep -qE "(ENTITIES|VALUE-OBJECTS|STATES)"; then
    echo "  HIGH-COUPLING file modified: $file"
    echo "  Checking dependents..."
    # Extract key terms and search for them
    grep -oE "^### [A-Z][a-zA-Z]+" "$file" 2>/dev/null | sed 's/^### //' | while read term; do
      REFS=$(grep -rl "$term" spec/ --include="*.md" 2>/dev/null | grep -v "$file" | wc -l)
      echo "    $term: referenced in $REFS other files"
    done
  fi
done
echo ""

# 3. Check for orphaned references
echo "## Orphaned Reference Check"
grep -rhoE "INV-[A-Z]+-[0-9]+" spec/ --include="*.md" 2>/dev/null | sort -u | while read inv; do
  if ! grep -q "$inv" spec/domain/05-INVARIANTS.md 2>/dev/null; then
    echo "  ORPHAN: $inv referenced but not defined in INVARIANTS.md"
  fi
done
```
