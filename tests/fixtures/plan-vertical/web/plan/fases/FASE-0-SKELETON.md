# FASE 0: Esqueleto — entrar y registrar un cliente

> **Estado:** Implementable
> **Incremento:** El personal entra y registra un cliente que sigue ahí al recargar
> **Requisitos:** REQ-F-001, REQ-F-002
> **Escenarios:** AC-001-01, AC-001-02, AC-002-01, AC-002-02, AC-002-03, AC-003-01
> **Necesidades:** N-001, N-002
> **Dependencias:** Ninguna (fase inicial)

---

## Criterios de Éxito

### UC-001 — Iniciar sesión
- [ ] Credenciales válidas abren la lista; contraseña errónea → mensaje genérico (AC-001-01, AC-001-02)

### UC-002 — Registrar cliente
- [ ] Alta con nombre y teléfono, visible tras recargar; nombre vacío → error (AC-002-01, AC-002-02)
- [ ] Sin sesión → página de login (AC-002-03)

### UC-003 — Listar clientes
- [ ] La lista muestra los clientes registrados (AC-003-01)

## Demo

| # | Acción | Resultado esperado | Escenario |
|---|--------|--------------------|-----------|
| 1 | `bin/rails db:seed` (staff demo@taller.test) · abrir `/` | página de login | AC-002-03 · N-001 |
| 2 | entrar con demo@taller.test y contraseña errónea | `Invalid email or password` | AC-001-02 · N-001 |
| 3 | entrar con la contraseña correcta | lista de clientes vacía | AC-001-01 · N-001 |
| 4 | Nuevo cliente sin nombre → Guardar | `Name is required` | AC-002-02 · N-002 |
| 5 | Nuevo cliente Ana Ruiz, 600111222 → Guardar; recargar | Ana Ruiz en la lista | AC-002-01, AC-003-01 · N-002 |
