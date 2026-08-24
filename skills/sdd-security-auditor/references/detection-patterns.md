# Security Detection Patterns

> Patrones de búsqueda para detectar defectos de seguridad en especificaciones.
> Complementa los detection-patterns de `sdd-spec-auditor` con enfoque exclusivo en seguridad.

---

## SEC-CAT-01: Amenazas Sin Modelo (THR-)

### Grep Patterns

```bash
# Endpoints sin mención de amenaza o threat
grep -rniE "^(GET|POST|PUT|PATCH|DELETE)\s" spec/contracts/ | grep -v -i "threat\|attack\|risk"

# Integraciones externas sin trust boundary
grep -rniE "(external|tercero|third.party|proveedor)" spec/ | grep -v -i "trust\|boundary\|verificar\|validar"

# Flujos de datos sin clasificación de sensibilidad
grep -rniE "(datos|data|información)" spec/ | grep -v -i "sensib\|PII\|encrypt\|confidential\|public"
```

### Threat Surface Checklist

```markdown
Para cada superficie, verificar:
- [ ] ¿Hay threat model documentado?
- [ ] ¿Las amenazas tienen mitigación especificada?
- [ ] ¿Los trust boundaries están definidos?
- [ ] ¿Los actores de amenaza están identificados?

Superficies típicas:
- [ ] API pública (endpoints REST)
- [ ] File upload/download
- [ ] Integraciones con LLM (prompt injection)
- [ ] OAuth/SSO flows
- [ ] Worker-to-Worker (internal API)
- [ ] Admin operations
```

---

## SEC-CAT-02: Autenticación Incompleta (AUTH-)

### Grep Patterns

```bash
# Endpoints sin auth requirement
grep -rniE "^(GET|POST|PUT|PATCH|DELETE)\s" spec/contracts/ | grep -v -i "auth\|token\|bearer\|session\|JWT"

# Login sin protección brute force
grep -rniE "(login|autenticar|sign.in)" spec/ | grep -v -i "lockout\|throttl\|rate.limit\|intento"

# Token management incompleto
grep -rniE "(token|JWT|session)" spec/ | grep -v -i "expir\|refresh\|revok\|blacklist\|invalidat"

# MFA sin recovery
grep -rniE "(MFA|2FA|TOTP|multi.factor)" spec/ | grep -v -i "recover\|backup\|respaldo"

# Session sin timeout explícito
grep -rniE "sesión|session" spec/ | grep -v -i "timeout\|expir\|24h\|7d"

# Password policy gaps
grep -rniE "(password|contraseña)" spec/ | grep -v -i "hash\|bcrypt\|argon\|longitud\|length\|complex"
```

### Auth Completeness Checklist

```markdown
- [ ] ¿Método de autenticación especificado?
- [ ] ¿Hash de contraseña con algoritmo y cost factor?
- [ ] ¿JWT con expiración y claims definidos?
- [ ] ¿Refresh token con rotación obligatoria?
- [ ] ¿Account lockout después de N intentos fallidos?
- [ ] ¿MFA para operaciones sensibles?
- [ ] ¿Session invalidation en logout?
- [ ] ¿Session invalidation en cambio de password?
- [ ] ¿OAuth/SSO con PKCE?
- [ ] ¿Internal auth (worker-to-worker) con timing-safe comparison?
```

---

## SEC-CAT-03: Autorización Insuficiente (AUTHZ-)

### Grep Patterns

```bash
# Endpoints sin rol especificado
grep -rniE "^(GET|POST|PUT|PATCH|DELETE)\s" spec/contracts/ | grep -v -i "role\|permis\|admin\|recruiter\|viewer"

# Operaciones sin tenant isolation
grep -rniE "(query|SELECT|WHERE)" spec/ | grep -v -i "org_id\|tenant\|organization"

# Escalación de privilegios potencial
grep -rniE "(rol|role|promot|escalat|privilegio)" spec/ | grep -v -i "verific\|validat\|check\|permis"

# RBAC sin deny-by-default
grep -rniE "permiso|permission" spec/ | grep -v -i "deny\|prohib\|denegad"

# Missing org_id filter
grep -rniE "SELECT|query|búsqueda|search|list" spec/ | grep -v -i "org_id\|organization_id\|tenant"
```

### Authorization Checklist

```markdown
- [ ] ¿PERMISSIONS-MATRIX cubre todos los endpoints?
- [ ] ¿Deny-by-default documentado?
- [ ] ¿Tenant isolation en todas las queries?
- [ ] ¿Row-level security (own vs org vs global)?
- [ ] ¿Scope qualifiers definidos (own, org, all)?
- [ ] ¿Super admin bypass documentado con restricciones?
- [ ] ¿Horizontal privilege escalation prevenido?
- [ ] ¿Vertical privilege escalation prevenido?
```

---

## SEC-CAT-04: Datos Sin Protección (DATA-)

### Grep Patterns

```bash
# Campos PII sin encriptación
grep -rniE "(email|phone|nombre|address|dirección|dni|passport)" spec/domain/ | grep -v -i "encrypt\|cifra\|PII\|protect"

# Datos sensibles en logs
grep -rniE "(log|audit|trace|evento)" spec/ | grep -v -i "redact\|mask\|sanitiz\|exclude.PII"

# Datos en error messages
grep -rniE "(error|excep|falla)" spec/ | grep -v -i "generic\|opaque\|sin.detalle"

# Data retention sin enforcement
grep -rniE "(retention|retención|purge|eliminar)" spec/ | grep -v -i "auto\|cron\|schedul\|enforce"

# Data at rest sin encryption
grep -rniE "(storage|almacen|guardar|R2|D1)" spec/ | grep -v -i "encrypt\|cifra\|AES"
```

### Data Protection Checklist

```markdown
- [ ] ¿Todos los campos PII identificados?
- [ ] ¿Encryption at rest para PII?
- [ ] ¿Encryption in transit (TLS)?
- [ ] ¿Key management lifecycle especificado?
- [ ] ¿Data masking en logs?
- [ ] ¿Error messages no exponen datos internos?
- [ ] ¿Tenant data isolation?
- [ ] ¿Backup encryption?
- [ ] ¿Data retention con enforcement automático?
- [ ] ¿Secure deletion para GDPR Art. 17?
```

---

## SEC-CAT-05: Validación de Entrada (INPUT-)

### Grep Patterns

```bash
# Inputs sin schema
grep -rniE "^### Input" spec/use-cases/ -A 20 | grep -v -i "schema\|type\|Zod\|validat"

# File upload sin restricción
grep -rniE "(upload|subir|archivo|file)" spec/ | grep -v -i "size\|type\|mime\|extensi\|50.MB\|limit"

# Parámetros de URL sin validación
grep -rniE "path.*param|:id|:slug" spec/contracts/ | grep -v -i "UUID\|validat\|format"

# Campos de texto sin límite
grep -rniE "string|text|varchar" spec/ | grep -v -i "max\|length\|limit\|255\|1000"

# SQL/NoSQL injection surface
grep -rniE "(query|filter|search|WHERE)" spec/ | grep -v -i "parameteriz\|prepared\|sanitiz\|ORM"
```

### Input Validation Checklist

```markdown
- [ ] ¿Cada UC input tiene schema con tipos y constraints?
- [ ] ¿File uploads: tipo, tamaño, extensión validados?
- [ ] ¿Path/query params con formato especificado?
- [ ] ¿Campos de texto con longitud máxima?
- [ ] ¿Sanitización de HTML/markdown si aplica?
- [ ] ¿Rate limiting para operaciones costosas?
- [ ] ¿Protección contra ReDoS en regex?
- [ ] ¿Content-Type validation en uploads?
```

---

## SEC-CAT-06: Criptografía (CRYPTO-)

### Grep Patterns

```bash
# Algoritmos no especificados
grep -rniE "(encrypt|cifrar|hash)" spec/ | grep -v -i "AES\|RSA\|SHA\|bcrypt\|argon\|GCM\|256"

# Key rotation sin periodicidad
grep -rniE "(key.*rotation|rotación.*clave)" spec/ | grep -v -i "trimestral\|annual\|monthly\|quarterly\|90.d"

# IV/nonce sin unicidad
grep -rniE "(IV|nonce|initialization)" spec/ | grep -v -i "unique\|random\|único\|aleatorio"

# Encryption sin integridad (no AEAD)
grep -rniE "AES" spec/ | grep -v -i "GCM\|authenticated\|AEAD\|integrity\|MAC\|HMAC"

# Key derivation sin especificación
grep -rniE "(derive|KDF|PBKDF|HKDF)" spec/ | grep -v -i "iteration\|salt\|round"

# Deprecated algorithms
grep -rniE "(MD5|SHA-?1|DES|RC4|ECB)" spec/
```

### Cryptography Checklist

```markdown
- [ ] ¿Algoritmos explícitos (no "encryption" genérico)?
- [ ] ¿AES-256-GCM o equivalente AEAD?
- [ ] ¿Key generation con CSPRNG?
- [ ] ¿Key rotation policy con periodicidad?
- [ ] ¿Key storage seguro (no en código)?
- [ ] ¿IV/nonce unicidad garantizada (INV)?
- [ ] ¿Key recovery procedure (runbook)?
- [ ] ¿No hay algoritmos deprecados?
- [ ] ¿Password hashing con bcrypt/argon2 + cost adecuado?
```

---

## SEC-CAT-07: Respuesta a Incidentes (INCIDENT-)

### Grep Patterns

```bash
# Security events sin categorización
grep -rniE "(security.*event|evento.*seguridad)" spec/ | grep -v -i "type\|category\|severity\|taxonom"

# Alertas sin threshold
grep -rniE "(alert|alerta)" spec/ | grep -v -i "threshold\|umbral\|trigger\|condition"

# Incidentes sin escalación
grep -rniE "(incident|incidente)" spec/ | grep -v -i "escalat\|escalar\|notify\|notific"

# Logs sin retención
grep -rniE "(log|audit.*trail)" spec/ | grep -v -i "retention\|retención\|90.d\|1.año\|365"

# Runbook gaps
grep -rniE "(runbook|procedimiento|recovery)" spec/ | grep -v -i "step\|paso\|verific"
```

### Incident Response Checklist

```markdown
- [ ] ¿Taxonomía de security events definida?
- [ ] ¿Cada event type tiene severity mapping?
- [ ] ¿Alertas con threshold definido?
- [ ] ¿Escalación automática para critical events?
- [ ] ¿Runbook para cada tipo de incidente?
- [ ] ¿Log retention policy?
- [ ] ¿Audit trail inmutable?
- [ ] ¿Communication plan para incidentes?
- [ ] ¿Post-incident review process?
```

---

## SEC-CAT-08: Compliance GDPR (COMPLY-)

### Grep Patterns

```bash
# GDPR derechos sin UC
grep -rniE "(art\.\s*(15|16|17|18|20|21)|right.to|derecho.a)" spec/ | grep -v -i "UC-\|caso.de.uso"

# Consentimiento sin mecanismo
grep -rniE "(consent|consentimiento)" spec/ | grep -v -i "recolect\|revoc\|withdraw\|record\|audit"

# Data retention sin enforcement
grep -rniE "(retention|retención)" spec/ | grep -v -i "auto\|cron\|enforce\|TTL\|purge"

# Cross-border sin justificación
grep -rniE "(transfer|transferencia|cross.border|third.country)" spec/ | grep -v -i "adequate\|SCC\|binding.corp"

# Breach notification sin timeline
grep -rniE "(breach|brecha|violación.datos)" spec/ | grep -v -i "72h\|notif\|autorid"

# DPIA sin mención
grep -rniE "(DPIA|impact.assess|evaluación.impacto)" spec/
```

### GDPR Compliance Checklist

```markdown
- [ ] ¿Art. 15 - Right of access → UC exists?
- [ ] ¿Art. 16 - Right to rectification → UC exists?
- [ ] ¿Art. 17 - Right to erasure → UC exists?
- [ ] ¿Art. 18 - Right to restriction → UC exists?
- [ ] ¿Art. 20 - Right to portability → UC exists?
- [ ] ¿Art. 21 - Right to object → UC exists?
- [ ] ¿Consent collection mechanism specified?
- [ ] ¿Consent withdrawal mechanism specified?
- [ ] ¿Data retention with automatic enforcement?
- [ ] ¿Breach notification within 72h specified?
- [ ] ¿DPO designation referenced?
- [ ] ¿DPIA for high-risk processing?
- [ ] ¿Privacy by design evidence in specs?
```

---

## SEC-CAT-09: Tests de Seguridad (STEST-)

### Grep Patterns

```bash
# Security requirements sin BDD
# Step 1: Extract all REQ-SEC IDs
grep -rhoE "REQ-SEC-[0-9]+" spec/nfr/SECURITY.md | sort -u > /tmp/req-sec.txt

# Step 2: Check which are referenced in BDD tests
for req in $(cat /tmp/req-sec.txt); do
  if ! grep -rq "$req" spec/tests/; then
    echo "MISSING TEST: $req"
  fi
done

# Auth negative tests
grep -rniE "(unauthorized|forbidden|401|403)" spec/tests/ | wc -l

# Input validation negative tests
grep -rniE "(invalid|malformed|injection|XSS)" spec/tests/ | wc -l

# GDPR flow tests
grep -rniE "(GDPR|erasure|portability|consent)" spec/tests/ | wc -l

# Encryption tests
grep -rniE "(encrypt|decrypt|key.*rotat)" spec/tests/ | wc -l
```

### Security Test Coverage Checklist

```markdown
- [ ] ¿BDD scenarios para auth happy path?
- [ ] ¿BDD scenarios para auth failure (wrong password, expired token)?
- [ ] ¿BDD scenarios para authorization deny (wrong role)?
- [ ] ¿BDD scenarios para tenant isolation violation?
- [ ] ¿BDD scenarios para input validation rejection?
- [ ] ¿BDD scenarios para rate limiting?
- [ ] ¿BDD scenarios para GDPR flows (erasure, access, portability)?
- [ ] ¿Property tests para encryption correctness?
- [ ] ¿Property tests para IV uniqueness?
- [ ] ¿Negative tests for privilege escalation?
```

---

## SEC-CAT-10: Decisiones Sin ADR (SADR-)

### Grep Patterns

```bash
# Security technology choices without ADR
SECURITY_TECHS="bcrypt|argon2|AES|RSA|JWT|OAuth|OIDC|TOTP|Shamir"
grep -rniE "$SECURITY_TECHS" spec/ | grep -v "adr/" | grep -v "SECURITY.md"

# Encryption strategy without ADR
grep -rniE "(estrategia|strategy).*encr" spec/ | grep -v "adr/"

# Auth strategy without ADR
grep -rniE "(estrategia|strategy).*auth" spec/ | grep -v "adr/"

# GDPR decisions without ADR
grep -rniE "(GDPR|right.*eras|data.*retention)" spec/ | grep -v "adr/"

# Rate limiting strategy without ADR
grep -rniE "rate.limit" spec/ | grep -v "adr/"
```

### Security ADR Checklist

```markdown
Decisions that REQUIRE an ADR:
- [ ] ¿Encryption algorithm selection?
- [ ] ¿Authentication strategy (JWT vs sessions)?
- [ ] ¿Authorization model (RBAC vs ABAC)?
- [ ] ¿PII handling strategy?
- [ ] ¿Key management approach?
- [ ] ¿GDPR compliance strategy (Art. 17, 18, 21)?
- [ ] ¿Rate limiting approach?
- [ ] ¿Tenant isolation mechanism?
- [ ] ¿Security event taxonomy?
- [ ] ¿Incident response strategy?
```

---

## Cross-Category Detection Scripts

### Script: Full Security Surface Scan

```bash
#!/bin/bash
# security-surface-scan.sh

echo "=== Security Surface Scan ==="
echo ""

echo "## 1. Endpoints without auth"
grep -rniE "^(GET|POST|PUT|PATCH|DELETE)" spec/contracts/ | grep -v -i "auth\|bearer\|token" | head -20

echo ""
echo "## 2. PII fields without encryption marker"
grep -rniE "(email|phone|name|address)" spec/domain/02-ENTITIES.md | grep -v -i "encrypt\|PII"

echo ""
echo "## 3. Security REQs without BDD"
comm -23 \
  <(grep -rhoE "REQ-SEC-[0-9]+" spec/nfr/SECURITY.md | sort -u) \
  <(grep -rhoE "REQ-SEC-[0-9]+" spec/tests/ | sort -u)

echo ""
echo "## 4. Security ADRs"
ls spec/adr/ | grep -iE "security|encrypt|auth|gdpr|pii"

echo ""
echo "## 5. Security Runbooks"
ls spec/runbooks/

echo ""
echo "## 6. Security Invariants"
grep -c "^### INV-" spec/domain/05-INVARIANTS.md
grep "^### INV-SEC\|^### INV-PII\|^### INV-ROL\|^### INV-AUD" spec/domain/05-INVARIANTS.md
```

### Script: Traceability Chain Verification

```bash
#!/bin/bash
# security-traceability.sh

echo "=== Security Traceability Chain ==="
echo ""

echo "## REQ-SEC → INV coverage"
for req in $(grep -rhoE "REQ-SEC-[0-9]+" spec/nfr/SECURITY.md | sort -u); do
  INV_COUNT=$(grep -rc "$req" spec/domain/05-INVARIANTS.md 2>/dev/null)
  ADR_COUNT=$(grep -rc "$req" spec/adr/ 2>/dev/null)
  BDD_COUNT=$(grep -rc "$req" spec/tests/ 2>/dev/null)
  echo "  $req → INV:$INV_COUNT ADR:$ADR_COUNT BDD:$BDD_COUNT"
done

echo ""
echo "## Security ADRs → Runbooks"
for adr in spec/adr/ADR-*; do
  if grep -qiE "security|encrypt|auth|gdpr" "$adr" 2>/dev/null; then
    ADR_NAME=$(basename "$adr")
    HAS_RUNBOOK=$(grep -rl "$ADR_NAME" spec/runbooks/ 2>/dev/null | wc -l)
    echo "  $ADR_NAME → runbooks:$HAS_RUNBOOK"
  fi
done
```

---

## OWASP ASVS v4 Quick Reference

### Mapping to SEC-CATs

| ASVS Section | SEC-CAT | Key Verification Items |
|-------------|---------|----------------------|
| V1 Architecture | SEC-CAT-01, SEC-CAT-10 | Threat modeling, security architecture, ADRs |
| V2 Authentication | SEC-CAT-02 | Passwords, sessions, MFA, credential recovery |
| V3 Session Management | SEC-CAT-02 | Token lifecycle, timeout, invalidation |
| V4 Access Control | SEC-CAT-03 | RBAC, ABAC, tenant isolation, deny-by-default |
| V5 Validation | SEC-CAT-05 | Input validation, output encoding, injection |
| V6 Cryptography | SEC-CAT-06 | Algorithms, key mgmt, random numbers |
| V7 Error/Logging | SEC-CAT-07 | Security logging, error handling, audit trail |
| V8 Data Protection | SEC-CAT-04 | PII, classification, privacy, retention |
| V12 Files | SEC-CAT-05 | Upload validation, storage, serving |
| V13 API | SEC-CAT-02, SEC-CAT-03 | API auth, rate limiting, input validation |
| V14 Configuration | SEC-CAT-10 | Security headers, dependency management |

### Common CWE References

| CWE | Name | SEC-CAT |
|-----|------|---------|
| CWE-287 | Improper Authentication | SEC-CAT-02 |
| CWE-306 | Missing Authentication | SEC-CAT-02 |
| CWE-307 | Brute Force | SEC-CAT-02 |
| CWE-285 | Improper Authorization | SEC-CAT-03 |
| CWE-639 | IDOR | SEC-CAT-03 |
| CWE-862 | Missing Authorization | SEC-CAT-03 |
| CWE-311 | Missing Encryption | SEC-CAT-04 |
| CWE-312 | Cleartext Storage | SEC-CAT-04 |
| CWE-532 | Info Exposure in Logs | SEC-CAT-04 |
| CWE-20 | Improper Input Validation | SEC-CAT-05 |
| CWE-434 | Unrestricted Upload | SEC-CAT-05 |
| CWE-89 | SQL Injection | SEC-CAT-05 |
| CWE-327 | Broken Crypto | SEC-CAT-06 |
| CWE-326 | Inadequate Encryption Strength | SEC-CAT-06 |
| CWE-330 | Insufficient Randomness | SEC-CAT-06 |
| CWE-778 | Insufficient Logging | SEC-CAT-07 |
| CWE-223 | Omission of Security-relevant Info | SEC-CAT-07 |
| CWE-1053 | Missing Threat Modeling | SEC-CAT-01 |
