# Security Checklists

> Checklists de seguridad para auditoría sistemática basados en SWEBOK v4 y OWASP ASVS v4.
> Complementa los audit-checklists de `sdd-spec-auditor` con enfoque exclusivo en seguridad.

---

## 1. SWEBOK v4 Security Checklists

### Ch01 - Software Requirements (Security Requirements)

```markdown
- [ ] ¿Los requisitos de seguridad están separados de requisitos funcionales?
- [ ] ¿Cada requisito de seguridad tiene ID trazable (REQ-SEC-NNN)?
- [ ] ¿Los requisitos cubren: confidencialidad, integridad, disponibilidad?
- [ ] ¿Los requisitos incluyen requisitos negativos (lo que el sistema NO debe hacer)?
- [ ] ¿Hay requisitos para cada regulación aplicable (GDPR, etc.)?
- [ ] ¿Los requisitos de seguridad son verificables (testeable, medible)?
```

### Ch02 - Software Design (Security Architecture)

```markdown
- [ ] ¿La arquitectura identifica trust boundaries?
- [ ] ¿Hay separation of concerns para security (no inline en business logic)?
- [ ] ¿Defense-in-depth documentado (múltiples capas)?
- [ ] ¿Least privilege documentado por rol?
- [ ] ¿Fail-secure definido (qué pasa cuando falla un control)?
- [ ] ¿Security patterns documentados en ADRs?
```

### Ch04 - Software Testing (Security Testing)

```markdown
- [ ] ¿Hay tests de seguridad separados de tests funcionales?
- [ ] ¿Tests negativos para auth (401, 403)?
- [ ] ¿Tests de boundary (input validation)?
- [ ] ¿Tests de autorización (wrong role, wrong tenant)?
- [ ] ¿Tests de encryption (roundtrip, key rotation)?
- [ ] ¿Property-based tests para invariantes de seguridad?
- [ ] ¿BDD scenarios para GDPR flows?
```

### Ch08 - Software Quality (Security Quality Attributes)

```markdown
- [ ] ¿Confidencialidad: datos clasificados con niveles de protección?
- [ ] ¿Integridad: checksums/hashes para datos críticos?
- [ ] ¿Disponibilidad: rate limits y circuit breakers especificados?
- [ ] ¿Auditabilidad: audit trail para operaciones sensibles?
- [ ] ¿Non-repudiation: acciones críticas con evidencia inmutable?
```

### Ch10 - Software Maintenance (Security Maintenance)

```markdown
- [ ] ¿Key rotation procedure documentado?
- [ ] ¿Dependency update policy para security patches?
- [ ] ¿Incident response runbooks actualizados?
- [ ] ¿Security audit schedule definido?
- [ ] ¿Vulnerability disclosure policy?
```

### Ch12 - Software Engineering Economics (Security Cost)

```markdown
- [ ] ¿Cost of breach estimado (motivación para controles)?
- [ ] ¿Security controls priorizados por riesgo?
- [ ] ¿Trade-offs documentados (security vs UX, security vs performance)?
```

---

## 2. OWASP ASVS v4 Verification Map

### V1: Architecture, Design and Threat Modeling

| Item | Verificación | Doc a Revisar |
|------|-------------|---------------|
| V1.1.1 | ¿Threat model existe? | adr/, SECURITY.md |
| V1.1.2 | ¿Threat model actualizado? | Changelog dates |
| V1.2.1 | ¿Auth controles centralizados? | SECURITY.md, contracts/ |
| V1.4.1 | ¿Trust boundaries definidos? | 01-SYSTEM-CONTEXT.md |
| V1.5.1 | ¿Input validation centralizada? | contracts/, domain/ |
| V1.6.1 | ¿Crypto servicios centralizados? | ADR-002, SECURITY.md |
| V1.11.1 | ¿Security events definidos? | SECURITY.md sección 10 |

### V2: Authentication

| Item | Verificación | Doc a Revisar |
|------|-------------|---------------|
| V2.1.1 | ¿Password min length ≥ 8? | SECURITY.md |
| V2.1.7 | ¿Password breach check? | SECURITY.md |
| V2.2.1 | ¿Anti-automation en login? | SECURITY.md, LIMITS.md |
| V2.3.1 | ¿MFA disponible? | SECURITY.md REQ-SEC-002 |
| V2.5.1 | ¿Password recovery seguro? | UCs, SECURITY.md |
| V2.7.1 | ¿Credential stuffing protection? | Rate limiting, lockout |
| V2.8.1 | ¿Session tokens con entropy? | SECURITY.md |
| V2.9.1 | ¿Token revocation? | SECURITY.md |

### V4: Access Control

| Item | Verificación | Doc a Revisar |
|------|-------------|---------------|
| V4.1.1 | ¿Deny-by-default? | PERMISSIONS-MATRIX |
| V4.1.2 | ¿Trusted enforcement point? | contracts/, SECURITY.md |
| V4.1.3 | ¿Fail securely (deny on error)? | SECURITY.md |
| V4.2.1 | ¿Data belongs to user verified? | INV tenant isolation |
| V4.2.2 | ¿IDOR protection? | INV, contracts/ |
| V4.3.1 | ¿Admin functions protected? | PERMISSIONS-MATRIX |

### V5: Validation, Sanitization

| Item | Verificación | Doc a Revisar |
|------|-------------|---------------|
| V5.1.1 | ¿Input validation defined? | UC inputs, contracts/ |
| V5.1.3 | ¿Structured data validated? | Schemas, Zod specs |
| V5.2.1 | ¿HTML sanitization? | UC text fields |
| V5.3.1 | ¿SQL injection prevented? | contracts/, ADR |
| V5.5.1 | ¿Upload file type validated? | UC upload, LIMITS.md |

### V6: Cryptography

| Item | Verificación | Doc a Revisar |
|------|-------------|---------------|
| V6.1.1 | ¿Data classification exists? | SECURITY.md, ENTITIES |
| V6.2.1 | ¿Approved algorithms only? | SECURITY.md, ADR-002 |
| V6.2.5 | ¿AES-GCM or equivalent AEAD? | SECURITY.md, ADR-002 |
| V6.3.1 | ¿Random values from CSPRNG? | SECURITY.md |
| V6.4.1 | ¿Key management lifecycle? | ADR-002, runbooks |

### V7: Error Handling and Logging

| Item | Verificación | Doc a Revisar |
|------|-------------|---------------|
| V7.1.1 | ¿Generic error messages to user? | contracts/ (error specs) |
| V7.1.2 | ¿No stack traces in production? | NFR, contracts/ |
| V7.2.1 | ¿Security events logged? | SECURITY.md sección 10 |
| V7.2.2 | ¿Auth events logged? | SECURITY.md |
| V7.3.1 | ¿Log injection prevented? | SECURITY.md |
| V7.4.1 | ¿Time sync for logs? | NFR, SECURITY.md |

### V8: Data Protection

| Item | Verificación | Doc a Revisar |
|------|-------------|---------------|
| V8.1.1 | ¿PII identified and classified? | ENTITIES, SECURITY.md |
| V8.2.1 | ¿Sensitive data not in URL params? | contracts/ |
| V8.3.1 | ¿Sensitive data encrypted at rest? | SECURITY.md, ADR-002 |
| V8.3.4 | ¿PII removable per GDPR? | UCs GDPR, ADR-008 |

---

## 3. Per-Document Security Checklists

### Checklist: SECURITY.md

```markdown
### Structure
- [ ] ¿Sección de Autenticación completa?
- [ ] ¿Sección de Autorización completa?
- [ ] ¿Sección de Encriptación completa?
- [ ] ¿Sección de Audit/Logging completa?
- [ ] ¿Sección de Incident Response completa?
- [ ] ¿Taxonomía de Security Events?

### Authentication (Sección 1)
- [ ] ¿Método primario especificado con parámetros?
- [ ] ¿Método alternativo (OAuth/SSO)?
- [ ] ¿Hash algorithm con cost factor?
- [ ] ¿JWT claims y expiración?
- [ ] ¿Refresh token rotación?
- [ ] ¿MFA especificación y recovery?
- [ ] ¿Account lockout policy?
- [ ] ¿Internal auth (worker-to-worker)?
- [ ] ¿SSO/OIDC con PKCE?

### Authorization (Sección 2-3)
- [ ] ¿Roles definidos con scope?
- [ ] ¿Referencia a PERMISSIONS-MATRIX?
- [ ] ¿Tenant isolation mechanism?
- [ ] ¿Super admin restrictions?

### Encryption (Sección 4-6)
- [ ] ¿Algorithm explicit (AES-256-GCM)?
- [ ] ¿Key source (CSPRNG)?
- [ ] ¿IV uniqueness guarantee?
- [ ] ¿Key rotation policy?
- [ ] ¿Key recovery procedure?
- [ ] ¿Encrypted fields list?

### Security Events (Sección 10)
- [ ] ¿Taxonomía con tipos enumerados?
- [ ] ¿Severity mapping por tipo?
- [ ] ¿Estructura de evento definida?

### Preguntas de auditoría
- ¿Hay gaps entre SECURITY.md y PERMISSIONS-MATRIX?
- ¿Los valores numéricos son consistentes con LIMITS.md?
- ¿Todos los REQ-SEC tienen invariante o ADR correspondiente?
```

### Checklist: PERMISSIONS-MATRIX.md

```markdown
### Completeness
- [ ] ¿Todos los endpoints del sistema están en la matriz?
- [ ] ¿Todos los roles del sistema están en la matriz?
- [ ] ¿Deny-by-default está documentado?
- [ ] ¿Scope qualifiers definidos (own, org, all)?

### Consistency
- [ ] ¿Los roles coinciden con domain/02-ENTITIES.md?
- [ ] ¿Los endpoints coinciden con contracts/API-*.md?
- [ ] ¿Los permisos son coherentes con UCs?

### Security
- [ ] ¿Operaciones destructivas requieren admin?
- [ ] ¿Operaciones sensibles requieren 2FA? (cross-ref SECURITY.md)
- [ ] ¿Viewer tiene solo permisos de lectura?
- [ ] ¿Super admin bypass tiene restricciones documentadas?

### Preguntas de auditoría
- ¿Hay endpoints en API contracts que no están en la matriz?
- ¿Hay roles que tienen más permisos de los necesarios?
- ¿Horizontal escalation es posible (acceder a recursos de otro tenant)?
```

### Checklist: Security ADRs

```markdown
### Format
- [ ] ¿ID, fecha, estado presentes?
- [ ] ¿Contexto explica la amenaza/riesgo?
- [ ] ¿Decisión es específica y actionable?
- [ ] ¿Alternativas con pros/cons de seguridad?
- [ ] ¿Consecuencias incluyen riesgos residuales?

### Security-specific
- [ ] ¿El ADR referencia OWASP/CWE si aplica?
- [ ] ¿Los trade-offs de seguridad están explícitos?
- [ ] ¿Hay referencia a runbook para la operación del control?
- [ ] ¿Los riesgos residuales tienen mitigación complementaria?

### Traceability
- [ ] ¿El ADR está referenciado desde SECURITY.md?
- [ ] ¿El ADR tiene REQ-SEC correspondiente?
- [ ] ¿El ADR tiene invariantes de enforcement?
```

### Checklist: Security Runbooks

```markdown
### Structure
- [ ] ¿Tiene pre-requisitos claramente definidos?
- [ ] ¿Steps numerados con verificación en cada paso?
- [ ] ¿Tiene sección de rollback?
- [ ] ¿Tiene sección de comunicación?
- [ ] ¿Tiene estimated duration?

### Content
- [ ] ¿Commands/procedures son específicos (no vagos)?
- [ ] ¿Hay verificación post-ejecución?
- [ ] ¿Personas/roles responsables identificados?
- [ ] ¿Escalation path definido?

### Coverage
- [ ] ¿Hay runbook para key rotation?
- [ ] ¿Hay runbook para key recovery/disaster?
- [ ] ¿Hay runbook para security incident response?
- [ ] ¿Hay runbook para audit trail integrity check?
- [ ] ¿Hay runbook para data breach notification?
```

### Checklist: BDD Security Tests

```markdown
### Authentication Tests
- [ ] ¿Happy path: login exitoso?
- [ ] ¿Failure: wrong password → 401?
- [ ] ¿Failure: expired token → 401?
- [ ] ¿Failure: revoked token → 401?
- [ ] ¿Lockout: N failed attempts → locked?
- [ ] ¿MFA: valid code → success?
- [ ] ¿MFA: invalid code → deny?

### Authorization Tests
- [ ] ¿Happy path: correct role → allowed?
- [ ] ¿Failure: wrong role → 403?
- [ ] ¿Failure: wrong tenant → 403?
- [ ] ¿Failure: no token → 401?
- [ ] ¿Viewer: write attempt → 403?
- [ ] ¿Recruiter: admin attempt → 403?

### Data Protection Tests
- [ ] ¿PII encrypted on storage?
- [ ] ¿PII decrypted on retrieval (authorized)?
- [ ] ¿PII redacted in logs?
- [ ] ¿PII not in error messages?

### Input Validation Tests
- [ ] ¿Invalid input → 422?
- [ ] ¿Oversized file → 413?
- [ ] ¿Wrong file type → 422?
- [ ] ¿SQL injection attempt → rejected?

### GDPR Tests
- [ ] ¿Data access request → complete export?
- [ ] ¿Data erasure request → all PII removed?
- [ ] ¿Data portability → structured format?
- [ ] ¿Processing restriction → frozen state?
- [ ] ¿Consent withdrawal → processing stops?

### Rate Limiting Tests
- [ ] ¿Burst limit exceeded → 429?
- [ ] ¿Sustained limit exceeded → 429?
- [ ] ¿Retry-After header present?
```

---

## 4. Threat Model Verification Checklist

### Per Attack Surface

```markdown
### API Surface
- [ ] ¿Todos los endpoints tienen auth?
- [ ] ¿Rate limiting en endpoints públicos?
- [ ] ¿Input validation en todos los params?
- [ ] ¿CORS policy especificada?
- [ ] ¿Content-Type enforcement?

### File Upload Surface
- [ ] ¿File type whitelist?
- [ ] ¿File size limit?
- [ ] ¿Virus/malware scan mencionado?
- [ ] ¿Storage isolation (no executable)?
- [ ] ¿Access control on stored files?

### LLM Integration Surface
- [ ] ¿Prompt injection mitigación?
- [ ] ¿Output sanitization?
- [ ] ¿Cost control (token limits)?
- [ ] ¿Fallback when LLM unavailable?
- [ ] ¿PII not sent to external LLM?

### SSO/OAuth Surface
- [ ] ¿PKCE para auth code flow?
- [ ] ¿State parameter para CSRF?
- [ ] ¿Nonce validation?
- [ ] ¿Token validation (signature, audience, issuer)?
- [ ] ¿Account linking policy?

### Internal Communication Surface
- [ ] ¿Worker-to-worker auth?
- [ ] ¿Timing-safe comparison?
- [ ] ¿Secret rotation policy?
- [ ] ¿Network segmentation?
```

---

## 5. Security Posture Quick Assessment

### Rapid Assessment (5 min)

Use this for a quick security posture check:

```markdown
1. [ ] ¿Existe SECURITY.md con secciones de auth, authz, crypto, audit?
2. [ ] ¿Existe PERMISSIONS-MATRIX.md con todos los roles y endpoints?
3. [ ] ¿Existen ADRs para encryption (ADR-002), GDPR (ADR-008)?
4. [ ] ¿Existen runbooks para key rotation y recovery?
5. [ ] ¿Existen BDD tests con scenarios de auth failure y authz denial?
6. [ ] ¿Los campos PII están marcados en ENTITIES.md?
7. [ ] ¿Hay INV-SEC e INV-PII en INVARIANTS.md?
8. [ ] ¿Hay REQ-SEC requirements en SECURITY.md?
9. [ ] ¿GDPR UCs existen (access, erasure, portability, restriction)?
10. [ ] ¿Security event taxonomy está definida?

Score: {count}/10
- 9-10: Proceed to full audit (likely A-B grade)
- 6-8: Moderate gaps expected (likely B-C grade)
- 3-5: Significant gaps (likely C-D grade)
- 0-2: Major security spec work needed (likely D-F grade)
```
