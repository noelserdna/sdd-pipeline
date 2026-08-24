# FASE 1: Mini

> **Estado:** Implementable
> **Dependencias:** Ninguna (fase inicial)
> **Valor Observable:** Un operador comprueba la salud del servicio por HTTP (`GET /health`) y por CLI (`mini ping`).

---

## Objetivo

Permitir que un **Operador** compruebe que el servicio está vivo, tanto desde un cliente HTTP como desde la línea de comandos, con un único punto de entrada (`src/index.ts`) que arranca ambos canales.

---

## Criterios de Éxito

- [ ] `GET /health` responde `200` con `{ "status": "ok", "uptime": <segundos> }`
- [ ] `mini ping` imprime `pong` y termina con código `0`
- [ ] `mini --help` lista el comando `ping`
- [ ] `npm run build` y `npm test` terminan en verde

---

## Specs a Leer

### Casos de Uso

| Documento | Qué extraer |
|-----------|-------------|
| `use-cases/UC-001-health-check.md` | Respuesta de `/health`: campos y códigos |
| `use-cases/UC-002-cli-ping.md` | Sintaxis de `ping`, salida y código de salida |

### ADRs

| Documento | Qué extraer |
|-----------|-------------|
| `adr/ADR-001-node-esm-typescript.md` | Runtime Node 20, ESM, TypeScript strict, sin framework HTTP |

### Dominio

| Documento | Sección | Qué extraer |
|-----------|---------|-------------|
| `domain/03-VALUE-OBJECTS.md` | HealthStatus | Campos `status` y `uptime` |
| `domain/05-INVARIANTS.md` | INV-SYS-* | Invariantes |

### Contratos

| Documento | Sección | Qué extraer |
|-----------|---------|-------------|
| `contracts/API-health.md` | Completo | Contrato de `GET /health` |

---

## Invariantes Aplicables

| ID | Descripción |
|----|-------------|
| INV-SYS-001 | `uptime` nunca es negativo ni decrece entre dos llamadas consecutivas |

---

## Contratos Resultantes

| Endpoint | Método | Descripción |
|----------|--------|-------------|
| `/health` | GET | Estado del servicio (`HealthStatus`) |

### Comandos CLI

| Comando | Descripción |
|---------|-------------|
| `mini ping` | Imprime `pong` y sale con código `0` |

---

## Verificación

```bash
# API verification
curl -s http://localhost:3000/health
# Esperar: {"status":"ok","uptime":<n>}

# CLI verification
node dist/index.js ping
# Esperar: pong (exit 0)
```

---

## Alcance

| Incluye | Excluye |
|---------|---------|
| UC-001: health check HTTP | Autenticación (FASE-2) |
| UC-002: CLI ping | Métricas y logging estructurado (FASE-2) |
