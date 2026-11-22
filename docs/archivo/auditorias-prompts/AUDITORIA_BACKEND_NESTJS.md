# Foody — Auditoría Backend NestJS (Prompt 02)

> **Fecha:** 2026-08-05  
> **Alcance:** `foody_backend/src` — estructura general: módulos, controllers, DTOs, excepciones, pipes/filters/interceptors.  
> **Método:** lectura estática (grep + muestreo de controllers/services). Sin ejecución de API en esta pasada.  
> **Sucesora Prompt 03 (Flutter):** [`AUDITORIA_FLUTTER_ESTRUCTURA.md`](AUDITORIA_FLUTTER_ESTRUCTURA.md) — FL-\*.  
> **Sucesora Prompt 04 (REST):** [`AUDITORIA_APIS_REST.md`](AUDITORIA_APIS_REST.md) — API-\*.  
> **Predecesora:** [`AUDITORIA_ARQUITECTURA_CALIDAD.md`](AUDITORIA_ARQUITECTURA_CALIDAD.md) (Prompt 01, AQ-\*).  
> **Estado oficial:** hallazgos abiertos también en [`MASTER_STATUS.md`](MASTER_STATUS.md) § Backend NestJS (BN-\*).  
> **Al cerrar un BN-\*:** marcar ✅ aquí + MASTER + viñeta en `AVANCE_PROYECTO.md`.

---

## Veredicto

| Dimensión | Nota | Una línea |
|-----------|------|-----------|
| Módulos / SRP | C+ | Fronteras menú/catálogo y caja dual sanas; overlap métricas + god Pedidos/Auth |
| Controllers delgados | B | Casi todos OK; **almacenamiento** gordo (SQL); authz en usuarios/inventario |
| DTOs / class-validator | C | Pipe global OK; **~19 bodies inline** sin validar; CotizarDomicilioDto huérfano |
| Excepciones | B− | Filter global sólido; catch de billing Wompi / renovación tragan fallos |
| Pipes / interceptors / filters | B+ | Globales consistentes; falta `forbidNonWhitelisted` |

**Global Prompt 02:** ~**70 / 100** disciplina NestJS (estructura + validación + errores).

**Qué ya está bien (no rehacer):**

- `RespuestaInterceptor` + `HttpExceptionFilter` + `RateLimitGuard` globales (`app.module.ts`).
- `ValidationPipe({ whitelist, transform })` en `main.ts`.
- Controllers de caja, mesas, pedidos (mayoría), catálogo CRUD principal, super-admin: delgados.
- `core/caja` como único writer de `movimientos_caja` (frontera intencional).
- Split menú (lectura pública) vs catálogo (CRUD staff).
- DTOs con class-validator en ~60 archivos / ~90 clases (ninguno vacío).

---

## Índice de hallazgos

| Prefijo | Tema | Abiertos (aprox.) |
|---------|------|------------------:|
| BN-MOD-* | Módulos / responsabilidad única | 18 |
| BN-CTRL-* | Lógica en controllers | 12 |
| BN-DTO-* | Validación DTO / endpoints sin validar | 33 |
| BN-EXC-* | try/catch y filtro de excepciones | 18 |
| BN-PIPE-* | Interceptors / pipes / filters | 5 |
| BN-FIX-* | Remediaciones priorizadas | 6 |

Leyenda estado: `🟣 abierto` · `🟡 parcial / aceptado` · `✅ cerrado` · `📅 post-escala`

**Solapes con Prompt 01:** BN-CTRL-01 ≡ AQ-SOLID-03; BN-MOD-08 ≈ AQ-SOLID-02 (god services); BN-MOD-05 ≈ AQ-DUP / acoplamiento métricas. No duplicar remediación: cerrar uno cierra el otro.

---

## 1. Módulos — ¿responsabilidad única? (BN-MOD)

### Inventario

| Capa | Módulos |
|------|---------|
| `core/` (8) | auth, database, realtime, cache-menu, impresion, caja-movimientos, onboarding, suscripciones-cron |
| `modulos/` (27) | salud, ciudades, restaurantes, menu, dashboard, pedidos, dispositivos, mesas, super-admin, caja, catalogo, cocinas, inventario, domiciliarios, reportes, analitica, alertas, usuarios, facturacion, zonas, promociones, costeo, geografia, notificaciones, auditoria, pagos, almacenamiento |

### Overlaps / frontera borrosa

| ID | Estado | Par | Evidencia | Veredicto |
|----|--------|-----|-----------|-----------|
| **BN-MOD-01** | 🟡 | ciudades vs geografia | `GET /ciudades` (BD) vs `GET /geografia/buscar` (Photon) | Bajo overlap real; nombres confunden. Renombrar geografia→`direcciones` o agrupar bajo geografia |
| **BN-MOD-02** | 🟡 | menu vs catalogo | Menu = lectura pública; Catalogo = CRUD staff (5 controllers) | Split sano; riesgo: lógica producto duplicada entre `menu.service` y `catalogo.service` |
| **BN-MOD-03** | 🟡 | salud vs health | Dual intencional: `/salud` ligero · `/health` y `/salud/completo` profundo | Aceptado + alias canónico |
| **BN-MOD-04** | ✅ | caja vs `core/caja` | API turno vs único writer `movimientos_caja` | Frontera intencional y sana |
| **BN-MOD-05** | ✅ | reportes vs analitica vs dashboard | `compartido/sql/ventas-metricas.sql.ts` | Fuente única filtros/fecha/caja/TZ |
| **BN-MOD-06** | 🟡 | auth vs usuarios | Auth = login/registro/FCM; Usuarios = CRUD staff | Frontera clara; FCM partido auth ↔ notificaciones |
| **BN-MOD-07** | 🟡 | cocinas vs impresion | Impresoras (BD config) en cocinas; cola jobs en `core/impresion` | Split OK; nombres confunden |

### God modules / god services

| ID | Estado | Hallazgo | Evidencia |
|----|--------|----------|-----------|
| **BN-MOD-08** | 🟣 | PedidosModule hub | 2 controllers + ~12 providers; subservicios 600–1100 LOC |
| **BN-MOD-09** | 🟡 | AuthModule cross-cutting | 1 controller + ~12 providers (guards, plan, scope, supabase) — aceptable como “security hub” |
| **BN-MOD-10** | 🟣 | DomiciliariosModule amplio | 4 controllers + planta + independientes + documentos + dispatch |
| **BN-MOD-11** | 🟣 | CatalogoModule | 5 controllers, 1 service ~951 LOC |
| **BN-MOD-12** | 🟣 | AnaliticaService god | ~1625 LOC |
| **BN-MOD-13** | 🟣 | InventarioService god | ~1270 LOC |

### Core que es dominio (no infra pura)

| ID | Estado | Módulo | Nota |
|----|--------|--------|------|
| **BN-MOD-14** | 🟡 | `core/caja` | Dominio financiero; documentar criterio “core = shared domain writer” |
| **BN-MOD-15** | 🟡 | `core/impresion` | Cola + HTTP de dominio |
| **BN-MOD-16** | 🟡 | `core/onboarding` | Alta restaurante = negocio |
| **BN-MOD-17** | 🟡 | `core/suscripciones` | Billing SaaS |
| **BN-MOD-18** | ✅ | `core/cache/menu` | Infra ligera de dominio — OK |

`database`, `realtime`, JWT/Passport en auth = core legítimo.

---

## 2. Controllers — ¿lógica de negocio filtrada? (BN-CTRL)

Criterio “delgado”: parse + scope (`SucursalScope*`) + llamar service. Outlier = SQL, mutaciones, reglas de ownership/authz de producto, o cálculos en el handler.

| ID | Estado | Sev | Hallazgo | Ubicación |
|----|--------|-----|----------|-----------|
| **BN-CTRL-01** | ✅ | Alta | SQL ownership + UPDATE entidad + invalidar `MenuCache` → service | `almacenamiento.service.ts` |
| **BN-CTRL-02** | ✅ | Media | Authz crear/actualizar (sucursal + gerente_cadena) en service | `usuarios.service.ts` |
| **BN-CTRL-03** | ✅ | Media | Gate `puedeVerInventarioHermanas` + traslados en service | `inventario.service.ts` |
| **BN-CTRL-04** | ✅ | Baja | Gate corporativo consolidado/comparativa | services dashboard/analitica |
| **BN-CTRL-05** | ✅ | Baja | `resolverContexto` periodo+filtros | `analitica.service.ts` |
| **BN-CTRL-06** | ✅ | Baja | Branch tipo_entidad vía `ImpactoStockQueryDto` | `costeo.controller.ts` |
| **BN-CTRL-07** | ✅ | Baja | `dto.subtotal` tipado (sin `?? 0`) | `promociones.controller.ts` |
| **BN-CTRL-08** | ✅ | Baja | Default fechas `hoy` tras `TimelineAuditoriaDto` | `auditoria.controller.ts` |
| **BN-CTRL-09** | ✅ | Baja | lat/lng/limite con `@Type()` en DTOs zonas/geografia | query DTOs |
| **BN-CTRL-10** | ✅ | Baja | Payload FCM prueba por rol | `notificaciones.service.enviarPrueba` |
| **BN-CTRL-11** | ✅ | Baja | Bridge HTML retorno-app | `pagos.service.htmlRetornoApp` |
| **BN-CTRL-12** | ✅ | Baja | Merge `sucursal_id` crear staff | `pedidos.service.crearStaff` |

**Confirmado:** ningún otro controller inyecta `DatabaseService` (solo almacenamiento).

### Resumen delgado (sí / parcial / no)

| Delgado | Controllers |
|---------|-------------|
| **No** | — (almacenamiento SQL ya en service) |
| **Parcial** | analitica, dashboard, costeo, pagos, promociones, notificaciones, auditoria, zonas, geografia, pedidos, productos/bebidas/toppings/combos, cocina-tickets, domiciliarios, facturacion, auth, inventario (scope en controller), usuarios (scope listar) |
| **Sí** | caja, mesas, categorias, cocinas, impresoras, reportes, super-admin, sucursales-staff, pedidos-public, menu, ciudades, restaurantes, alertas, impresion, salud, health, app, domiciliarios-documentos\*, almacenamiento, dispositivos |

---

## 3. DTOs — ¿validación real con class-validator? (BN-DTO)

### Pipe global

```typescript
  app.useGlobalPipes(
    new ValidationPipe({
      whitelist: true,
      forbidNonWhitelisted: true,
      transform: true,
    }),
  );
```

**Importante:** class-validator **solo aplica a clases**. `@Body() body: { ... }` / `Record<string, unknown>` **no se validan**.

### A) Bodies inline (sin class-validator) — mutaciones

| ID | Estado | Método | Ruta | Archivo |
|----|--------|--------|------|---------|
| **BN-DTO-01** | ✅ | POST | `/auth/registrar-fcm` | `dto/fcm.dto.ts` |
| **BN-DTO-02** | ✅ | POST | `/auth/desactivar-fcm` | idem |
| **BN-DTO-03** | ✅ | POST | `/dispositivos/registrar` | `dto/dispositivos.dto.ts` |
| **BN-DTO-04** | ✅ | POST | `/dispositivos/vincular-auth` (+ body anonimizar) | idem |
| **BN-DTO-05** | 🟡 | POST | `/pagos/webhook-wompi` | `pagos.controller.ts` — `Record`; firma Wompi valida aparte |
| **BN-DTO-06** | ✅ | DELETE | `/pedidos/:id/items/:itemId` | `motivo-pedido.dto.ts` |
| **BN-DTO-07** | ✅ | PATCH | `/pedidos/:id/rechazar` | idem |
| **BN-DTO-08** | ✅ | PATCH | `/productos/:id/disponibilidad` | `extras-mutacion.dto.ts` |
| **BN-DTO-09** | ✅ | POST | `/productos/:id/toppings` | idem |
| **BN-DTO-10** | ✅ | PUT | `/productos/:id/toppings` | idem |
| **BN-DTO-11** | ✅ | POST | `/productos/:id/bebidas` | idem |
| **BN-DTO-12** | ✅ | PATCH | `/bebidas/:id` | `ActualizarExtraDto` |
| **BN-DTO-13** | ✅ | PATCH | `/toppings/:id` | idem |
| **BN-DTO-14** | ✅ | PATCH | `/combos/:id/disponibilidad` | `CambiarDisponibilidadDto` |
| **BN-DTO-15** | ✅ | PATCH | `/cocina/items/:item_id/observaciones` | `item-kds-mutacion.dto.ts` |
| **BN-DTO-16** | ✅ | PATCH | `/cocina/items/:item_id/prioridad` | idem |
| **BN-DTO-17** | ✅ | PATCH | `/domiciliarios-planta/config-fiado/:sucursal_id` | `config-domicilio.dto.ts` |
| **BN-DTO-18** | ✅ | PATCH | `/domiciliarios-planta/config-domicilio-caja/:sucursal_id` | idem |
| **BN-DTO-19** | ✅ | POST | `/facturacion/anular/:factura_id` | `anular-factura.dto.ts` |

### B) Query sin DTO / sin Parse\*

| ID | Estado | Endpoint | Nota |
|----|--------|----------|------|
| **BN-DTO-20** | ✅ | GET `/promociones/validar-codigo` | `ValidarCodigoPromocionDto` |
| **BN-DTO-21** | ✅ | GET `/zonas/cotizar-domicilio` | `CotizarDomicilioDto` + `@Query()` |
| **BN-DTO-22** | ✅ | GET `/geografia/buscar` | `BuscarGeografiaDto` |
| **BN-DTO-23** | ✅ | GET `/auditoria/timeline` | `TimelineAuditoriaDto` |
| **BN-DTO-24** | ✅ | GET `/pedidos`, `cerrados-hoy` | `ListarPedidosQueryDto` / `ListarCerradosHoyQueryDto` |
| **BN-DTO-25** | ✅ | GET `/costeo/.../impacto-stock` | `ImpactoStockQueryDto` |
| **BN-DTO-26** | ✅ | POST uploads almacenamiento | `SubirImagenQueryDto` / `SubirVideoQueryDto` |
| **BN-DTO-27** | ✅ | GET `/pagos/retorno-app` | `RetornoAppQueryDto` (`pago_id` UUID opcional) |

Muchos GET staff usan `@Query('sucursal_id') string` + scope después — deuda menor si el scope falla con 403.

### C) DTO débil / huérfano

| ID | Estado | Hallazgo |
|----|--------|----------|
| **BN-DTO-28** | ✅ | `AprobarPedidoMesaDto` con `mesera_id?`; sin default `= {}` en controller |
| **BN-DTO-29** | ✅ | POST notificaciones prueba / procesar-cola sin body — OK |
| **BN-DTO-30** | ✅ | POST `/pagos/renovar` sin body — OK |
| **BN-DTO-31** | ✅ | `CotizarDomicilioDto` cableado en controller |
| **BN-DTO-32** | ✅ | `CrearPedidoDto`: `requiere_factura` / `forzar_fuera_horario` con `@IsBoolean()` |
| **BN-DTO-33** | ✅ | `ParseUUIDPipe` en mesas/productos/usuarios/inventario/costeo/catálogo/promos/zonas/cocinas/alertas/facturación (parcial F7 + lote residual) |

**Ningún `*.dto.ts` vacío** ni sin al menos un `@Is*`.

---

## 4. Manejo de excepciones (BN-EXC)

### Global (bien)

- `HttpExceptionFilter` (`APP_FILTER`): normaliza `{ exito: false, error, mensaje }`, preserva códigos de negocio (`STOCK_INSUFICIENTE`, caja, plan…), loggea 5xx.
- No hay `@UseFilters` locales → aplicación **consistente**.

### try/catch: peligrosos / dudosos

| ID | Estado | Sev | Archivo | Qué hace |
|----|--------|-----|---------|----------|
| **BN-EXC-01** | ✅ | Alta | `pagos.service.ts` | `registrarFalloFuentePago` + auditoria |
| **BN-EXC-02** | ✅ | Alta | webhook Wompi | idem |
| **BN-EXC-03** | ✅ | Media | `pagos-recurrentes.service.ts` | Sin `payment_source_id` → throw (caller audita) |
| **BN-EXC-04** | ✅ | Media | `pagos-recurrentes.service.ts` | Fallo consultar fuente → `logger.error` + `estado_wompi=consulta_fallida`, igual guarda id |
| **BN-EXC-05** | ✅ | Alta | `suscripciones-cron` | log error + `renovaciones_fallos` en resultado |

### Aceptables (best-effort post-commit / health)

| ID | Estado | Archivo | Motivo |
|----|--------|---------|--------|
| **BN-EXC-06** | ✅ | `realtime-broadcast.service.ts` | Broadcast no debe tumbar pedido |
| **BN-EXC-07** | ✅ | `pagos.service.ts` realtime | Idem |
| **BN-EXC-08** | ✅ | `transaction-hooks.service.ts` | Hooks post-commit |
| **BN-EXC-09** | ✅ | `fcm.service.ts` | Init Firebase |
| **BN-EXC-10** | ✅ | `alertas-riesgo.service.ts` | FCM alerta |
| **BN-EXC-11** | ✅ | `super-admin.service.ts` | FCM |
| **BN-EXC-12** | ✅ | `promociones-cron.service.ts` | Cron estados |
| **BN-EXC-13** | ✅ | `suscripciones-cron` aviso | Email/push best-effort |
| **BN-EXC-14/15** | ✅ | realtime/impresión health | Probe → `conectado:false` |
| **BN-EXC-16** | ✅ | impresión job fail | `registrarFalloJob` (no silencioso) |
| **BN-EXC-17** | ✅ | almacenamiento cleanup | Storage remove → false + log |
| **BN-EXC-18** | ✅ | `encolarPorPedido` | catch + job `estado=error` auditable (no tumba pedido) |

**No hay** `catch {}` vacío.

---

## 5. Interceptors, pipes, filters (BN-PIPE)

### `compartido/` (sin pipes propios)

```
compartido/decoradores/* (usuario, permisos, módulo, omitir-suscripcion)
compartido/dto/paginacion.dto.ts
compartido/filtros/http-exception.filter.ts
compartido/guards/rate-limit.guard.ts
compartido/interceptores/respuesta.interceptor.ts
```

| ID | Estado | Hallazgo | Detalle |
|----|--------|----------|---------|
| **BN-PIPE-01** | ✅ | Filters/pipes locales ausentes | Todo vía global — consistente |
| **BN-PIPE-02** | ✅ | `@UseInterceptors` solo multer | `FileInterceptor` en almacenamiento + documentos domiciliarios |
| **BN-PIPE-03** | ✅ | Sin `forbidNonWhitelisted: true` → **ahora sí** | Props extra → 400 |
| **BN-PIPE-04** | 🟡 | Sin `enableImplicitConversion` global (a propósito) | Query nums/bools: `@Type()` en DTOs; comment en `main.ts` |
| **BN-PIPE-05** | 🟡 | Pipe en `main.ts`, filter/interceptor en `AppModule` | DX menor; no bug |

---

## 6. Backlog remediación (BN-FIX)

Orden sugerido (impacto / riesgo prod):

| ID | Estado | Acción | Cierra |
|----|--------|--------|--------|
| **BN-FIX-01** | ✅ | Mover SQL/ownership/UPDATE de `AlmacenamientoController` → service | BN-CTRL-01, AQ-SOLID-03 |
| **BN-FIX-02** | ✅ | DTOs públicos dispositivos (`registrar` / `vincular-auth` / anonimizar body) | BN-DTO-03/04 |
| **BN-FIX-03** | ✅ | Reemplazar bodies inline pedidos/catálogo/cocina/domi/facturación por clases `@Is*` | BN-DTO-06…19 |
| **BN-FIX-04** | ✅ | Query DTOs validar-código / geografia; `@IsBoolean` CrearPedido; Cotizar cableado | BN-DTO-20/21/22/31/32 |
| **BN-FIX-05** | ✅ | Billing: auditoria fuente + log error renovación + contador `renovaciones_fallos` | BN-EXC-01/02/05 |
| **BN-FIX-06** | ✅ | `forbidNonWhitelisted: true` en ValidationPipe (+ smoke) | BN-PIPE-03 |

**Después (calidad / a pulir):**  
→ Lista viva: [`docs/REMEDIACION_NEST_AUTH_2026-08-07.md`](../../REMEDIACION_NEST_AUTH_2026-08-07.md) §3.  
Prioridad código: BN-MOD-05 · BN-CTRL-04/05/07/10–12 · residuales finanzas/domiciliarios/super-admin UUID.  
~~BN-DTO-23…28/33~~ ✅ · ~~BN-MOD-03~~ 🟡 aceptado · ~~BN-PIPE-04~~ 🟡 aceptado (estrategia `@Type`).
No confundir con F5 humano (térmica / Wompi / VPS).

---

## 7. Cómo verificar al remediar

| Cambio | Evidencia |
|--------|-----------|
| DTOs nuevos | `POST` con body inválido → 400 `SOLICITUD_INVALIDA`; props extra → 400 si `forbidNonWhitelisted` |
| Almacenamiento | Upload imagen producto → URL en BD + menú invalidado; sin SQL en controller |
| Billing | Pago aprobado sin fuente → log error + flag/estado visible (no solo warn) |
| Pipe global | `scripts/verificar-ci.ps1` + smoke login/pedido/caja |

---

## Changelog de este documento

| Fecha | Cambio |
|-------|--------|
| 2026-08-07 | **Residuales** BN-DTO-28/33 · BN-MOD-03 alias `/salud/completo` · BN-PIPE-04 doc `@Type` · `verificar-bn-residuales.ps1` OK |
| 2026-08-07 | **BN-DTO-24…27** query DTOs pedidos/costeo/upload/retorno; `verificar-bn-dto-query-rest.ps1` OK |
| 2026-08-07 | **BN-DTO-23** `TimelineAuditoriaDto` + `verificar-bn-dto-auditoria.ps1` OK · **BN-EXC-03/04** throw/audit + `consulta_fallida` |
| 2026-08-07 | Doc cierre + **a pulir**: enlace `REMEDIACION_NEST_AUTH_2026-08-07.md`; BN-DTO-01/02 · BN-CTRL-02/03 · BN-EXC-18 ✅; BN-FIX-01…06 ✅ |
| 2026-08-07 | BN-DTO-01/02 ✅ FCM; BN-CTRL-02/03 ✅; BN-EXC-18 ✅; BN-FIX-01…06 ✅; pipe `forbidNonWhitelisted` |
| 2026-08-05 | Enlace a Prompt 04 (`AUDITORIA_APIS_REST.md`) |
| 2026-08-05 | **Creación** Prompt 02 — BN-MOD/CTRL/DTO/EXC/PIPE + BN-FIX-01…06; enlazado MASTER / AVANCE / README / Prompt 01 |

---

*Fin — Auditoría Backend NestJS (Prompt 02).*
