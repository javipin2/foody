# Foody — Auditoría Roles y permisos / RBAC (Prompt 06)

> **Fecha:** 2026-08-06  
> **Alcance:** NestJS guards (`JwtAuthGuard`, `RolGuard`, `SuperAdminGuard`, `SucursalScopeService`) + matriz rol↔endpoint + IDOR multi-tenant.  
> **Método:** lectura estática de controllers + seeds `roles_permisos` + `sucursal-scope`. Sin fuzz runtime de todos los endpoints en esta pasada.  
> **Predecesoras:** AQ-\* · BN-\* · FL-\* · API-\* · [`AUDITORIA_AUTH_JWT.md`](AUDITORIA_AUTH_JWT.md) (AUTH-\*).  
> **Sucesora Prompt 07 (BD):** [`AUDITORIA_BD_SUPABASE.md`](AUDITORIA_BD_SUPABASE.md) — BD-\*.  
> **Estado oficial:** [`MASTER_STATUS.md`](MASTER_STATUS.md) § RBAC (RBAC-\*).  
> **Al cerrar un RBAC-\*:** marcar ✅ aquí + MASTER + viñeta en `AVANCE_PROYECTO.md`.  
> **Prod-risk:** varios hallazgos permiten abuso de dinero / cross-tenant → priorizar RBAC-FIX-01…03 en la misma sesión si se remedian.

---

## Veredicto

| Dimensión | Nota | Una línea |
|-----------|------|-----------|
| Guards presentes | B | Casi todos los módulos staff llevan JWT+Activo+Suscripción+Rol |
| Semántica `@Permisos` | C | Es **OR** (`.some`); OR demasiado amplio en cobro/estado/domi |
| Mesero vs caja/admin | C− | **No** abre módulo caja; **sí** cobra y cambia estados vía pedidos |
| Endpoints sin guard | C | Públicos intencionales OK; `anonimizar` + `prueba-web` peligrosos |
| Multi-tenant ID swap | B− | Scope bloquea `sucursal_id` ajeno; **IDOR crítico en `POST /caja/cerrar`** |

**Global Prompt 06:** ~**58 / 100** disciplina RBAC (piloto usable; escalada mesero + IDOR caja = deuda prod).

**Qué ya está bien:**

- `SucursalScopeService` rechaza `sucursal_id` de otro `restaurante_id` (403).
- Catálogo / inventario / usuarios / reportes / analitica / super: permisos correctos para mesero (bloqueado).
- `/super/*` revalida `super_admin` + sin tenant en BD.
- Abrir caja / gastos / retiros exigen caja de la sucursal scoped (`exigirCajaAbierta`).
- Cliente sin JWT staff (device_id) — no escala a admin.

---

## Mecánica RBAC (leer antes de la matriz)

```26:26:foody_backend/src/core/auth/guards/rol.guard.ts
    const tiene = permisosRequeridos.some((p) => usuario.permisos.includes(p));
```

- `@Permisos('a', 'b')` = necesita **uno** de los dos (OR), no ambos.
- `RolGuard` sin `@Permisos` = **cualquier JWT** pasa.
- Permisos vienen de `roles_permisos` (BD) en cada request vía `jwt.strategy` (excepto cocina / domi indep. hardcoded).

### Permisos seed mesero

| Permiso | Origen |
|---------|--------|
| `ver_pedidos` | `002_usuarios.sql` |
| `gestionar_mesas` | `002_usuarios.sql` |
| `aprobar_pedido_mesa` | `002_usuarios.sql` |
| `crear_pedido` | `042_mesero_crear_pedido.sql` |

**No tiene:** `ver_caja`, `abrir_caja`, `cerrar_caja`, `editar_productos`, `gestionar_usuarios`, `ver_reportes`, `ver_inventario`, `ver_dashboard`, `aplicar_descuento`, `gestionar_domiciliarios`.

---

## Índice de hallazgos

| Prefijo | Tema | Abiertos |
|---------|------|--------:|
| RBAC-GUARD-* | Endpoints sin / con guard débil | 5 |
| RBAC-MESERO-* | Escalada mesero vía API | 5 |
| RBAC-CAJA-* | Permisos de dinero flojos | 2 |
| RBAC-TENANT-* | Multi-tenant / IDOR | 4 |
| RBAC-FIX-* | Remediaciones | 7 |

Leyenda: `🟣 abierto` · `🟡 parcial` · `✅ cerrado` · `📅 post-piloto`

---

## 1. Endpoints sin guard / JWT-only (RBAC-GUARD)

### Públicos intencionales (no hallazgo)

`/salud`, `/menu/*`, `/ciudades/*`, `/pedidos` cliente, `/auth/login*`, webhook Wompi, promociones lectura, cotizar domicilio, geografia.

### Hallazgos

| ID | Estado | Sev | Hallazgo | Ejemplo que rompe |
|----|--------|-----|----------|-------------------|
| **RBAC-GUARD-01** | 🟣 | Alta | `DELETE /dispositivos/anonimizar/:device_id` **público** — sin prueba de posesión | `DELETE /api/v1/dispositivos/anonimizar/{device_id_victima}` → limpia dispositivo ajeno |
| **RBAC-GUARD-02** | 🟣 | Alta | `POST /notificaciones/prueba-web` JWT **sin** `RolGuard`; fuerza `todos_web: true` | Header `Authorization: Bearer <token_mesero>` → `POST /api/v1/notificaciones/prueba-web` → blast FCM web global |
| **RBAC-GUARD-03** | 🟣 | Media | `POST /notificaciones/procesar-cola` con solo `ver_dashboard` — cola **global** | Admin resto A: `POST /api/v1/notificaciones/procesar-cola` procesa pendientes de todos |
| **RBAC-GUARD-04** | 🟡 | Media | `GET /pagos/estado`, `POST /pagos/sincronizar` JWT sin RolGuard | Cualquier staff del restaurante ve/sincroniza billing (checkout sí mitiga en service) |
| **RBAC-GUARD-05** | 🟡 | Baja | `GET /health*` público filtra cola impresión / realtime | Info ops; no IDOR de negocio |

---

## 2. Matriz mesero vs áreas críticas (RBAC-MESERO)

Pregunta del prompt: *¿un mesero puede, por la API, acceder a caja o admin?*

| Área | ¿Mesero API? | Motivo |
|------|--------------|--------|
| Abrir/cerrar caja, retiro, gastos módulo `/caja/*` | **No** | Falta `ver_caja` / `abrir_caja` / `cerrar_caja` → **403** |
| Catálogo CRUD / fotos | **No** | `editar_productos` |
| Usuarios CRUD | **No** | `gestionar_usuarios` |
| Reportes / analitica / inventario / dashboard | **No** | permisos admin |
| Super `/super/*` | **No** | `SuperAdminGuard` |
| **Cobrar** mesa/pedido | **Sí** | `@Permisos('ver_pedidos','crear_pedido')` OR |
| **Cambiar estado** pedido | **Sí** | `@Permisos('ver_pedidos')` |
| Asignar domiciliario | **No** | solo `gestionar_domiciliarios` |
| Crear pedido / mesas / aprobar QR | **Sí** | intencional |
| Descuento | **No** | `aplicar_descuento` |

### Hallazgos con petición ejemplo

| ID | Estado | Sev | Hallazgo | Petición que rompe el permiso esperado |
|----|--------|-----|----------|----------------------------------------|
| **RBAC-MESERO-01** | 🟣 **prod-risk** | Alta | Cobro de caja vía pedidos sin permiso de caja | `POST /api/v1/pedidos/{pedido_id}/cobrar` + Bearer mesero + body pagos → registra movimiento caja |
| **RBAC-MESERO-02** | 🟣 **prod-risk** | Alta | Idem cobro cuenta mesa | `POST /api/v1/pedidos/mesa/{mesaId}/cobrar?sucursal_id=…` + Bearer mesero |
| **RBAC-MESERO-03** | 🟣 | Alta | Cambiar estado Kanban / cancelar (sujeto a reglas de transición, no a rol cajero) | `PATCH /api/v1/pedidos/{id}/estado` `{ "estado": "listo" }` + Bearer mesero |
| **RBAC-MESERO-04** | ✅ | — | Asignar/reasignar domiciliario / dispatch | `POST /api/v1/domiciliarios-planta/asignar` + Bearer mesero → **403** |
| **RBAC-MESERO-05** | ✅ | — | Módulo `/caja/*` admin/catálogo/reportes **bloqueados** (403) | `GET /api/v1/caja/activa/{sucursal}` + mesero → 403 |

Evidencia permisos: `pedidos.controller.ts` cobro/estado; `domiciliarios.controller.ts` planta — solo `gestionar_domiciliarios` (✅ 2026-08-11).

---

## 3. Caja — escritura con permiso de solo lectura (RBAC-CAJA)

| ID | Estado | Sev | Hallazgo | Ejemplo |
|----|--------|-----|----------|---------|
| **RBAC-CAJA-01** | 🟣 | Alta | Fiados crear/pagar, devolución, gastos: solo `@Permisos('ver_caja')` | Cajero (tiene `ver_caja`): `POST /api/v1/caja/cuentas-por-cobrar` / `POST …/gastos` — OK operativo pero **cualquier rol futuro con solo ver_caja** escribe dinero |
| **RBAC-CAJA-02** | 🟡 | Baja | Abrir/cerrar/retiro sí usan `abrir_caja` / `cerrar_caja` / `hacer_retiro_parcial` | Correcto |

---

## 4. Multi-tenant — cambiar IDs (RBAC-TENANT)

### Spoof `sucursal_id` de otro restaurante

| Ataque | Resultado |
|--------|-----------|
| `POST /caja/abrir` `{ sucursal_id: <sede_B> }` | **403** — `resolverEscritura` → `assertPerteneceRestaurante` |
| `GET /pedidos?sucursal_id=<sede_B>` | **403** o lista vacía scoped |
| `PATCH /productos/:id` producto de B | **404/403** — update `id AND sucursal_id` JWT |

### Spoof UUID de recurso

| ID | Estado | Sev | Hallazgo | Ejemplo que rompe |
|----|--------|-----|----------|-------------------|
| **RBAC-TENANT-01** | 🟣 **prod-risk** | Crítica | `POST /caja/cerrar` no valida que `caja_id` pertenezca a la sucursal del JWT | Cajero resto A con `cerrar_caja`: `POST /api/v1/caja/cerrar` `{ "caja_id": "<uuid_caja_resto_B>", "monto_final_contado": 0 }` → cierra turno de B, expira QR de B, Realtime en sede B. Controller solo hace `resolverEscritura(usuario, usuario.sucursal_id)` y service `WHERE id = $1` **sin** `sucursal_id` (`caja.service.ts:111-113`, `caja.controller.ts:55-62`) |
| **RBAC-TENANT-02** | ✅ | — | Pedidos/mesas/productos/inventario: UUID + `AND sucursal_id` | Spoof pedido B → 404 |
| **RBAC-TENANT-03** | 🟣 | Media | `POST /promociones/admin/limpiar-expiradas` efecto **global** (staff con `editar_productos`) | Admin A limpia estados Storage de todos los tenants |
| **RBAC-TENANT-04** | 🟣 | Media | Colas globales impresión / FCM (`procesar-cola`) | Staff A drena jobs de B |

**Respuesta corta:** spoofear `sucursal_id` de otro restaurante **no** funciona en la mayoría de rutas. Spoofear **`caja_id` en cerrar** **sí** funciona (crítico).

---

## 5. Matriz compacta rol × capacidad API

| Capacidad | admin/gerente | cajero | mesero | cocina | domi planta | super |
|-----------|:-------------:|:------:|:------:|:------:|:-----------:|:-----:|
| Ver/crear pedidos | ✅ | ✅ | ✅ | — | ver | ✅ |
| Cobrar | ✅ | ✅ | ⚠️ **sí** | ❌ | ❌ | ✅ |
| Abrir/cerrar caja | ✅ | ✅ | ❌ | ❌ | ❌ | ✅ |
| Catálogo / inventario | ✅ | ❌ | ❌ | ❌ | ❌ | ✅ |
| Usuarios | ✅ | ❌ | ❌ | ❌ | ❌ | ✅ |
| Reportes/analitica | ✅ | parcial | ❌ | ❌ | ❌ | ✅ |
| KDS cocina | ✅ | ❌ | ❌ | ✅ | ❌ | ✅ |
| Asignar domi | ✅ | ? | ⚠️ **sí** | ❌ | self | ✅ |
| `/super/*` | ❌ | ❌ | ❌ | ❌ | ❌ | ✅ |
| Cerrar caja UUID ajeno | ⚠️ si tiene `cerrar_caja` | ⚠️ | ❌ | ❌ | ❌ | ✅ |

⚠️ = hallazgo RBAC abierto.

---

## 6. Backlog remediación (RBAC-FIX)

| ID | Prioridad | Acción | Cierra | Prod-risk |
|----|-----------|--------|--------|-----------|
| **RBAC-FIX-01** | P0 | `cerrar`: exigir `caja.sucursal_id === scoped` (mismo patrón `exigirCajaAbierta`) | RBAC-TENANT-01 | **Sí** |
| **RBAC-FIX-02** | P0 | Cobrar: exigir `ver_caja` o permiso `cobrar_pedido` (quitar OR `ver_pedidos`/`crear_pedido` solo) | RBAC-MESERO-01/02 | **Sí** |
| **RBAC-FIX-03** | P1 | `PATCH estado`: permiso dedicado / roles cocina+cajero+admin — no solo `ver_pedidos` | RBAC-MESERO-03 | Medio |
| **RBAC-FIX-04** | P1 | Domi asignar: solo `gestionar_domiciliarios` | RBAC-MESERO-04 | ✅ cerrado 2026-08-11 (`verificar-rbac-mesero-04.ps1`) |
| **RBAC-FIX-05** | P1 | Anonimizar: firma HMAC / Bearer device / o auth cliente | RBAC-GUARD-01 | Sí |
| **RBAC-FIX-06** | P2 | `prueba-web`: quitar `todos_web` o restringir super_admin + no-prod; RolGuard en pagos staff | RBAC-GUARD-02/04 | Medio |
| **RBAC-FIX-07** | P2 | Escrituras caja (fiado/gasto/devolución): permisos write dedicados; colas globales → cron/super | RBAC-CAJA-01, TENANT-03/04 | Medio |

Extender `scripts/verificar-idor-scope.ps1` con caso **cerrar caja cross-restaurant** + smoke mesero cobro → 403 tras fix.

---

## 7. Matriz de conteo

| Grupo | 🟣 | 🟡 | ✅ |
|-------|---:|---:|---:|
| RBAC-GUARD | 3 | 2 | 0 |
| RBAC-MESERO | 3 | 0 | 2 |
| RBAC-CAJA | 1 | 1 | 0 |
| RBAC-TENANT | 3 | 0 | 1 |
| **Total** | **10** | **3** | **3** |
| RBAC-FIX | 6 abiertos · FIX-04 ✅ | | |

---

## 8. Cómo verificar al remediar

| Fix | Evidencia |
|-----|-----------|
| RBAC-FIX-01 | Login cajero A; `POST /caja/cerrar` con `caja_id` de B → **403/404**; caja B sigue abierta |
| RBAC-FIX-02 | Login mesero; `POST /pedidos/:id/cobrar` → **403**; cajero → 200 |
| RBAC-FIX-03 | Mesero `PATCH …/estado` → 403 (salvo transiciones explícitamente permitidas) |
| RBAC-FIX-04 | Mesero `POST /domiciliarios-planta/asignar` → 403 (`verificar-rbac-mesero-04.ps1`) |
| RBAC-FIX-05 | `DELETE anonimizar` sin prueba → 401/403 |
| RBAC-FIX-06 | Mesero `prueba-web` → 403; no envía a tokens ajenos |

Credenciales demo: `admin@foody.demo` / mesero seed / `123456`. Script: ampliar `verificar-idor-scope.ps1`.

---

## Changelog de este documento

| Fecha | Cambio |
|-------|--------|
| 2026-08-11 | **RBAC-MESERO-04 / FIX-04 ✅** — planta sin OR `ver_pedidos`; script `verificar-rbac-mesero-04.ps1` |
| 2026-08-06 | Enlace a Prompt 07 (`AUDITORIA_BD_SUPABASE.md`) |
| 2026-08-06 | **Creación** Prompt 06 — RBAC-GUARD/MESERO/CAJA/TENANT + RBAC-FIX-01…07; ejemplos de petición; enlazado MASTER / AVANCE / README / ROADMAP |

---

*Fin — Auditoría Roles y permisos RBAC (Prompt 06).*
