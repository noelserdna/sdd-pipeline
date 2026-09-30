# Implementation Plan — FASE-0: Esqueleto

> Spec v1.0 · 2026-09-30 · Depends on: — · Enables: FASE-1

## 4. Component Implementation

### 4.1 `src/api/tasks.ts` (A)

**Responsibility:** REQ-F-001, REQ-F-006

### 4.2 Puertos con doble

| Puerto | Interfaz (fichero) | Doble | Provider real | Observable del contrato |
|--------|--------------------|-------|---------------|-------------------------|
| `SyncClient` | `src/api/sync.ts` | `tests/doubles/sync-fake.ts` | `src/adapters/http-sync.ts` | the body carries the task title and status (REQ-F-006 AC1) |

## 7. Test Strategy

### 7.2 Integration Tests

| Scenario | Test ids (test/) | Setup | Block |
|----------|------------------|-------|-------|
| add persists and syncs | REQ-F-006 AC1 | mock `SyncClient` (`tests/doubles/sync-fake.ts`) | A |
