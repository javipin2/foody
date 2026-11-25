# Foody — Auditoría Roles y permisos / RBAC (Prompt 06)

> **Fecha:** 2026-08-06  
> **Alcance:** NestJS guards (`JwtAuthGuard`, `RolGuard`, `SuperAdminGuard`, `SucursalScopeService`) + matriz rol↔endpoint + IDOR multi-tenant.  
> **Método:** lectura estática de controllers + seeds `roles_permisos` + `sucursal-scope`. Sin fuzz runtime de todos los endpoints en esta pasada.  
> **Predecesoras:** AQ-\* · BN-\* · FL-\* · API-\* · [`AUDITORIA_AUTH_JWT.md`](AUDITORIA_AUTH_JWT.md) (AUTH-\*).  
> **Sucesora Prompt 07 (BD):** [`AUDITORIA_BD_SUPABASE.md`](AUDITORIA_BD_SUPABASE.md) — BD-\*.  
> **Estado oficial:** [`MASTER_STATUS.md`](MASTER_STATUS.md) § RBAC (RBAC-\*).  
> **Al cerrar un RBAC-\*:** marcar ✅ aquí + MASTER + viñeta en `AVANCE_PROYECTO.md`.  
> **Revalidación 2026-11-25:** `RBAC-TENANT-01` ya tiene evidencia QA autenticada entre restaurantes distintos: administrador A intentó cerrar una caja de B, recibió 403 y la caja B siguió `abierta` (clone QA aislado, 2026-11-24; no repetido en esta revisión). La fuente actual también valida `fila.sucursal_id` antes de efectos. `RBAC-CAJA-01` se corrigió en fuente con permiso `gestionar_caja`, migración 094 y UI condicionada; 11 unitarias de controller, build y 17 widgets/analyzer pasan, pero falta aplicar migración y probar en runtime autenticado. Una consulta estrictamente de solo lectura encontró 0 overrides con `ver_caja` en `foody_diseno_qa`; no informa sobre producción ni sobre otras bases. Siguen abiertos limpieza global de promociones (`RBAC-TENANT-03`) y autorización de billing staff. El API vivo debe actualizarse para que la evidencia del código actual llegue al piloto.

> **Revisión de código 2026-11-23:** cobro por pedido y por mesa ya requiere `cobrar_pedido`; `crear_pedido` protege alta, edición de líneas y el PATCH genérico de estado. El servicio restringe al rol mesero a `pagando`/`cancelado`; admin, gerente y cajero pueden pedir cualquier transición permitida por la FSM, dentro del alcance de sucursal. Los overrides por usuario solo reducen la plantilla de su rol; no hay roles personalizados ni permiso separado por transición implementado.

---

## Veredicto

| Dimensión | Nota | Una línea |
|-----------|------|-----------|
| Guards presentes | B | Casi todos los módulos staff llevan JWT+Activo+Suscripción+Rol |
| Semántica `@Permisos` | C | Es **OR** (`.some`); OR demasiado amplio en cobro/estado/domi |
| Mesero vs caja/admin | C− | **No** abre módulo caja ni cobra; puede crear pedidos y transiciones limitadas por servicio |
| Endpoints sensibles | B− | `anonimizar` exige prueba de posesión; `prueba-web` envía solo al usuario; cola global solo Super Admin; billing/diagnóstico aún parciales |
| Multi-tenant ID swap | B | Cierre de caja valida la sucursal real y QA cross-tenant confirmó 403 sin mutación; quedan rutas globales y módulos no cubiertos por esta prueba |

**Global Prompt 06:** ~**58 / 100** es la valoración histórica de 2026-08-06; requiere recalcularse porque cierre de caja y tres rutas sensibles cambiaron y otros hallazgos continúan abiertos.

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

| Prefijo | Tema | Hallazgos |
|---------|------|----------:|
| RBAC-GUARD-* | Endpoints sin / con guard débil | 2 |
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
| **RBAC-GUARD-01** | ✅ Código + regresión | Alta | La ruta es pública por diseño, pero antes de anonimizar exige FCM exacto guardado o sesión Supabase del `auth_uid` vinculado; sin prueba devuelve 403. La fila también elimina `capability_hash`. | Unitarias de posesión cubren secreto FCM, ausencia/discordancia y usuario Supabase correcto/incorrecto. Ver `dispositivos.service.spec.ts`. |
| **RBAC-GUARD-02** | ✅ Código | Alta | `POST /notificaciones/prueba-web` requiere `RolGuard` + `ver_dashboard`; el controller fuerza `todos_web:false`, y el servicio solo recoge tokens web del usuario. | No blast global desde sesión staff. |
| **RBAC-GUARD-03** | ✅ Código + regresión | Media | `POST /notificaciones/procesar-cola` afecta cola global; ahora requiere JWT, usuario activo y `SuperAdminGuard`, que revalida rol y ausencia de tenant en BD. El cron sigue siendo el camino automático. | Spec de metadata exige exactamente los guards de plataforma y no `ver_dashboard`. Smoke sin sesión: HTTP 401 local/Tunnel. |
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
| **Cobrar** mesa/pedido | **No** | ambas rutas usan `@Permisos('cobrar_pedido')`; migration `082` no asigna ese permiso a mesero |
| **Cambiar estado** pedido | **Sí, con `crear_pedido`** | PATCH genérico usa un permiso que también se necesita para crear/editar líneas. Mesero está limitado en servicio a `pagando`/`cancelado`; admin/gerente/cajero pueden usar transiciones permitidas por FSM. No hay permiso separado por transición. Overrides por usuario solo quitan permisos de su plantilla |
| Asignar domiciliario | **No** | solo `gestionar_domiciliarios` |
| Crear pedido / mesas / aprobar QR | **Sí** | intencional |
| Descuento | **No** | `aplicar_descuento` |

### Hallazgos con petición ejemplo

| ID | Estado | Sev | Hallazgo | Petición que rompe el permiso esperado |
|----|--------|-----|----------|----------------------------------------|
| **RBAC-MESERO-01** | ✅ Código | Alta | Cobro de caja vía pedido protegido con permiso específico | `pedidos.controller.ts`: `@Permisos('cobrar_pedido')`; spec ejecuta guard: mesero 403 / cajero permitido |
| **RBAC-MESERO-02** | ✅ Código | Alta | Cobro de cuenta mesa protegido con permiso específico | `pedidos.controller.ts`: `@Permisos('cobrar_pedido')`; spec ejecuta guard: mesero 403 / cajero permitido |
| **RBAC-MESERO-03** | 🟡 Parcial | Media | PATCH con solo `ver_pedidos` no pasa; requiere `crear_pedido`. Mesero limitado por servicio a `pagando`/`cancelado`; admin/gerente/cajero tienen transiciones FSM. `crear_pedido` también autoriza edición de líneas. Decidir si separar alta/edición/transición antes de expandir roles | `pedidos.controller.ts`, `pedidos-estado.service.ts`, `pedidos.controller.spec.ts` |
| **RBAC-MESERO-04** | ✅ | — | Asignar/reasignar domiciliario / dispatch | `POST /api/v1/domiciliarios-planta/asignar` + Bearer mesero → **403** |
| **RBAC-MESERO-05** | ✅ | — | Módulo `/caja/*` admin/catálogo/reportes **bloqueados** (403) | `GET /api/v1/caja/activa/{sucursal}` + mesero → 403 |

Evidencia permisos: `pedidos.controller.ts` cobro/estado; `domiciliarios.controller.ts` planta — solo `gestionar_domiciliarios` (✅ 2026-08-11).

---

## 3. Caja — escritura con permiso de solo lectura (RBAC-CAJA)

| ID | Estado | Sev | Hallazgo | Ejemplo |
|----|--------|-----|----------|---------|
| **RBAC-CAJA-01** | 🟡 Fuente corregida; migración/runtime pendientes | Alta | Crear/pagar CxC, devolución y gastos ahora exigen `@Permisos('gestionar_caja')`; `ver_caja` queda para lectura. Roles operativos por defecto lo reciben por migración 094. | Controller specs: `ver_caja` solo → 403; `ver_caja` + `gestionar_caja` → pasa. Flutter oculta acciones según sesión. No se aplicó la migración; overrides completos sin el nuevo permiso seguirán en solo lectura hasta que se revisen. |
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
| **RBAC-TENANT-01** | ✅ Fuente + unitarias + QA cross-sucursal y cross-tenant | Crítica | `POST /caja/cerrar` consulta la caja bloqueando su fila y ejecuta `resolverEscritura(usuario, fila.sucursal_id)` antes de expirar QR o realizar escrituras. | QA cross-sucursal: gerente Centro intentó cerrar caja Norte → 403 y caja abierta. Clon QA separado 2026-11-24: admin del restaurante A intentó cerrar caja del tenant B → 403; `SELECT` confirmó estado `abierta`. Evidencia histórica en `AVANCE_PROYECTO.md`; no repetida en la revalidación 2026-11-25. |
| **RBAC-TENANT-02** | ✅ | — | Pedidos/mesas/productos/inventario: UUID + `AND sucursal_id` | Spoof pedido B → 404 |
| **RBAC-TENANT-03** | 🟣 | Media | `POST /promociones/admin/limpiar-expiradas` efecto **global** (staff con `editar_productos`) | Admin A limpia estados Storage de todos los tenants |
| **RBAC-TENANT-04** | ✅ parcial | Media | La cola FCM manual ya exige Super Admin; cron interno procesa automáticamente. Revisar por separado el alcance de colas de impresión y sus tareas de administración. | Personal tenant no puede disparar `procesar-cola` |

**Respuesta corta:** spoofear `sucursal_id` de otro restaurante se rechaza en las rutas revisadas. El cierre de caja ajena se rechaza antes de cualquier escritura y ya tiene una prueba histórica E2E cross-tenant en clon QA (403; caja permanece abierta). `RBAC-CAJA-01` está corregido en fuente/migración con permisos separados; falta activación verificada. La revisión continúa abierta por ese rollout, `RBAC-TENANT-03`, billing y scopes de otros trabajos.

---

## 5. Matriz compacta rol × capacidad API

| Capacidad | admin/gerente | cajero | mesero | cocina | domi planta | super |
|-----------|:-------------:|:------:|:------:|:------:|:-----------:|:-----:|
| Ver/crear pedidos | ✅ | ✅ | ✅ | — | ver | ✅ |
| Cobrar | ✅ | ✅ | ❌ | ❌ | ❌ | ✅ |
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
| **RBAC-FIX-01** | ✅ Fuente + unitarias + QA cross-sucursal y cross-tenant | — | `cerrar`: valida el scope de la sucursal leída de la caja antes de cualquier efecto financiero. QA cross-tenant documentada 2026-11-24: 403 y caja sigue abierta. | RBAC-TENANT-01 | Sin efecto fuera del alcance de sucursal |
| **RBAC-FIX-02** | P0 | ✅ Código 2026-11-23: ambas rutas de cobro exigen `cobrar_pedido`; spec del guard bloquea mesero y permite cajero | RBAC-MESERO-01/02 | Cerrado en código; sin cobro real de prueba |
| **RBAC-FIX-03** | P1 | 🟡 Parcial 2026-11-23: PATCH genérico exige `crear_pedido`; servicio limita al mesero a `pagando`/`cancelado`, mientras admin/gerente/cajero pueden transiciones FSM. UI explica alcance de `crear_pedido`. Decidir si separar alta/edición/transición y probar matriz antes de agregar roles | RBAC-MESERO-03 | Medio |
| **RBAC-FIX-04** | P1 | Domi asignar: solo `gestionar_domiciliarios` | RBAC-MESERO-04 | ✅ cerrado 2026-08-11 (`verificar-rbac-mesero-04.ps1`) |
| **RBAC-FIX-05** | ✅ Código + regresión | — | Anonimizar exige token FCM actual o sesión Supabase ligada al dispositivo; capability se limpia al anonimizar | RBAC-GUARD-01 | No se reproduce limpieza por ID conocido |
| **RBAC-FIX-06** | 🟡 Parcial | P2 | `prueba-web` se limita al usuario actual; procesamiento global ahora es Super Admin. Sigue pendiente decidir protección/alcance de GET/POST billing staff | RBAC-GUARD-02/03/04 | Medio |
| **RBAC-FIX-07** | 🟡 | Permiso write `gestionar_caja` aplicado en fuente/migración 094 y UI; faltan migración/runtime y revisión de usuarios con overrides. Colas globales → cron/super sigue pendiente | RBAC-CAJA-01, TENANT-03/04 | Medio |

`scripts/verificar-idor-scope.ps1` cubre cierre de caja entre sucursales y, en modo optativo, entre tenants; ambos confirman persistencia `abierta` después del 403. Reejecutado el 2026-11-25 desde clon limpio y Nest aislado :3001: 10 comprobaciones pasaron. La guarda exige DB `foody_diseno_qa_codex_rbac_*`, UUID de otra empresa y correo sintético `@qa.example`; valida esto antes de iniciar sesión, luego crea la cuenta solo en el clon. La prueba negativa con la QA persistente fue detenida antes de cualquier login/API. Ver detalle y limpieza en `AVANCE_PROYECTO.md`.

---

## 7. Matriz de conteo

| Grupo | 🟣 | 🟡 | ✅ |
|-------|---:|---:|---:|
| RBAC-GUARD | 0 | 2 | 3 |
| RBAC-MESERO | 0 | 1 | 4 |
| RBAC-CAJA | 1 | 1 | 0 |
| RBAC-TENANT | 1 | 1 | 2 |
| **Total** | **2** | **5** | **9** |
| RBAC-FIX | FIX-01 E2E pendiente; FIX-02/04/05 ✅; FIX-03/06 parcial; FIX-07 abierto | | |

---

## 8. Cómo verificar al remediar

| Fix | Evidencia |
|-----|-----------|
| RBAC-FIX-01 | ✅ E2E QA cross-tenant documentada: la autorización consulta la sucursal real de la caja y corta antes de mutaciones; tenant B recibe 403 y la caja queda abierta (2026-11-24) |
| RBAC-FIX-02 | Spec de `RolGuard` sobre ambos métodos: mesero (sin `cobrar_pedido`) → 403; cajero (con permiso) pasa guard. Falta smoke autenticado en BD QA |
| RBAC-FIX-03 | Spec: `ver_pedidos` solo → 403; `crear_pedido` pasa guard. Servicio mantiene límite mesero `pagando`/`cancelado`; falta matriz de transiciones por rol |
| RBAC-FIX-04 | Mesero `POST /domiciliarios-planta/asignar` → 403 (`verificar-rbac-mesero-04.ps1`) |
| RBAC-FIX-05 | ✅ Unitarias: no prueba/FCM ajeno → false; FCM correcto o Supabase UID igual → true; UID distinto → false |
| RBAC-FIX-06 | ✅ Controller `prueba-web` scope al usuario; `procesar-cola` metadata exige SuperAdminGuard. Billing staff aún pendiente |

Credenciales demo: `admin@foody.demo` / mesero seed / `123456`. Script: ampliar `verificar-idor-scope.ps1`.

---

## Changelog de este documento

| Fecha | Cambio |
|-------|--------|
| 2026-11-25 | **RBAC-CAJA-WRITE-01** — `gestionar_caja` para mutaciones, migración 094, `ver_caja` read-only, pantalla Caja respeta permisos; Jest 11/11 + build + Flutter 17/17/analyzer. Falta aplicación de migración, runtime y revisión de overrides |
| 2026-11-23 | **RBAC-PEDIDOS-01** — Actualizada evidencia: cobros ya exigen `cobrar_pedido`; el guard de estado deja de aceptar solo lectura y requiere `crear_pedido`. Specs de ambos endpoints de cobro y estado. Permisos por transición quedan parcialmente pendientes |
| 2026-08-11 | **RBAC-MESERO-04 / FIX-04 ✅** — planta sin OR `ver_pedidos`; script `verificar-rbac-mesero-04.ps1` |
| 2026-08-06 | Enlace a Prompt 07 (`AUDITORIA_BD_SUPABASE.md`) |
| 2026-08-06 | **Creación** Prompt 06 — RBAC-GUARD/MESERO/CAJA/TENANT + RBAC-FIX-01…07; ejemplos de petición; enlazado MASTER / AVANCE / README / ROADMAP |

---

*Fin — Auditoría Roles y permisos RBAC (Prompt 06).*
