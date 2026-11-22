# Foody — Auditoría funcionalidad huérfana (Prompt 28)

> **Fecha:** 2026-08-06  
> **Alcance:** mapa funcional backend ↔ Flutter ↔ BD (no calidad de código).  
> **Base:** [`MAPA_FOODY.md`](MAPA_FOODY.md) (Prompt 00) + cruce estático controllers Nest ↔ repos/pantallas `lib/features` + `lib/core`.  
> **Estado oficial:** hallazgos también en [`MASTER_STATUS.md`](MASTER_STATUS.md) § Funcionalidad huérfana (HUER-\*).  
> **Método:** lectura estática (grep rutas Dio vs `@Get|@Post|@Patch|@Delete`). Sin click-through en dispositivo en esta pasada.

---

## Veredicto

| Pregunta | Respuesta corta |
|----------|-----------------|
| ¿Backend invocable solo por API/scripts (no Flutter)? | **Sí** — ops intencional + ~10–12 huérfanos de producto |
| ¿Botones Flutter sin API real? | **Casi no** — 0 `onPressed: () {}` en features; 1 badge muerto |
| ¿Endpoints sin consumo Flutter? | **Sí** — prioridad/obs KDS, costeo combos, ganancias domi, tipos docs |
| ¿Servicios/repos sin widget? | **Sí** — métodos muertos + legacy `lib/services/` |
| ¿Modelos nunca mostrados? | **Pocos** — legacy `ConfigLugar`; campo dashboard `pedidos_pendientes_qr` |
| ¿Permisos que la UI no respeta? | **Sí** — tab Rentabilidad sin `ver_finanzas` |
| ¿Config BD sin panel? | **Sí** — márgenes sede; tablas schema-only |
| ¿Opciones visibles que no hacen nada? | **Sí** — badge No disponible; config super sin efecto runtime |
| ¿Pantallas a medias? | **Sí** — FE DIAN pausada; finanzas sin editar costo fijo; espera domi |
| ¿Datos almacenados sin consumidor? | **Sí** — `presentaciones_compra`, `ajustes_stock` sin Nest |

**Global:** el núcleo pedido→caja→KDS→inventario está cableado (~98% botones→API). Los huérfanos reales son **feature half-built** (costeo combos, prioridad KDS, ganancias indep.) y **config engañosa** (super global / márgenes sede).

Leyenda fix: **CONECTAR** = cablear UI/repo existente · **COMPLETAR** = lógica a medias · **OCULTAR** = quitar affordance · **UI_NUEVA** = falta pantalla · **DEPRECATE** = borrar/código muerto · **OPS** = intencional no-UI.

---

## Respuestas a las 10 preguntas

### 1. Backend que nunca se invoca desde el frontend

| ID | Ubicación | Fix |
|----|-----------|-----|
| **HUER-API-COC-01** (= COC-UI-PRIO-01) | `PATCH /cocina/items/:item_id/prioridad` — `cocina-tickets.controller.ts:75-88` | **CONECTAR** botón Urgente en `kds_screen.dart` |
| **HUER-API-COC-02** | `PATCH /cocina/items/:item_id/observaciones` — `:60-73` | **CONECTAR** o **DEPRECATE** (notas ya vienen del pedido) |
| **HUER-API-COST-01** | `GET /costeo/combos/:sucursal_id` — `costeo.controller.ts:76` | **CONECTAR** en Costos/Márgenes |
| **HUER-API-COST-02** | `POST /costeo/combos/:id/recalcular` — `:135` | **CONECTAR** (mismo patrón que producto) |
| **HUER-API-DOM-01** | `GET /domiciliarios/ganancias` — `domiciliarios.controller.ts:302` | **UI_NUEVA** sección en dashboard indep. |
| **HUER-API-DOM-02** | `GET /domiciliarios/documentos/tipos` — docs controller `:25` | **CONECTAR** (UI hardcodea 3 tipos) o **DEPRECATE** |
| **HUER-API-PRIV-01** | `DELETE /dispositivos/anonimizar/:device_id` | **UI_NUEVA** (privacidad cliente) o dejar API-only |
| **HUER-OPS-*** | `/impresion/*`, `/notificaciones/*`, `/health*`, webhook Wompi, cron limpia promos | **OPS** — no son huérfanos de producto |

### 2. Pantallas / botones sin API real

| ID | Ubicación | Fix |
|----|-----------|-----|
| **HUER-UI-01** | Badge «No disponible» `onTap: () {}` — `menu_admin_screen.dart:1791` (el badge «Sin cocina» sí llama API) | **OCULTAR** o **CONECTAR** toggle disponibilidad |
| **HUER-UI-02** | `panel_restaurante_screen.dart:606` — `?seccion=` inválida → «en construcción» | **OCULTAR** / redirect |
| — | Qty pill carrito `onTap: () {}` — sink intencional | No huérfano |

### 3. Endpoints implementados nunca consumidos (producto)

Ver §1. Ya **no** huérfanos (cerrados 2026-07-02): DELETE cocina/impresora, recalcular subreceta, historial producciones.

### 4. Servicios / repos sin widget

| ID | Ubicación | Fix |
|----|-----------|-----|
| **HUER-REPO-01** | `InventarioRepository.costosProductos` — `inventario_repository.dart:62-67` (0 callers; duplica costeo) | **DEPRECATE** |
| **HUER-REPO-02** | `CatalogoAdminRepository.vincularExtra` — `catalogo_admin_repository.dart:106` | **DEPRECATE** (UI usa `configurarToppingsProducto`) |
| **HUER-REPO-03** | `FinanzasRepository.actualizarCostoFijo` — `finanzas_repository.dart:47` | **COMPLETAR** diálogo editar en `finanzas_admin_screen` |
| **HUER-REPO-04** | `PromocionesRepository.listarStoriesCiudad` `@Deprecated` | **DEPRECATE** borrar |
| **HUER-SVC-LEG-01** | Legacy sin imports Foody: `CleanupService`, `ConfigLugarService`, `ImageUploadService`, `IndexErrorService`, `LugarAmbientMusicService`, `PlanFeatureService` + `plan_selection_dialog`, etc. (`lib/services/`) | **DEPRECATE** (limpieza P3) |
| **HUER-DEAD-01** | `AppController` / `AppService` no registrados en `AppModule` | **DEPRECATE** |

### 5. Modelos / campos nunca mostrados

| ID | Ubicación | Fix |
|----|-----------|-----|
| **HUER-MOD-01** | `ConfigLugar` + Firestore — `lib/models/config_lugar.dart` | **DEPRECATE** |
| **HUER-DASH-01** (= DASH-ORPH-01) | `pedidos_pendientes_qr` en `GET /dashboard/resumen` — `dashboard.service.ts`; UI admin no lo pinta (sí existe en mesas vía otro payload) | **CONECTAR** KPI o quitar del payload dashboard |
| **HUER-MOD-02** | Modelos `lib/features/**/domain/` | En uso — no huérfanos |

### 6. Permisos que ninguna pantalla respeta (mismatch)

| ID | Ubicación | Fix |
|----|-----------|-----|
| **HUER-PERM-01** | `GET /analitica/rentabilidad` exige `@Permisos('ver_finanzas')` (`analitica.controller.ts:182-184`); tab Rentabilidad en `analitica_screen.dart` **no** chequea `ver_finanzas` → 403 silencioso/ruido | **CONECTAR** ocultar tab sin permiso |
| **HUER-PERM-02** | `finanzas` no está en matriz plan (`PlanModulosFoody` / `@RequiereModulo`); solo `ver_finanzas` | Documentar como intencional o añadir plan gate |
| **HUER-PERM-03** | Facturación visible (enterprise) con FE DIAN pausada | **OCULTAR**/banner más fuerte (= FE) |

### 7. Configuraciones en BD sin panel (o panel mentiroso)

| ID | Ubicación | Fix |
|----|-----------|-----|
| **HUER-CFG-01** (= CFG-MARGEN-UI-02) | `sucursales.margen_objetivo_default`, `umbral_alerta_margen` — leídos por costeo; **sin** PATCH/UI | **UI_NUEVA** + API write |
| **HUER-CFG-02** (= CFG-GLOBAL-DEAD) | `configuracion_global_foody` — Super UI edita; runtime alertas/dispatch hardcode (salvo `dias_datos_restaurante_bloqueado`) | **COMPLETAR** cable runtime **o** **OCULTAR** claves muertas |
| **HUER-CFG-03** | Sin `PATCH /sucursales/:id` (nombre/dirección sede) | **UI_NUEVA** necesita API primero |
| **HUER-DB-01** | Tabla `presentaciones_compra` — 0 refs en `foody_backend/src` | **DEPRECATE** o implementar |
| **HUER-DB-02** | Tabla `ajustes_stock` — 0 refs Nest (ajustes van por PATCH inventario → movimientos) | **DEPRECATE** schema o usar |
| **HUER-DB-03** | `margenes_venta`, `fuentes_pago` | Internos OK sin panel staff |
| **HUER-DB-04** | `zonas.poligono` (= CFG-POLIGONO-03) | DEPRECATE ✅ COMMENT mig 088 |

### 8. Opciones visibles que no hacen nada real

| ID | Evidencia | Fix |
|----|-----------|-----|
| **HUER-UI-01** | Badge tappable vacío | OCULTAR/CONECTAR |
| **HUER-CFG-02** | Editar umbrales/comisión en Foody Control **no cambia** comportamiento | COMPLETAR/OCULTAR |
| **HUER-HALF-FE** | Emisión «factura» local sin DIAN/CUFE | COMPLETAR integración o OCULTAR claim legal |

### 9. Pantallas que parecen completas pero están a medias

| ID | Ubicación | Fix |
|----|-----------|-----|
| **HUER-HALF-01** | `FacturacionAdminScreen` — UI completa + banner pausa DIAN | **COMPLETAR** (X-01) o **OCULTAR** módulo |
| **HUER-HALF-02** | Finanzas: create/pay/delete costos fijos; **sin** edit pese a repo | **COMPLETAR** |
| **HUER-HALF-03** | `DomiciliarioEsperaScreen` — solo CTA login; sin poll estado docs | **COMPLETAR** |
| **HUER-HALF-04** | Costos/Márgenes: productos/subrecetas OK; **combos** API sin UI | **CONECTAR** (§1) |
| **HUER-HALF-05** | KDS lee `[URGENTE]` / obs pero no las escribe | **CONECTAR** |

### 10. Datos almacenados que ningún módulo consume

| ID | Evidencia | Fix |
|----|-----------|-----|
| **HUER-DB-01/02** | `presentaciones_compra`, `ajustes_stock` | DEPRECATE o implementar |
| **HUER-DB-04** | `poligono` | DEPRECATE |
| **HUER-CFG-02** | Filas config global no leídas en runtime | Cablear o no seed/UI |

---

## Inventario priorizado (acción)

| Prio | ID | Sev | Fix | Esfuerzo |
|-----:|----|-----|-----|----------|
| 1 | HUER-PERM-01 | Alta | CONECTAR gate tab | XS |
| 2 | HUER-CFG-02 | Alta | COMPLETAR/OCULTAR | M |
| 3 | HUER-API-COC-01 | Media | CONECTAR KDS urgente | S |
| 4 | HUER-API-COST-01/02 | Media | CONECTAR combos costeo | S |
| 5 | HUER-API-DOM-01 | Media | UI_NUEVA ganancias | S |
| 6 | HUER-UI-01 | Media | OCULTAR/CONECTAR badge | XS |
| 7 | HUER-REPO-03 / HALF-02 | Media | COMPLETAR edit costo fijo | S |
| 8 | HUER-CFG-01 | Media | UI_NUEVA márgenes sede | M |
| 9 | HUER-HALF-01 | Alta (producto) | FE / OCULTAR | L (bloqueado X-01) |
| 10 | HUER-REPO-01/02/04 + SVC-LEG + DEAD | Baja | DEPRECATE | S–M |

---

## Qué NO es huérfano (evitar re-auditar)

- Núcleo: auth, pedidos public/staff, mesas, caja, catálogo CRUD, KDS estado, inventario/traslados, costeo resumen/subrecetas/producciones, analítica (salvo gate rentabilidad), reportes, zonas, promos, pagos Wompi checkout, super CRUD restos/planes, FCM cola (cron).
- Impresión Python / health / webhooks / crons — consumidores no-Flutter **intencionales**.
- `onPressed: () {}` en `lib/features/` — **0** (salvo sink carrito y badge §2).

---

## Verificación de esta auditoría

| Check | Resultado |
|-------|-----------|
| Mapa Prompt 00 | `docs/MAPA_FOODY.md` leído |
| Grep `prioridad` / `costeo/combos` / `ganancias` en `lib/` | Sin consumers Dio |
| Grep `costosProductos(` callers | Solo definición repo |
| Grep `ver_finanzas` en `analitica_screen` | 0 matches |
| Grep `presentaciones_compra` / `ajustes_stock` en Nest `src` | 0 matches |
| Click-through dispositivo | **No corrido** |

Al cerrar un HUER-\*: marcar ✅ aquí + MASTER + viñeta AVANCE.
