---
name: sdd-security-auditor
description: This skill should be used when auditing the security posture of technical specifications. Performs systematic security analysis based on OWASP ASVS v4, CWE, and SWEBOK v4 to detect missing threat models, incomplete authentication/authorization specs, unprotected data, weak cryptography, missing input validation, incomplete incident response, regulatory compliance gaps, absent security tests, and undocumented security decisions. Generates a Security Posture Scorecard with 10 dimensions and detailed findings with OWASP/CWE references. Complements sdd-spec-auditor (quality) with security-focused analysis. Does NOT propose implementations or assume unspecified behavior.
version: "1.0.0"
---

# SDD Security Auditor Skill

> **Principio:** Auditar seguridad es validar que cada amenaza tiene mitigación especificada.
> No se propone implementación. No se asume comportamiento no especificado.

## Purpose

Evaluar la postura de seguridad de especificaciones técnicas mediante análisis sistemático de amenazas, controles y compliance, generando un Security Posture Scorecard y hallazgos con referencias OWASP ASVS / CWE.

## When to Use This Skill

Use this skill when:
- Evaluating the security posture of a specification repository
- Preparing for compliance audits (SOC2, GDPR, ISO 27001)
- Validating that security requirements cover the full threat surface
- Reviewing security-related specs after major changes
- Assessing security test coverage of specifications
- Verifying traceability of security decisions (REQ→INV→ADR→BDD)

## Relationship to Other Skills

| Skill | Focus | Complementary |
|-------|-------|--------------|
| `sdd-spec-auditor` | Quality general (ambigüedades, contradicciones, silencios) | Security auditor NO repite hallazgos de calidad general |
| `sdd-security-auditor` | **Postura de seguridad** (amenazas, auth, crypto, compliance) | Solo hallazgos de seguridad con OWASP/CWE |
| `sdd-spec-auditor` (Mode Fix) | Corrección de hallazgos | Los hallazgos de security se corrigen con Mode Fix del spec-auditor (formato compatible) |
| `sdd-requirements-engineer` | Derivación de requisitos | Valida que REQ-SEC cubran la superficie de amenazas |

---

## Core Principles

### 1. Threat-Driven Analysis

```
❌ "La seguridad podría mejorarse"
❌ "Se recomienda agregar validación"
❌ "Buena práctica es usar X"

✅ "Amenaza: {atacante} puede {acción} porque {gap en spec}"
✅ "No hay mitigación especificada para {amenaza}"
✅ "Pregunta: ¿Qué debe ocurrir cuando {escenario de ataque}?"
```

### 2. Evidence-Based Findings

```
Cada hallazgo DEBE incluir:
- Referencia OWASP ASVS v4 (sección)
- Referencia CWE (ID)
- Amenaza concreta que explota el gap
- Evidencia de 2+ documentos
```

### 3. No Implementation, No Assumptions

```
❌ "Se debería implementar WAF"
❌ "Usar AES-256-GCM para esto"
❌ "Agregar este middleware"

✅ "No está especificado el algoritmo de encriptación para {campo}"
✅ "Falta especificar el mecanismo de rate limiting para {endpoint}"
✅ "Pregunta: ¿Qué controles mitigan {amenaza} en {superficie}?"
```

---

## Security Defect Categories

### SEC-CAT-01: Amenazas Sin Modelo (THR-)

Superficies de ataque no cubiertas por threat model.

**OWASP ASVS:** V1 Architecture, Design, Threat Modeling
**Señales:**
- Endpoints expuestos sin análisis de amenazas
- Flujos de datos sin clasificación de sensibilidad
- Integraciones externas sin trust boundary
- Actores sin perfil de amenaza

**Ejemplo:**
```markdown
#### THR-001: Superficie de API pública sin threat model

| Campo | Valor |
|-------|-------|
| **Severidad** | Alto |
| **Estado** | new |
| **Categoría** | SEC-CAT-01: Amenazas Sin Modelo |
| **OWASP ASVS** | V1.1 |
| **CWE** | CWE-1053 |
| **Ubicación** | contracts/API-extraction.md:endpoints |
| **Amenaza** | Atacante puede descubrir endpoints no protegidos |
| **Problema** | 15 endpoints expuestos sin threat model documentado |
| **Pregunta** | ¿Existe threat model para la superficie API? ¿Dónde? |
| **Docs relacionados** | nfr/SECURITY.md, contracts/ |
| **Mitigación existente** | Parcial: rate limiting en ADR-025 |
```

---

### SEC-CAT-02: Autenticación Incompleta (AUTH-)

Gaps en especificación de autenticación.

**OWASP ASVS:** V2 Authentication
**Señales:**
- Endpoints sin requisito de autenticación
- Flujos de login sin protección contra brute force
- Token management incompleto (refresh, revocación, blacklist)
- MFA sin especificación de recovery
- Session management sin timeout/invalidación

---

### SEC-CAT-03: Autorización Insuficiente (AUTHZ-)

Gaps en especificación de autorización y control de acceso.

**OWASP ASVS:** V4 Access Control
**Señales:**
- Endpoints sin permiso en PERMISSIONS-MATRIX
- Operaciones sin verificación de tenant isolation
- Escalación de privilegios no cubierta
- RBAC incompleto (roles sin scope de operaciones)
- Row-level security no especificado

---

### SEC-CAT-04: Datos Sin Protección (DATA-)

PII u otros datos sensibles sin controles de protección especificados.

**OWASP ASVS:** V6 Cryptography, V8 Data Protection
**Señales:**
- Campos PII sin marcador de encriptación
- Datos sensibles en logs o error messages
- Datos en tránsito sin TLS especificado
- Datos at rest sin encryption policy
- Datos compartidos entre tenants sin isolation

---

### SEC-CAT-05: Validación de Entrada Ausente (INPUT-)

Entradas del sistema sin validación de seguridad especificada.

**OWASP ASVS:** V5 Validation, Sanitization
**Señales:**
- Inputs de usuario sin schema de validación
- File uploads sin restricción de tipo/tamaño
- Parámetros de URL sin sanitización
- Queries sin protección contra injection
- Campos de texto libre sin límite de longitud

---

### SEC-CAT-06: Criptografía Débil o Incompleta (CRYPTO-)

Especificaciones criptográficas débiles, incompletas o ausentes.

**OWASP ASVS:** V6 Cryptography
**Señales:**
- Algoritmos no especificados o deprecados
- Key management sin lifecycle (generación, rotación, destrucción)
- IV/nonce reutilización no prevenida
- Key derivation sin especificación
- Encryption sin integridad (confidencialidad sin autenticación)

---

### SEC-CAT-07: Respuesta a Incidentes Incompleta (INCIDENT-)

Gaps en especificación de detección, respuesta y recuperación.

**OWASP ASVS:** V7 Error Handling and Logging
**Señales:**
- Security events sin taxonomía
- Alertas sin threshold o escalación
- Incidentes sin runbook
- Logs sin retención especificada
- Audit trail incompleto

---

### SEC-CAT-08: Compliance Regulatorio Incompleto (COMPLY-)

Requisitos regulatorios (GDPR, etc.) con gaps en especificación.

**OWASP ASVS:** N/A (Regulatorio)
**Referencia:** GDPR Art. 5-34
**Señales:**
- Derechos GDPR sin UC o mecanismo
- Consentimiento sin especificación de recolección/revocación
- Data retention sin política o sin enforcement
- Cross-border data transfer sin justificación
- DPO/DPA sin referencia

---

### SEC-CAT-09: Tests de Seguridad Ausentes (STEST-)

Pruebas de seguridad no especificadas en BDD/property tests.

**SWEBOK v4:** Ch08 Software Testing
**Señales:**
- Security requirements sin BDD scenario
- Flujos de autorización sin test negativo
- Input validation sin property tests
- Encryption sin test de correctitud
- GDPR flows sin test de compliance

---

### SEC-CAT-10: Decisiones de Seguridad Sin ADR (SADR-)

Decisiones de seguridad tomadas sin documentación formal.

**OWASP ASVS:** V1 Architecture
**Señales:**
- Algoritmos criptográficos elegidos sin ADR
- Estrategia de auth sin ADR
- Trust boundaries sin justificación
- Security trade-offs no documentados

---

## Security Posture Scorecard

### 10 Dimensiones

| # | Dimensión | Peso | Descripción |
|---|-----------|------|-------------|
| D1 | Authentication Completeness | 15% | Todos los flujos de auth especificados y protegidos |
| D2 | Authorization Completeness | 15% | RBAC + tenant isolation + row-level security |
| D3 | Data Protection | 15% | PII encriptado, at-rest + in-transit + key mgmt |
| D4 | Input Validation | 10% | Todos los inputs con schema y validación |
| D5 | Cryptographic Rigor | 10% | Algoritmos, key lifecycle, IV uniqueness |
| D6 | Incident Readiness | 10% | Detección, escalación, runbooks, audit trail |
| D7 | Regulatory Compliance | 10% | GDPR derechos, consentimiento, retención |
| D8 | Security Test Coverage | 5% | BDD/property tests para security requirements |
| D9 | Threat Model Coverage | 5% | Superficies mapeadas con mitigaciones |
| D10 | Security Decision Documentation | 5% | ADRs para decisiones de seguridad |

### Fórmula de Score por Dimensión

```
Score(D) = max(0, 100 - (critical_findings * 25) - (high_findings * 15) - (medium_findings * 5) - (low_findings * 2))
```

### Score Global

```
Global = Σ (Score(Di) * Weight(Di))
```

### Grados

| Grado | Rango | Significado |
|-------|-------|-------------|
| **A** | 90-100 | Postura de seguridad sólida. Gaps menores. |
| **B** | 75-89 | Buena postura. Algunos gaps medios a remediar. |
| **C** | 50-74 | Postura aceptable. Gaps significativos requieren atención. |
| **D** | 25-49 | Postura débil. Múltiples gaps críticos o altos. |
| **F** | 0-24 | Postura inaceptable. Requiere rediseño de seguridad. |

---

## Audit Process

### Phase 0: Security Baseline Loading

Before starting the audit, check for an existing security audit baseline.

1. **Search for baseline file:** Look for `SECURITY-AUDIT-BASELINE.md` in the audits directory
2. **If baseline exists:**
   - Load all findings with status `accepted`, `wont_fix`, or `deferred`
   - These findings are **excluded** from the report (NOT re-reported)
   - Track in "Excluded by Baseline" counter
   - For `deferred` findings: check `Re-evaluar en` date — if past due, re-report
3. **If no baseline exists:**
   - Proceed normally (first security audit)
   - Note: "No security baseline found — all findings are new"
4. **Load previous security audit report** (if any) to classify findings as `new`, `persistent`, or `regression`

---

### Phase 1: Security Spec Inventory

Inventariar todos los documentos relacionados con seguridad:

1. **Core security docs:**
   - `nfr/SECURITY.md` — Requisitos de seguridad
   - `contracts/PERMISSIONS-MATRIX.md` — Matriz de permisos
   - Security-related ADRs (encryption, auth, GDPR)
   - Runbooks de seguridad (key rotation, recovery, audit integrity)

2. **Security-touching docs:**
   - All API contracts (auth requirement per endpoint)
   - All UCs with authorization/PII handling
   - Domain model (PII fields, security entities)
   - BDD tests with security scenarios
   - Requirements with REQ-SEC prefix

3. **Output:** Complete security spec inventory with document count and coverage assessment

---

### Phase 2: Threat Surface Mapping

Mapear las superficies de ataque del sistema:

1. **API Surface:**
   - List all endpoints from contracts/
   - Classify: public, authenticated, admin-only
   - Map auth requirements per endpoint

2. **Data Surface:**
   - List all PII fields from domain model
   - Map encryption requirements per field
   - Identify data flows (input → storage → output)

3. **Integration Surface:**
   - External services (LLM APIs, OAuth providers, SSO)
   - Worker-to-Worker communication
   - File upload/download flows

4. **Trust Boundaries:**
   - Client → API
   - API → Storage
   - Worker → Worker
   - API → External Services

---

### Phase 3: Coverage Analysis

Para cada amenaza identificada, verificar que existe mitigación especificada:

1. **Authentication Coverage:**
   - Every endpoint has auth requirement? → PERMISSIONS-MATRIX
   - Brute force protection? → SECURITY.md
   - Token lifecycle complete? → SECURITY.md
   - MFA for sensitive ops? → SECURITY.md

2. **Authorization Coverage:**
   - Every endpoint has role requirement? → PERMISSIONS-MATRIX
   - Tenant isolation specified? → INVARIANTS
   - Row-level security? → INVARIANTS

3. **Data Protection Coverage:**
   - Every PII field has encryption? → SECURITY.md + ENTITIES
   - Key rotation specified? → ADR + runbook
   - Data retention policy? → INVARIANTS + GDPR

4. **Input Validation Coverage:**
   - Every UC input has schema? → UC files
   - File upload restrictions? → LIMITS + UC
   - API param validation? → Contracts

---

### Phase 4: Depth Analysis

Para cada spec de seguridad, verificar completitud interna:

1. **SECURITY.md depth:**
   - Auth section: method, hash, session, refresh, MFA, lockout
   - Authz section: RBAC, matrix ref, tenant isolation
   - Crypto section: algorithms, key mgmt, rotation, IV
   - Audit section: events, retention, format
   - Incident section: detection, response, recovery

2. **PERMISSIONS-MATRIX depth:**
   - Every role has defined permissions
   - Every endpoint is in the matrix
   - Deny-by-default is specified
   - Scope qualifiers (own, org, global)

3. **Security ADRs depth:**
   - Context explains threat
   - Decision specifies control
   - Alternatives considered
   - Consequences include security trade-offs

4. **Runbooks depth:**
   - Pre-requisites defined
   - Step-by-step with verification
   - Rollback procedure
   - Communication plan

---

### Phase 5: Traceability Verification

Verificar la cadena de trazabilidad de seguridad:

```
REQ-SEC → INV-SEC/INV-PII → ADR → UC (security flow) → BDD (security scenario) → Runbook
```

1. **Forward trace:** Each REQ-SEC → has INV or ADR → has UC flow → has BDD test
2. **Backward trace:** Each security BDD → maps to UC → maps to REQ-SEC
3. **Gap detection:** REQ-SEC without test, INV without enforcement, ADR without runbook

---

### Phase 6: Security Posture Scorecard

Generar el scorecard de 10 dimensiones:

1. **Count findings per dimension** (each SEC-CAT maps to a dimension)
2. **Calculate score per dimension** using the formula
3. **Calculate global score** as weighted average
4. **Assign grade** (A-F)
5. **Highlight weakest dimensions** for priority remediation

**Mapping SEC-CAT → Dimension:**

| SEC-CAT | Dimension |
|---------|-----------|
| SEC-CAT-02 (AUTH-) | D1: Authentication |
| SEC-CAT-03 (AUTHZ-) | D2: Authorization |
| SEC-CAT-04 (DATA-) | D3: Data Protection |
| SEC-CAT-05 (INPUT-) | D4: Input Validation |
| SEC-CAT-06 (CRYPTO-) | D5: Cryptographic Rigor |
| SEC-CAT-07 (INCIDENT-) | D6: Incident Readiness |
| SEC-CAT-08 (COMPLY-) | D7: Regulatory Compliance |
| SEC-CAT-09 (STEST-) | D8: Security Test Coverage |
| SEC-CAT-01 (THR-) | D9: Threat Model Coverage |
| SEC-CAT-10 (SADR-) | D10: Security Decision Documentation |

---

### Phase 7: Report Generation

Generar informe final con todos los componentes.

---

## Finding Format

```markdown
#### {PREFIX}-{NNN}: {Título}

| Campo | Valor |
|-------|-------|
| **Severidad** | Crítico / Alto / Medio / Bajo |
| **Estado** | new / persistent / regression |
| **Categoría** | SEC-CAT-{NN}: {nombre} |
| **OWASP ASVS** | V{N}.{N} |
| **CWE** | CWE-{NNN} |
| **Ubicación** | {documento}:{sección} |
| **Amenaza** | {qué podría salir mal} |
| **Problema** | {descripción del defecto en la spec} |
| **Pregunta** | {pregunta para resolver el gap} |
| **Docs relacionados** | {lista} |
| **Mitigación existente** | {parcial si aplica, o "ninguna"} |
```

---

## Severity Classification

| Severidad | Criterio | OWASP Risk |
|-----------|----------|------------|
| **Crítico** | Amenaza explotable sin mitigación especificada. Datos PII expuestos. Auth bypass posible. | Critical |
| **Alto** | Control parcialmente especificado. Gap explotable bajo condiciones. | High |
| **Medio** | Control especificado pero incompleto. Defense-in-depth faltante. | Medium |
| **Bajo** | Mejora de postura sin amenaza inmediata. Documentación de seguridad faltante. | Low |

### Signal Filters

Apply these filters BEFORE assigning severity to reduce noise:

1. **Threat requirement:** Only report findings with a concrete threat scenario. "Could be more secure" is NOT a valid finding.

2. **Evidence from 2+ docs:** A finding based on a single document and subjective interpretation is NOT valid. Cross-reference required.

3. **Respect security ADRs:** If a security decision is documented in an ADR with trade-off analysis, it is NOT a defect — even if a "better" approach exists.

4. **Respect existing mitigations:** If a mitigation exists but is partial, classify as Medium (not Critical). Note the existing mitigation in the finding.

5. **Implementation-blocking test:**
   ```
   Does this security gap block safe implementation?
   ├── YES → Crítico or Alto
   │   ├── PII exposure or auth bypass? → Crítico
   │   └── Exploitable but mitigated partially? → Alto
   └── NO → Medio or Bajo
       ├── Defense-in-depth gap? → Medio
       └── Documentation/testing gap only? → Bajo
   ```

---

## Audit Report Format

```markdown
# Security Audit Report: {Repository Name}

> **Fecha:** YYYY-MM-DD
> **Auditor:** SDD Security Auditor
> **Versión specs auditada:** X.Y.Z
> **Documentos de seguridad analizados:** {N}
> **Total documentos analizados:** {N}

---

## Security Posture Scorecard

| # | Dimensión | Score | Grado | Hallazgos (C/H/M/L) |
|---|-----------|-------|-------|---------------------|
| D1 | Authentication Completeness | {0-100} | {A-F} | {N}/{N}/{N}/{N} |
| D2 | Authorization Completeness | {0-100} | {A-F} | {N}/{N}/{N}/{N} |
| D3 | Data Protection | {0-100} | {A-F} | {N}/{N}/{N}/{N} |
| D4 | Input Validation | {0-100} | {A-F} | {N}/{N}/{N}/{N} |
| D5 | Cryptographic Rigor | {0-100} | {A-F} | {N}/{N}/{N}/{N} |
| D6 | Incident Readiness | {0-100} | {A-F} | {N}/{N}/{N}/{N} |
| D7 | Regulatory Compliance | {0-100} | {A-F} | {N}/{N}/{N}/{N} |
| D8 | Security Test Coverage | {0-100} | {A-F} | {N}/{N}/{N}/{N} |
| D9 | Threat Model Coverage | {0-100} | {A-F} | {N}/{N}/{N}/{N} |
| D10 | Security Decision Docs | {0-100} | {A-F} | {N}/{N}/{N}/{N} |
| **GLOBAL** | **Weighted Average** | **{0-100}** | **{A-F}** | **{N}/{N}/{N}/{N}** |

---

## Resumen Ejecutivo

| Categoría | Hallazgos | Críticos | Altos | Medios | Bajos |
|-----------|-----------|----------|-------|--------|-------|
| SEC-CAT-01: Amenazas Sin Modelo | {N} | {N} | {N} | {N} | {N} |
| SEC-CAT-02: Autenticación Incompleta | {N} | {N} | {N} | {N} | {N} |
| SEC-CAT-03: Autorización Insuficiente | {N} | {N} | {N} | {N} | {N} |
| SEC-CAT-04: Datos Sin Protección | {N} | {N} | {N} | {N} | {N} |
| SEC-CAT-05: Validación de Entrada | {N} | {N} | {N} | {N} | {N} |
| SEC-CAT-06: Criptografía Incompleta | {N} | {N} | {N} | {N} | {N} |
| SEC-CAT-07: Respuesta Incidentes | {N} | {N} | {N} | {N} | {N} |
| SEC-CAT-08: Compliance Regulatorio | {N} | {N} | {N} | {N} | {N} |
| SEC-CAT-09: Tests de Seguridad | {N} | {N} | {N} | {N} | {N} |
| SEC-CAT-10: Decisiones Sin ADR | {N} | {N} | {N} | {N} | {N} |
| **TOTAL** | **{N}** | **{N}** | **{N}** | **{N}** | **{N}** |

---

## Baseline Delta

> Compared against: {previous security audit ID or "N/A (first audit)"}

| Métrica | Cantidad |
|---------|----------|
| Hallazgos nuevos (new) | {N} |
| Hallazgos persistentes (persistent) | {N} |
| Hallazgos de regresión (regression) | {N} |
| Hallazgos resueltos desde último audit | {N} |
| Hallazgos excluidos por baseline | {N} |

---

## Threat Surface Summary

| Superficie | Elementos | Cubiertos | Sin cobertura |
|-----------|-----------|-----------|---------------|
| API Endpoints | {N} | {N} | {N} |
| PII Fields | {N} | {N} | {N} |
| External Integrations | {N} | {N} | {N} |
| Trust Boundaries | {N} | {N} | {N} |

---

## Traceability Summary

| Cadena | Total | Completas | Incompletas |
|--------|-------|-----------|-------------|
| REQ-SEC → INV → ADR | {N} | {N} | {N} |
| REQ-SEC → UC → BDD | {N} | {N} | {N} |
| Security ADR → Runbook | {N} | {N} | {N} |

---

## Hallazgos por Categoría

### SEC-CAT-01: Amenazas Sin Modelo

#### THR-001: {Título}

| Campo | Valor |
|-------|-------|
| **Severidad** | {valor} |
| **Estado** | {new/persistent/regression} |
| **Categoría** | SEC-CAT-01: Amenazas Sin Modelo |
| **OWASP ASVS** | V{N}.{N} |
| **CWE** | CWE-{NNN} |
| **Ubicación** | {documento}:{sección} |
| **Amenaza** | {qué podría salir mal} |
| **Problema** | {descripción} |
| **Pregunta** | {pregunta} |
| **Docs relacionados** | {lista} |
| **Mitigación existente** | {parcial/ninguna} |

{...más hallazgos...}

---

## Hallazgos Excluidos por Baseline

> {N} hallazgos excluidos: {N} accepted, {N} wont_fix, {N} deferred

---

## Recomendaciones de Priorización

1. **Críticos (resolver antes de implementar):**
   - {ID}: {Título} — {Amenaza}

2. **Altos (resolver en sprint actual):**
   - {ID}: {Título} — {Amenaza}

3. **Medios (backlog priorizado):**
   - {ID}: {Título}

4. **Bajos (mejora continua):**
   - {ID}: {Título}
```

---

## Multi-Agent Protocol

### 4 Security Audit Agents

<!-- Security auditor uses domain-specific prefixes (AUTH, DATA, COMPLY, TEST) rather than
     the standard spec-directory prefixes (DOM-, UC-, CON-, etc.) because security agents
     are organized by security concern, not by spec directory. Each security prefix maps
     to one or more SEC-CAT categories:
       AUTH-  → SEC-CAT-02/03 (Authentication/Authorization)
       DATA-  → SEC-CAT-04/06 (Data Protection/Cryptography)
       COMPLY- → SEC-CAT-08/07 (Compliance/Incident Response)
       TEST-  → SEC-CAT-09/01/10/05 (Tests/Threats/ADRs/Input Validation)
     For the standard spec-directory prefix convention used by sdd-spec-auditor and
     sdd-req-change, see: DOM- → domain/, UC- → use-cases/, WF- → workflows/,
     CON- → contracts/, NFR- → nfr/, ADR- → adr/, TEST- → tests/, RUN- → runbooks/. -->

| Agente | Prefijos | Scope | Docs a Analizar |
|--------|----------|-------|-----------------|
| AUTH-agent | AUTH-/AUTHZ- | Authentication + Authorization | SECURITY.md (secciones 1-3), PERMISSIONS-MATRIX.md, API contracts (auth fields), UCs (auth flows), INV-ROL/INV-USR |
| DATA-agent | DATA-/CRYPTO- | Data Protection + Cryptography | SECURITY.md (secciones 4-6), ADR-002 (encryption), ENTITIES.md (PII fields), VALUE-OBJECTS.md (encrypted VOs), INV-PII/INV-SEC, runbooks (key rotation/recovery) |
| COMPLY-agent | COMPLY-/INCIDENT- | Compliance + Incident Response | SECURITY.md (secciones 7-10), ADR-008 (GDPR), UCs GDPR (UC-030 to UC-034), BDD-gdpr, CLARIFICATIONS.md (RN GDPR), runbooks (audit integrity) |
| TEST-agent | STEST-/THR-/SADR-/INPUT- | Tests + Threats + ADRs + Input Validation | All BDD-*.md, all property-tests, all security ADRs, UCs (input schemas), API contracts (param validation), LIMITS.md |

### Agent ID Prefixes

Each agent MUST use a unique prefix for finding IDs:

| Agent | ID Range | Example |
|-------|----------|---------|
| AUTH-agent | AUTH-001..099, AUTHZ-001..099 | AUTH-001, AUTHZ-015 |
| DATA-agent | DATA-001..099, CRYPTO-001..099 | DATA-003, CRYPTO-007 |
| COMPLY-agent | COMPLY-001..099, INCIDENT-001..099 | COMPLY-012, INCIDENT-004 |
| TEST-agent | STEST-001..099, THR-001..099, SADR-001..099, INPUT-001..099 | STEST-001, THR-003, INPUT-008 |

### Consolidation Process

After all agents complete:

1. **Merge all findings** into a single report
2. **Cross-reference by:** document + threat + control type
3. **Deduplication rules:**
   - Same document + same security control + same gap → keep most complete, mark `cross-validated`
   - Threshold: identical location AND identical threat = duplicate
4. **Renumber** final findings sequentially within each prefix
5. **Generate scorecard** from consolidated findings
6. **Preserve** original agent source in findings for traceability

### Cross-Validation Bonus

Findings independently detected by 2+ agents are marked `[CROSS-VALIDATED]` — highest confidence, prioritize for resolution.

---

## Audit Stability Rules

### Rule 1: No Re-Reporting Resolved Security Findings

Check `SECURITY-AUDIT-BASELINE.md` before reporting. If finding matches baseline entry with status `accepted`, `wont_fix`, or `resolved`, exclude it.

### Rule 2: Respect Security ADRs

Before flagging a security gap:
- Check `adr/` for an ADR explaining the security decision
- Check `CLARIFICATIONS.md` for a business rule
- If covered by ADR or RN → NOT a defect

### Rule 3: Precision Over Volume

```
BAD:  "Authentication could be stronger"
GOOD: "AUTH-003: UC-015 login flow lacks account lockout after failed attempts — SECURITY.md REQ-SEC-001 specifies bcrypt but no lockout policy"

BAD:  "GDPR compliance needs improvement"
GOOD: "COMPLY-005: GDPR Art. 17 right to erasure — UC-031 handles deletion but does not specify backup purge timeline (see ADR-008 section 4)"
```

Every finding MUST include:
- Exact file and section
- The specific security gap
- The threat it enables
- OWASP ASVS + CWE reference
- Evidence from 2+ documents

### Rule 4: Complementary to spec-auditor

Do NOT report findings that belong to `sdd-spec-auditor`:
- Terminology/glossary violations → spec-auditor CAT-04
- Generic ambiguities without security impact → spec-auditor CAT-01
- Missing invariant without security implication → spec-auditor CAT-07
- Only report when the gap has a **concrete security threat**

---

## Important Constraints

1. **NUNCA proponer implementación** - Solo identificar el gap de seguridad y formular pregunta
2. **NUNCA asumir comportamiento** - Si no está especificado, es un hallazgo
3. **SIEMPRE incluir referencia OWASP/CWE** - Cada hallazgo con clasificación estándar
4. **SIEMPRE indicar amenaza concreta** - No "podría ser inseguro" sino "atacante puede X"
5. **SIEMPRE cruzar documentos** - Mínimo 2 docs por hallazgo
6. **SIEMPRE generar scorecard** - Incluso si hay 0 hallazgos, reportar las 10 dimensiones
7. **NUNCA duplicar con spec-auditor** - Solo hallazgos con impacto de seguridad demostrable

---

## Persist Summary

After generating all output artifacts, update `pipeline-state.json`:

1. Read `pipeline-state.json` from project root (create if absent with default stage structure)
2. Set `stages["security-auditor"].status` = `"done"` (lateral stage — add key if absent)
3. Set `stages["security-auditor"].lastRun` = current ISO-8601
4. Set `stages["security-auditor"].summary`:
   - `artifacts`: list of files created with labels (e.g., `{"file": "audits/SECURITY-AUDIT-BASELINE.md", "label": "Security Audit Baseline"}`)
   - `metrics`: `{ "total_findings": N, "critical": N, "high": N, "medium": N, "low": N, "owasp_coverage": N }` (owasp_coverage: percentage of OWASP ASVS dimensions assessed)
   - `highlights`: top 3-5 notable observations (e.g., "1 critical: Missing CSRF on payment endpoint", "OWASP coverage: 78%")
   - `nextStep`: `"Address critical findings before implementation"` or `"No critical findings — proceed with pipeline"`
   - `generatedAt`: current ISO-8601
5. Write updated `pipeline-state.json`
6. Display summary table to user (console output)
