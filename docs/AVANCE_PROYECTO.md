# Foody — avance del proyecto (documento vivo)

> **Los agentes deben leer este archivo al inicio de cada sesión de implementación y actualizarlo al terminar.**
> Regla Cursor: `.cursor/rules/foody-avance-documentar.mdc`
> Especificación objetivo: `INFRAESTRUCTURA/GUIA_DESARROLLO_FOODY_CURSOR.md` (sprints 1–11).

**Última actualización:** 2026-06-24 — Fix plan Pro tras pago: guard lee BD (no JWT viejo); `/auth/perfil` renueva token si cambió el plan.

**Próximo paso recomendado:** Reiniciar backend + recargar panel admin; webhook Wompi en URL pública.

> **Estado por módulo (hecho / falta):** **`docs/MODULOS_ESTADO.md`** — consultar siempre; actualizar al cerrar cada tarea.

> **Auditoría E2E (flujos operativos):** `docs/AUDITORIA_FLUJOS_E2E.md` — matriz mesa/cocina/caja/domi/inventario, 13 riesgos, plan de remediación P0–P5.
> **Auditoría de analista:** `docs/ANALISIS_SISTEMA.md` — brechas spec vs implementado, casos hipotéticos de restaurante y roadmap por bloques.
> **Flujos por rol (HTML):** `INFRAESTRUCTURA/foody_flujo_completo_pantallas.html` · mapa código `docs/MAPA_FLUJOS_PANTALLAS.md`.
> **Planes comerciales (básico/pro/enterprise):** 🟡 módulos + **límites numéricos** (sucursales/usuarios) — ver `docs/PLANES_SUSCRIPCION.md`.

---

## Resumen de 1 minuto (léelo primero)

| Qué | Estado |
|-----|--------|
| **Mapa módulos (hecho/falta)** | 📋 **`docs/MODULOS_ESTADO.md`** — leer para saber qué falta por área |
| Cliente sin login | ✅ Ciudad → menú → carrito → pedido → seguimiento + **mis pedidos** |
| Pedido mesa QR | ✅ `/mesa/:qrToken` → ciudad+sucursal auto (`MesaSesionService`) → menú → checkout mesa |
| Backend pedidos | 🟡 | Stock valida al crear, **descuenta al confirmar/aprobar** + devolución cancel/rechazo; asignación mesera; falta DIAN |
| Admin login | ✅ `admin@foody.demo` / `123456` → panel |
| Kanban pedidos | ✅ Reloj por estado, Confirmar/Aprobar, columna **Pagando** (mesa/para llevar), broadcast Realtime |
| Mesas admin / mesero | 🟡 | Grid + CRUD + QR + transferir + **turno mesas admin** + DELETE ítem en sheet; cuenta acumulada | — | S4+ |
| Caja / menú CRUD admin | 🟡 | Productos, toppings, bebidas, combos; enlace «Ver costos»; **precio local + llevar** en diálogo menú | margen/precio sugerido por canal | S2 UI menú |
| Cocinas / impresoras / KDS | ✅ CRUD admin + panel cocina (`cocina@foody.demo`/123456) + estado por ítem |
| Zonas domicilio + descuentos | ✅ Anillos km/precio + mapa OSM admin + cotizar API + descuento Kanban |
| Mapas / geolocalización | ✅ `flutter_map` + OSM; `GET /geografia/buscar` (Photon); sin Google Maps en cliente |
| Horarios sucursal (admin) | ✅ `HorariosAdminScreen` + `GET/PATCH /sucursales/.../horarios` |
| Insumos admin | ✅ | Mercado + subrecetas + **badges/barras stock**, banner alertas bajo stock, FAB |
| Costeo industrial (KYG) | 🟡 Parcial | UX flujo plato→costeo + **impacto stock por plato** + líneas «descuenta X» en receta/incluidos | Fase C canal mesa/domicilio | S2 / post-S6 |
| Reportes UI | ✅ Tabs + tarjeta **Cuadre caja** (pedidos vs movimientos, por método) |
| Facturación admin | 🟡 Config fiscal, listado, emitir borrador, HTML preview |
| Alertas admin | 🟡 Listar + marcar revisada + **disparadores automáticos** (incl. **pedido sin stock**) + evaluar reglas batch |
| Usuarios staff admin | 🟡 Listar, crear, activar/desactivar; **selector sucursal** si `gestionar_sucursales` |
| Domiciliarios planta | ✅ Asignación Kanban + app `/admin/domiciliario` con tabs Activos/Historial/Stats |
| Domiciliarios independientes | 🟡 Dispatch + ofertas + registro `/domiciliario/registro` + app independiente |
| Super Admin (Foody Control) | 🟡 Avanzado | Panel 7 secciones; **onboarding compartido** `OnboardingRestauranteService`; plan limita módulos |
| Multi-sucursal Fase 1–2 | ✅ Avanzado | `SucursalScopeService` en inventario, pedidos, caja, dashboard, catálogo, facturación, mesas, **zonas**, **alertas**; traslados con scope; UI hermanas + traslados | Dashboard cadena Fase 3 | `docs/MULTI_SUCURSAL.md` |
| Legacy Firebase | 🟡 Aislado en `lib/legacy/`; `lib/features/` sin imports a `screens/` |
| Verificación Paso 0 (API+BD) | ✅ | `scripts/verificar-paso0.ps1` — 25/25 (2026-06-08) | Prueba UI Flutter por rol | Manual | Paso 0 §3 |
| QA auditoría E2E (P0–P2) | ✅ | `scripts/verificar-todos-e2e.ps1` — **4/4** (2026-06-19): pagos mesa, domicilio, inventario→menú, transferencia | P4.1 impresión física | Sprint 10 |
| Self-service (F1–F6) | 🟡 Parcial | Registro, Google, plan gratis, avisos, checkout Wompi, **UI upgrade + candados** | Webhook prod + F7 métricas | `docs/MODULO_SELF_SERVICE_PLANES.md` |

**Probar QR mesa:** `http://localhost:.../mesa/demo-mesa-1` (web) o deep link cuando exista.

**Migración nueva:** `041_mesera_asignacion_stock.sql` (`stock_descontado`, `mesera_id`, `mesera_asignada_id` en mesas). Aplicar antes de reiniciar backend.

> Detalle técnico permanente (variables, BD, endpoints): secciones **Referencias persistentes** más abajo.  
> Spec completa: `INFRAESTRUCTURA/` + `MEMORIA.md` (no copiar todo aquí; solo lo que el agente necesita a mano).

### Pospuesto por acuerdo (no implementar salvo petición explícita del usuario)

| Tema | Sprint spec | Notas |
|------|-------------|--------|
| **FCM** / push notifications | 7 | ✅ Avanzado — cola + cron + eventos pedido/domi; requiere `FIREBASE_SERVICE_ACCOUNT_PATH` en backend |
| **DIAN** / factura electrónica real | 9–11 | Proveedor FE; hoy HTML borrador basta |
| **Servidor Python** impresión | 10 | WebSocket + tickets cocina — **gateway NestJS** ✅; falta escpos físico |
| **Import Excel KYG** | — | `TABLA DE COSTEOS KYG.xlsx` solo referencia de fórmulas; datos se cargan manual en admin |

---

## Leyenda de estados

| Símbolo | Significado |
|---------|-------------|
| ✅ Avanzado | Usable en dev; cubre el flujo principal del sprint |
| 🟡 Parcial | Funciona pero falta spec completa, UX legacy o post-commit |
| ⏳ Pendiente | No iniciado en código Foody |
| 🚫 Bloqueado | Depende de otro módulo/infra |
| 📅 Planificado | Previsto en sprint N; no tocar antes sin acuerdo |

---

## Resumen por sprint (guía oficial)

| Sprint | Tema | Estado global | Notas |
|--------|------|---------------|-------|
| 1 | Fundación (Docker, BD, Auth, Flutter core) | ✅ Avanzado | Ver detalle abajo |
| 2 | Cliente: ciudades, restaurantes, menú | ✅ Avanzado | Combos en menú cliente; toppings modal |
| 3 | Pedidos y seguimiento | 🟡 Parcial | POST transacción ampliada; sin FCM/post-commit impresión |
| 4 | Panel admin básico | ✅ Avanzado | Kanban+reloj+acciones; mesas QR; dashboard; falta solo módulos sidebar 5+ |
| 5 | Caja y productos CRUD | ✅ Avanzado | Combos incluidos |
| 7 | Domiciliarios (sin FCM aún) | 🟡 Parcial | Planta + dispatch independientes; falta FCM push realtime |
| 8 | Super Admin completo | 🟡 Avanzado | Foody Control UI + usuarios + metadata planes; falta **PlanFeaturesGuard**, vencimiento auto, guard tenant | 8 |
| 9 | Reportes y facturación | 🟡 Parcial | Reportes MVP; facturación borrador+emisión; falta PDF DIAN |
| 10 | Python impresión | ⏳ Pendiente | |
| 11 | Producción y pulido | ⏳ Pendiente | |

---

## Sprint 1 — Fundación

| Ítem | Estado | Hecho | Falta | Por qué falta | Cuándo |
|------|--------|-------|-------|---------------|--------|
| Estructura repo in-place | ✅ | `lib/main.dart`, `foody_backend/`, `foody_supabase/`, `lib/features/` | — | — | — |
| Migraciones SQL | ✅ | `001`–`016` + seeds demo | RLS exhaustivo en prod | Sprint 11 | 11 |
| NestJS core + respuesta API | ✅ | `DatabaseModule`, interceptores, filtros | — | — | — |
| Auth JWT + guards | ✅ | Jwt, Rol, SuperAdmin, Suscripción, Usuario activo | Aplicar SuscripcionActiva en todos los módulos | Revisión sprint 8 | 8 |
| Flutter: tema, Dio, go_router | ✅ | `TemaFoody`, `ClienteDio`, `AppRouter` | Renombrar paquete `reserva_canchas` | Refactor no bloqueante | 11 |
| Login staff | ✅ | `StaffLoginScreen`, `AuthRepository` | — | — | — |

---

## Sprint 2 — App cliente (catálogo)

| Ítem | Estado | Hecho | Falta | Por qué falta | Cuándo |
|------|--------|-------|-------|---------------|--------|
| API ciudades/restaurantes/menú | ✅ | Módulos NestJS + repos Flutter | — | — | — |
| device_id + dispositivos | ✅ | `DispositivoService`, `POST /dispositivos/registrar` | FCM token en cliente | Sprint 7 | 7 |
| Splash + preferencia ciudad | ✅ | `FoodySplashScreen`, `CiudadPreferenceService` | Deep link universal FCM | Sprint 7 | 7 |
| Flujo ciudades → sucursales | ✅ | Pantallas `*_foody.dart` + rutas | Animaciones legacy completas | Opcional | 11 |
| Menú con categorías y búsqueda | ✅ | `MenuScreenFoody` (chips, cards, Foody colors) | Tabs sticky idénticos a `menu_sede_screen` | Prioridad baja | 11 |
| Modal toppings/bebidas | ✅ | `DetalleProductoSheet` + API toppings/bebidas | — | — | — |
| Combos en menú cliente | ✅ | Sección Combos en `MenuScreenFoody` | Modal detalle combo | Prioridad baja | 11 |
| Carrito Riverpod | ✅ | `carrito_provider`, líneas con clave única | — | — | — |
| Legacy `menu_sede_screen` | 🟡 | Sigue en `lib/screens/` (Firebase) | Eliminar cuando no queden imports | Limpieza continua | 11 |
| Pedido mesa QR cliente | ✅ | `/mesa/:qrToken`, `GET /menu/mesa/:qr_token` | PDF QR impresión | Sprint 5 mesas admin | 5 |

**Archivos clave:** `lib/features/menu/`, `lib/features/ciudades/`, `lib/features/restaurantes/`, `lib/core/dispositivo/`.

---

## Sprint 3 — Pedidos y seguimiento

| Ítem | Estado | Hecho | Falta | Por qué falta | Cuándo |
|------|--------|-------|-------|---------------|--------|
| POST /pedidos transacción | 🟡 | Validación precios, horario, ítems, historial, **domicilio por zona**, inventario, caja, auditoría, **IVA en pedido**, borrador factura | Combos en INSERT; integración DIAN; 18 pasos MEMORIA al 100% | Spec ERP completa | 5–9 |
| Estados iniciales | ✅ | Mesa → `pendiente_aprobacion`; resto → `pendiente` | — | — | — |
| GET /pedidos/:id/estado | ✅ | Historial público | — | — | — |
| Checkout cliente | ✅ | Tipos para llevar/domicilio/**encargo**, dirección, **geo lat/lng + mapa**, cotización zona | — | — | — |
| Seguimiento cliente | 🟡 | Timeline + broadcast; **mis pedidos** por device_id | Push al cambiar estado | FCM sprint 7 | 7 |
| Promociones / historias | 🟡 | Admin publicar URL imagen; cliente stories en menú | Subir foto Storage | Bloque 5.6 | 5 |
| Realtime broadcast backend | ✅ | `RealtimeBroadcastService` + hooks pedidos/mesas; Flutter `FoodyRealtime` | Revisar en prod con RLS aplicado | Tras migración 028 | 4 |
| E2E documentado | ⏳ | Flujo manual posible | Script o checklist en CI | Sprint 11 | 11 |

**Archivos clave:** `foody_backend/src/modulos/pedidos/`, `lib/features/pedidos/`.

**Inventario en pedido:** valida al crear; **descuenta al confirmar/aprobar** (`stock_descontado`); restaura en cancel/rechazo. Solo productos con receta/incluidos/combos expanden ingredientes.

---

## Sprint 4 — Panel admin básico

| Ítem | Estado | Hecho | Falta | Por qué falta | Cuándo |
|------|--------|-------|-------|---------------|--------|
| GET/PATCH pedidos admin | ✅ | Lista con `estado_desde`, cambiar estado, aprobar/rechazar | — | — | — |
| Login → panel por rol | ✅ | Redirección dashboard en splash/login | App cocina separada | Un `main.dart` | 7 |
| Dashboard resumen | ✅ | Tarjetas + badge QR + tap → pedidos/mesas | Gráficos avanzados | Sprint 9 | 9 |
| Kanban pedidos | ✅ | Reloj 15 min rojo, acciones rápidas, broadcast Realtime, timer 30s | Asignar domiciliario en “listo” | Sprint 7 | 7 |
| Mesas | 🟡 | Grid, CRUD, QR, transferir; `mesera_asignada_id` en API; panel mesero tap libre → `PedidoCajeroScreen` | UI admin asignar mesas por turno; liberar mesa en todos los cierres | S4+ | Post-S1 |
| Panel mesero | 🟡 | `/admin/mesero`: mesas + kanban **5 columnas** (Por confirmar → Pagando) | Banner contador QR; S6 ciudad auto en QR | S5–S6 | 4 |
| Menú dinámico permisos | ✅ | `MenuAdminDinamico` por permisos JWT | Pantallas caja/menú CRUD/inventario | Sprint 5–6 | 5–6 |
| Cliente QR → pedido mesa | ✅ | `/mesa/:qrToken`, checkout `tipo=mesa` | Escaneo cámara nativo | Mejora UX | 11 |
| Módulos sidebar (caja, menú CRUD…) | ✅ | `CajaAdminScreen` (fiados), `MenuAdminScreen` | Panel cajero mesa selector | Mejora | 5 |

**Archivos clave:** `lib/features/admin/`, `lib/features/mesa/`, `foody_backend` pedidos/dashboard/mesas/menu.

---

## Sprint 5 — Caja y productos CRUD

| Ítem | Estado | Hecho | Falta | Por qué falta | Cuándo |
|------|--------|-------|-------|---------------|--------|
| NestJS módulo caja | ✅ | abrir, cerrar, movimientos, gastos, fiados crear/cobrar | — | — | — |
| NestJS catálogo admin | ✅ | categorías, productos, toppings, bebidas, combos | — | — | — |
| Flutter menú admin | ✅ | tabs Productos/Toppings/Bebidas/Combos | imágenes | 11 |
| Panel cajero constructor pedido | ✅ | `PedidoCajeroScreen` + sidebar «Nuevo pedido» | Mesa con selector QR | Mejora | 5 |

**Archivos:** `foody_backend/src/modulos/caja/`, `catalogo/`, `lib/features/caja/`, `lib/features/catalogo/`.

---

## Sprint 6 — Inventario

| Ítem | Estado | Hecho | Falta | Por qué falta | Cuándo |
|------|--------|-------|-------|---------------|--------|
| Descuento stock en pedido | ✅ | `validarStock` al crear con **`detalles`**; `descontarStock` al confirmar; diálogo Flutter `mostrarDialogoStockSiAplica` en checkout/cajero | — | — | — |
| NestJS inventario | ✅ | ingredientes, compras, movimientos, costos, receta, conteo cerrar | — | — | — |
| Flutter inventario admin | ✅ | tabs + compra/ajuste/receta/conteo (stock teórico en diálogo, `mensajeErrorHttp`) | — | — | — |
| Recalcular costo_calculado | 🟡 | `CosteoService` merma/subrecetas/combos + cascada compra/ajuste | UI subrecetas/empaques en configurar receta | Fase 1 restante | Fase 1 |

**Archivos:** `foody_backend/src/modulos/inventario/`, `lib/features/inventario/`.

---

## Módulo costeo industrial (Fase 1 — en curso)

> Spec completa: **`docs/MODULO_COSTEO.md`** · Excel referencia: `INFRAESTRUCTURA/TABLA DE COSTEOS KYG.xlsx`

| Ítem | Estado | Hecho | Falta | Por qué falta | Cuándo |
|------|--------|-------|-------|---------------|--------|
| Spec + decisiones producto | ✅ | `docs/MODULO_COSTEO.md` (fórmulas, fases, casos borde) | — | — | — |
| Motor `CosteoService` | ✅ | Merma, subrecetas recursivas, margen_error, cascada, empaques domicilio | — | — | — |
| Costo domicilio (empaques) | ✅ | `tipo_item=empaque`; descuento solo en pedido domicilio | — | — | — |
| Costeo combos (ganancia) | ✅ | `recalcularCombo`, alerta margen, tab Costos | — | — | — |
| Subrecetas KYG (Fase B) | ✅ | `POST/PATCH /costeo/subrecetas`, detalle, recalcular; `dialogo_subreceta_form.dart`; cascada a platos que usan la subreceta | Producción en lote (`usa_produccion_lote`) | Fase 2 | Fase 2 |
| Alertas margen / precio sugerido | ✅ | `precio_sugerido`, alertas, tab Costos con umbral | — | — | — |
| UI editor receta producto | ✅ | Ingrediente / subreceta / empaque en `InventarioAdminScreen` | — | — | — |
| Demo BD subreceta+empaque | ✅ | Migración `033` (carne preparada, caja/bolsa en hamburguesa) | — | — | — |
| API costeo | ✅ | `GET /costeo/resumen`, `GET /costeo/productos/:id/impacto-stock`, subrecetas CRUD+detalle+recalcular, `POST /costeo/recalcular`, combos | — | — | — |
| Migración BD | ✅ | `032_costeo_industrial.sql` | — | — | — |
| Productos con ítems de menú incluidos | ✅ Avanzado | Tabla `034_producto_items_incluidos.sql`; `GET/PUT /productos/:id/items-incluidos`; costeo + stock expandido; tab Incluye; KDS | Demo carne/hígado +2 rosquetes (seed opcional) | Sprint costeo |
| Precio local vs para llevar | ✅ Avanzado | Migración `035_precio_para_llevar.sql`; `precioVentaProducto()` en pedidos; admin `actualizarPreciosCanal`; menú/checkout/cajero usan canal | Precio sugerido llevar en Costos | S2 |
| Import Excel KYG | 🚫 No aplica | — | — | Solo referencia fórmulas | Acuerdo 2026-06-08 |
| Simulador popularidad | ⏳ | — | Hojas Excel Popularidad Mesa/Domicilio | Opcional | Fase 3 |

**Spec admin (menú, costos, incluidos):** `docs/ADMIN_MENU_COSTEO.md` — prioridad sobre UI legacy en Inventario.

**Archivos:** `foody_backend/src/modulos/costeo/`, `lib/features/catalogo/`, `lib/features/inventario/` (migrar UI a spec admin).

---

## Multi-sucursal (Alitas House Norte / Sur)

> **Spec:** `docs/MULTI_SUCURSAL.md` · Reglas: `INFRAESTRUCTURA/reglas_negocio_foody.md` § Multi-sucursal · Cursor: `.cursor/rules/foody-multi-sucursal.mdc`

| Ítem | Estado | Hecho | Falta | Por qué / cuándo |
|------|--------|-------|-------|------------------|
| Modelo documentado (aislamiento por sede) | ✅ Avanzado | `docs/MULTI_SUCURSAL.md`, `MEMORIA.md` roles, reglas negocio ampliadas | — | Acuerdo producto 2026-06-09 |
| Excepción inventario hermano (solo lectura) | ✅ Avanzado | Permiso `ver_inventario_otras_sucursales` (migr. `043`); `GET /inventario/hermanas/resumen`; `InventarioHermanasPanel` | — | Fase 1 |
| Guard API escritura = `sucursal_id` JWT | ✅ Avanzado | `SucursalScopeService` en inventario, pedidos, caja, dashboard, catálogo, facturación, mesas, **zonas**, **alertas** | — | Fase 2 |
| Selector sucursal en panel admin | ✅ Avanzado | Solo `gestionar_sucursales`; chip sede fija para admin de sucursal | — | Fase 1 |
| Traslados stock entre sedes | ✅ Avanzado | Backend traslados + scope GET/POST + `inventario_traslados_panel.dart` | — | Fase 2 |
| Dashboard consolidado cadena | ⏳ Pendiente | — | Rol `gerente_cadena` + KPIs multi-sede | Fase 3 |

---

## Sprints 7–11 (pendientes)

| Sprint | Estado | Dependencias | Cuándo abordar |
|--------|--------|--------------|----------------|
| Multi-sucursal Fase 2 | ✅ Avanzado | Scope zonas/alertas/traslados; script `verificar-multi-sucursal.ps1` | Dashboard cadena | Fase 3 |
| 5 restante | 🟡 | Caja/catálogo base | cuentas-por-cobrar, panel cajero |
| 6 restante | ✅ | Inventario + UX stock/conteo | — | — |
| 7 Domiciliarios + FCM | ✅ Avanzado | Planta + dispatch + push ofertas + deep links |
| 8 Super Admin | 🟡 Avanzado | Cron vencimiento + **`LIMITES_POR_PLAN`** (sucursales/usuarios staff) | cobro recurrente | 8 |
| 9 Reportes/facturación | 🟡 | Reportes + borrador/emitir/anular + scope sucursal | PDF DIAN proveedor FE | 9–11 |
| 10 Impresión Python | 🟡 | Python WS MVP + **`ImpresionService`** NestJS (cola `impresion_cocina_jobs`) | python-escpos real | 10 |
| 11 Producción | ⏳ | Todo anterior | — |

---

## Deuda legacy (no duplicar)

| Qué | Estado | Acción cuando |
|-----|--------|----------------|
| `lib/screens/`, Provider, Firebase pedidos | 🟡 Coexiste | Solo `lib/legacy/main_reserva_canchas.dart`; ver `lib/legacy/README.md` |
| `lib/services/pedido_service.dart` | 🟡 | No usar en flujos Foody; usar `PedidosClienteRepository` |
| Paquete `reserva_canchas` | 🟡 | Renombrar en refactor global |
| `menu_sede_screen.dart` | 🟡 | Referencia UI; ruta Foody es `MenuScreenFoody` |

---

## Backend — módulos existentes

| Módulo | Estado |
|--------|--------|
| auth, salud, ciudades, restaurantes, menu, dispositivos | ✅ |
| pedidos (público + staff), dashboard, mesas, menu/mesa QR | ✅ |
| super-admin | ✅ |
| caja, catalogo | 🟡 |
| inventario | 🟡 |
| costeo | ✅ |
| domiciliarios (planta + independientes) | 🟡 |
| reportes | 🟡 |
| facturación | 🟡 |
| impresión | 🟡 |

---

## Flutter — features existentes

| Feature | Rutas / notas | Estado |
|---------|---------------|--------|
| splash | `/splash` | ✅ |
| ciudades / restaurantes / sucursales | `/cliente`, `/ciudades/...` | ✅ |
| menu + carrito + checkout + seguimiento | `/menu/...`, `/carrito/...`, `/checkout/...`, `/pedidos/.../seguimiento` | ✅ |
| mesa QR | `/mesa/:qrToken` | ✅ |
| auth staff | `/admin/login` | ✅ |
| panel restaurante / foody control | `/admin/panel`, `/admin/foody-control` | ✅ / 🟡 Avanzado |
| caja / catálogo / inventario admin | panel sidebar `caja`, `menu`, `inventario` | 🟡 |
| domiciliario app | `/admin/domiciliario` planta · `/domiciliario/independiente` | 🟡 |
| facturación admin | panel sidebar `facturacion` | 🟡 |

---

## Últimos cambios (changelog)

- **2026-06-24:** **Fix plan Pro tras Wompi** — `PlanFeaturesGuard` consulta plan en BD (JWT podía quedar `gratis`); `GET /auth/perfil` emite `token` nuevo si cambió plan/permisos; Flutter `sincronizarPerfil` guarda JWT actualizado.
- **2026-06-24:** **OAuth Google staff móvil** — `GoogleOAuthStaffService` (redirect web `/admin/registro` vs `foody://login`); detección sesión en registro; chip «Cuenta Google conectada»; diálogo correo duplicado; `AndroidManifest` + `Info.plist` + script Supabase `foody://login`.
- **2026-06-24:** **Self-service F6 UI** — `MejorarPlanScreen` + `PagosRepository`; candados en sidebar (módulos Pro/Enterprise visibles con lock); `ModuloBloqueadoPlaceholder`; banner gratis/vencimiento con CTA; ruta `/admin/mejorar-plan`; ítem «Mejorar plan» en menú admin.
- **2026-06-24:** **Self-service F1–F3** — Migración `052_self_service_planes.sql` (plan `gratis`, OAuth en `usuarios`, `origen` en `restaurantes`); `OnboardingRestauranteService` compartido (super-admin + auth); `POST /auth/registro-restaurante` (rate limit 5/min) crea rest+sucursal+admin plan gratis; `POST /auth/login-google` (Supabase token→JWT); `plan-features.config.ts` tier `gratis` (3 staff, 1 sucursal); cron excluye plan gratis; Flutter `/admin/registro` + botón Google en login.
- **2026-06-24:** **Costeo UI fixes** — editor receta usa costo del backend (merma/rendimiento) coherente con margen/precio sugerido; diálogo margen muestra fórmula en vivo `costo÷(1−m%)`; `TabController` estable (pestaña «Qué va incluido» ya no expulsa); recarga silenciosa sin resetear pestañas; pestaña receta = solo receta (no suma incluidos).
- **2026-06-20:** **Spec módulo Analítica/BI** — `docs/MODULO_ANALITICA_BI.md` (Centro de Análisis: cocinas, inventario, domi, caja, riesgo, comparativas mes/rango; scope dueño vs admin; fórmulas; fases F1–F7). Solo documentación; extiende módulo `reportes`.
- **2026-06-19:** **QA E2E 4/4** — `scripts/verificar-todos-e2e.ps1` + `limpiar-demo-qa.ps1` (`Restaurar-InventarioDemo`); fixes: domiciliario ocupado ignora pedidos cancelados (`domiciliarios.service.ts`), libera asignación al cancelar pedido, scripts usan `pedido_id` en mesas y menú staff para disponibilidad.
- **2026-06-19:** **P4.2 + P5** — `GET /health/realtime`, banner admin Realtime, scripts `verificar-flujo-domicilio.ps1`, `verificar-inventario-menu.ps1`, `verificar-transferencia-mesa.ps1`, extensión `verificar-pagos-mesa.ps1`.
- **2026-06-19:** **P0–P3 auditoría E2E** — mesa/cobro, domicilio, inventario→menú, transferencia, caja; ver `docs/AUDITORIA_FLUJOS_E2E.md` + `FLUJO_ESTADOS_PEDIDOS.md`.
- **2026-06-19:** **`docs/MODULOS_ESTADO.md`** — mapa vivo de 20 módulos (hecho/falta/prioridad/backlog); enlace desde resumen de `AVANCE_PROYECTO.md`.
- **2026-06-19:** **Multi-sucursal UI** — selector sede admin recarga mesas/pedidos/KDS (`KeyedSubtree`, `didUpdateWidget`).
- **2026-06-12:** **Módulo 2 FCM ✅** — Cola reintenta si Admin no listo; `NotificacionesCronService`; `GET /notificaciones/diagnostico`, `POST /prueba`; push pendiente/confirmado/cancelado + rutas deep link; tap notificación local; `POST /auth/desactivar-fcm`; `verificar-fcm.ps1`.
- **2026-06-19:** **Sprint 5 P0 pagos** — `POST /pedidos/:id/cobrar` (CAJ-005); `pagos[]` al crear staff para llevar; `pedido_id` en `pagos_pedido`; comensal `PATCH .../comensal`; UI mesa (saldo, abonos, etiqueta comensal); cajero pago mixto.
- **2026-06-19:** **Sprint 7 FCM** — `NavegadorFcmFoody` deep links al abrir notificación.
- **2026-06-19:** **Sprint 8** — `SuscripcionesCronService` marca `vencida` cada hora.
- **2026-06-19:** **Sprint 10 MVP** — `foody_python_printer/main.py` WebSocket simulado.
- **2026-06-19:** Script `verificar-pagos-mesa.ps1`; fix `sincronizar-ip-movil.ps1` encoding UTF8.
- **2026-06-12:** **Firebase dual-flavor** — `flutterfire configure` cliente+equipo; `google-services.json` en `src/cliente/` y `src/equipo/`; `firebase_options_*.dart`; `FirebaseInicializador`; APK release compilados OK.
- **2026-06-12:** **Dos apps (cliente + equipo)** — `equipo` = dueño + domiciliario + staff en un solo APK (`app.foody.equipo`); `cliente` separado; guards en `app_router`; doc `INFRAESTRUCTURA/foody_multi_app_flavors.md`.
- **2026-06-12:** **RT-5 debounce + backlog §10** — `FoodyRealtime`: coalesce 300 ms por sucursal (`sucursal_actualizada`); `docs/ESTRATEGIA_REALTIME_FOODY.md` actualizado (RT-1…RT-5 ✅, §10 pendiente global: FCM/DIAN/impresión, QA, promos Storage, resync escenarios).
- **2026-06-12:** **UI brechas escenarios** — Mesas (unir/reservar/salió sin pagar/cobro mixto), KDS `no_disponible`, caja devolución/arqueo ciego, traslados inventario, timeline auditoría, anular factura; migración `047` aplicada.
- **2026-06-17:** **Cuadre demo + I4** — `046_caja_cuadre_demo_cleanup.sql` (limpia ventas canceladas, backfill); reportes usan `COALESCE(p.created_at, m.created_at)` en cuadre; QA `verificar-cuadre-caja.ps1` → diferencia 0; `endpoints_api_foody.md` sincronizado (~170 rutas).
- **2026-06-12:** **Escenarios negocio sincronizados** — `docs/ESCENARIOS_NEGOCIO_FOODY.md`: 65→**73** ✅ tras auditoría (cobro mesa/caja, DELETE ítem, cuadre, promos código, PlanFeatures); matriz P0 actualizada; día «Sabor Urbano» corregido; roadmap §L.
- **2026-06-12:** **I1 refactor PedidosService (cierre)** — `PedidosItemsService` (`agregarItems`, `eliminarItemPedido`), `PedidosDescuentoService` (`aplicarDescuento`); `pedidos.service.ts` ~224 LOC fachada (listar, delegación); `npm run build` OK. Ver `docs/AUDITORIA_ARQUITECTONICA_FOODY.md` I1 ✅.
- **2026-06-12:** **Auditoría fases C–E** — Fase C: UI eliminar ítem en `MesaPedidosSheet`, Realtime sheet mesa, máquina estados `pagando`→`pagado` (`pedido-estados.ts`), admin **Turno mesas** (`POST /mesas/asignar-turno`). Fase D: `PlanFeaturesGuard` + `@RequiereModulo`, `plan`/`modulos` en login/perfil/JWT, sidebar filtra por plan; Realtime `caja_movimiento` + `alerta_nueva`. Fase E: `endpoints_api_foody.md`, `ANALISIS_SISTEMA.md` histórico, migración `045_demo_plan_pro.sql`. Ver `docs/AUDITORIA_ARQUITECTONICA_FOODY.md`.
- **2026-06-12:** **Auditoría RT-2 + C5 + I3** — Realtime: `pedido_asignado` (planta), `oferta_nueva` (independiente); Flutter dashboards suscritos + poll 60s. Promociones: migración `044` (`codigo`, `descuento_*`, `pedidos.promocion_id`); `GET /promociones/validar-codigo`; checkout con código. Mesas: `SucursalScopeService` en controller.
- **2026-06-12:** **Fix auditoría arquitectónica (Fase A + C4 + RT-1)** — C1: `cobrarCuentaMesa` → `movimientos_caja` + auditoría + exige caja abierta; C2: no venta caja en `pendiente_aprobacion` / mesa diferida + reversa al rechazar; M5: selector método pago en `MesaPedidosSheet`; C4: `DELETE /pedidos/:id/items/:itemId` + alerta `item_eliminado_post_cocina`; RT-1: `cocina_actualizada` + KDS suscrito (poll 60s backup). Ver `docs/AUDITORIA_ARQUITECTONICA_FOODY.md`.
- **2026-06-12:** **Firebase / identificador app** — `applicationId` y bundle iOS/macOS → `app.foody.cliente` (reemplaza `com.tucanchafacil.app` / `com.example.app`). Eliminado `google-services.json` legacy; `lib/firebase_options.dart` listo para `flutterfire configure` (proyecto `foody-pin2`).
- **2026-06-12:** **RT-7 Realtime** — Backend: `qr_aprobacion_urgente` al crear pedido QR; `catalogo_disponibilidad` al agotar/reactivar producto (venta, cancelación, admin). Flutter: listeners en `FoodyRealtime`, SnackBar/banner QR en mesas, refresh menú cliente y POS cajero.
- **2026-06-12:** **QA operación mesas API** — `scripts/verificar-operacion-mesas.ps1` (cajero sin turno + mesero con turno). Migración `042` `crear_pedido` para mesero aplicada en BD demo.
- **2026-06-12:** **Cajero sin turno de mesas** — Solo `mesero` asigna `mesera_asignada_id` al crear pedido mesa (`pedidos-crear.service.ts` + `rol` en JWT). Flutter: `MesasGridWidget.modoCajero` en panel cajero (pedir/cobrar sin bloqueo de mesera); mesero sigue con `modoMesero` + turno. Migración `049` limpia asignaciones erróneas al cajero.
- **2026-06-12:** **Estrategia Realtime distribuido** — `docs/ESTRATEGIA_REALTIME_FOODY.md`: inventario actual (3 eventos broadcast); RT obligatorio/recomendado/opcional por mesas/pedidos/cocina/QR/domi/caja/inventario; 10 riesgos concurrencia + 7 duplicación; canales objetivo; fases RT-1…RT-6; hueco crítico: `CocinasService` no emite RT.
- **2026-06-12:** **130 escenarios negocio restaurante** — `docs/ESCENARIOS_NEGOCIO_FOODY.md`: mesas/pedidos/cocina/caja/QR/domi/inventario; por escenario: debería/módulos/validaciones/errores/controles faltantes; 65✅ 39🟡 26❌; día simulado «Sabor Urbano».
- **2026-06-12:** **Auditoría mesas/pedidos/caja/roles** — `docs/FLUJO_MESAS_PEDIDOS_CAJA.md`: flujo spec vs código, 10 simulaciones reales, matriz conexiones (stock/costeo/caja), Realtime obligatorio (KDS/domiciliario faltan), checklist QA y roadmap brechas (caja cobro mesa, DELETE ítem, RT cocina).
- **2026-06-12:** **Cuenta acumulada por mesa** — Backend: `POST /pedidos/:id/items` (sumar ítems/combos a pedido abierto, recalcula total + stock); `POST /pedidos/mesa/:mesaId/cobrar` (todos los pedidos activos → `pagado`, libera mesa). Flutter: `MesaPedidosSheet` botones Agregar/Cobrar cuenta; mesero agrega consumo al pedido mesa o crea pedido llevar/domi vinculado a la misma mesa; `total_acumulado` en detalle mesa.
- **2026-06-11:** **Mapas OpenStreetMap (sin costo Google)** — Flutter: `lib/core/mapas/` (`MapaFoody`, `GeografiaRepository`, navegación Waze/Maps). Reemplazo Google en checkout, seguimiento, `MapaSeleccionUbicacion`. Backend: módulo `geografia` (`GET /geografia/buscar` → Photon + caché); zonas: `GET /zonas/sucursal/:id/configuracion-mapa`, `PATCH .../ubicacion`; pedidos domiciliario incluyen `lat`/`lng`. Admin `ZonasAdminScreen`: mapa con anillos de radio (km) y precio por zona.
- **2026-06-09:** **Rediseño UI operación** — `operacion_ui.dart` (tokens compartidos). **Pedidos:** vista grid por defecto + stats + búsqueda/filtros + toggle columnas. **Nuevo pedido:** layout POS menú+carrito, categorías, qty inline, tipo/mesa/pago sin diálogo. **Mesas:** tarjetas blancas + resumen libres/ocupadas/QR. **Caja:** métricas + movimientos + panel lateral gasto/cierre.
- **2026-06-09:** **Usuarios por sucursal (dueño corporativo)** — `UsuariosAdminScreen`: dropdown «Ver usuarios de la sede» + campo **Sucursal** en «Nuevo usuario»; aviso si solo hay una sede. Backend `usuarios.controller`: `SucursalScopeService` en listar/crear/cambiar estado (corporativo puede asignar otra sede del mismo restaurante).
- **2026-06-09:** **Multi-sucursal Fase 1 (código)** — `SucursalScopeService`; permiso `ver_inventario_otras_sucursales` (migr. `043`); scope en inventario/pedidos/caja/dashboard; `GET /inventario/hermanas/resumen`; Flutter `InventarioHermanasPanel` + selector sucursal solo corporativo (`gestionar_sucursales`).
- **2026-06-09:** **Multi-sucursal — spec y reglas** — `docs/MULTI_SUCURSAL.md` (modelo Alitas House: cada sede aislada; inventario cruzado solo lectura). Actualizado `reglas_negocio_foody.md`, `MEMORIA.md` (roles), `.cursor/rules/foody-multi-sucursal.mdc`, `foody-backend.mdc`, `AGENTS.md`. Brechas: dropdown sucursal sin restricción, API sin `SucursalScopeGuard`.
- **2026-06-09:** **Alerta `intento_pedido_sin_stock`** — Al fallar `validarStockDisponible` se inserta alerta (transacción aparte) con mensaje contextual: producto pedido, insumo faltante, ítems incluidos (ej. queso en 2× Rosquete del hígado). UI `AlertasAdminScreen` resalta tarjeta roja.
- **2026-06-09:** **UX stock admin + errores detallados** — Backend: `STOCK_INSUFICIENTE` con `detalles[]`; `GET /costeo/productos/:id/impacto-stock`; `PedidosInventarioService.detectarFaltasStock`. Flutter: `stock_visual_widgets.dart` (badges, barras, banner, tarjeta impacto); `InventarioAdminScreen` alertas visuales; `CostosMargenesScreen` tarjeta «puede vender / faltas»; `RecetaProductoPanel` «Venta descuenta X»; `ProductoItemsIncluidosPanel` aviso incluidos descuentan stock; checkout muestra insumo faltante (ej. queso en hígado→rosquetes).
- **2026-06-09:** **S6 QR ciudad/sucursal automática** — `GET /menu/mesa/:qr` devuelve `ciudad` + `restaurante` en `sucursal`; Flutter `MesaSesionService` guarda contexto, splash redirige al menú, `GoRouter` bloquea cambio de ciudad/sucursal; banner mesa con «Salir».
- **2026-06-09:** **Operación mesero S1+S3+S4+S5 (parcial)** — Backend: `PedidosInventarioService` valida al crear, descuenta al confirmar/aprobar, restaura stock cancel/rechazo; `aprobarMesa` asigna mesera y bloquea conflicto (`MESA_ASIGNADA_OTRA_MESERA`); migración `041`. Flutter: `PanelMeseroScreen` con `modoMesero` en grid (tap mesa libre → pedido staff) y kanban 5 columnas; `PedidoCajeroScreen.modoMesero`. Pendiente: aplicar `041`, S6 QR ciudad/sucursal auto, banner QR pendientes.
- **2026-06-09:** **Fix pedido cliente 400** — Backend: precio de venta siempre del servidor (`pedidos.service.ts`, ya no `PRECIO_INVALIDO`); filtro HTTP con mensajes de negocio. Flutter: `checkout_screen` usa `mensajeErrorHttp`, re-cotiza domicilio antes de confirmar; `pedidos_cliente_repository` omite campos `null`.
- **2026-06-09:** **A-MES-3 pedidos activos por mesa** — `GET /pedidos/mesa/:mesaId` (ítems + `estado_cocina` + total acumulado). Flutter: `MesaPedidosSheet` (expansible por pedido, colores cocina, marcar pagando, transferir).
- **2026-06-09:** **Mapa flujos — lote pendientes cliente/staff** — P02: `PromocionesCiudadStoriesBar` + `RestaurantesScreenFoody` (stories, búsqueda, cards). P06B: preview mapa checkout. P07: mapa destino + `tipo/lat/lng` en estado público. A-CAJ-3 descuento en `PedidoCajeroScreen`; A-CAJ-5 alerta arqueo >$5k. D-PL-2 tabs domiciliario planta; D-REG `/domiciliario/registro`. A-MES-2 timer QR 3/5 min. KDS sonido + alerta >20 min. Backend: `GET /promociones/ciudad/:slug/stories`, domiciliario historial/stats, `pedido_creado_at` en mesas.
- **2026-06-09:** **Flujos por rol (HTML → código)** — Mapa `docs/MAPA_FLUJOS_PANTALLAS.md`. Backend: `cajero`/`mesero` en `resolverDashboard`. Flutter: `/admin/cajero` (`PanelCajeroScreen`: apertura caja obligatoria + POS + tab caja), `/admin/mesero` (`PanelMeseroScreen`: mesas + kanban), `redireccion_staff.dart` unifica splash/login. Panel admin acepta `?seccion=` en ruta. — `docs/PLANES_SUSCRIPCION.md`: hoy `basico`/`pro`/`enterprise` solo se guardan en `suscripciones_restaurante` y se editan en Foody Control; **no restringen módulos**. Lo operativo es `estado` (`prueba`/`activa`/`vencida`/`bloqueada`) vía `SuscripcionActivaGuard`. Pendiente: matriz plan→features, guard por plan, vencimiento automático por `fecha_vencimiento`, UI upgrade en panel restaurante.
- **2026-06-09:** **Foody Control (superadmin) — UI y control operativo** — Rediseño `panel_foody_control_screen.dart` + `foody_control_ui.dart`: rail/drawer responsivo, KPIs, búsqueda, pull-to-refresh. Secciones: Resumen, Restaurantes, Planes, Usuarios, Ciudades, Config, Repartidores. Backend: `GET /super/restaurantes/:id/sucursales`, `fecha_vencimiento` en PATCH suscripción. Fix falso error al crear restaurante (timeout 90s, recuperación por nombre).
- **2026-06-09:** **Fix costos obsoletos en incluidos** — Backend recalcula siempre el producto incluido antes de sumarlo (`obtenerCostoUnitarioIncluido`, `listarItemsIncluidosProducto`); corrige $9 vs ~600+ en Rosquete×2. UI: pestaña receta aplica margen error 5%; incluidos muestran costo c/u × cantidad; una ecuación prep + incluidos = margen real.
- **2026-06-09:** **Fix desglose costos incluidos + receta** — `ProductoItemsIncluidosPanel`: total = `costo_calculado`, preparación = total − incluidos (ya no usa `costo_domicilio` ni doble cuenta). `RecetaProductoPanel`: pie usa suma de líneas (solo receta), no `costo_calculado` mezclado. Conversión unidades en líneas subreceta. Aviso en diálogo subreceta si `cantidad obtenida = 1` con lote grande.
- **2026-06-08:** **UX Costos e Insumos** — `costeo_ui_bloques.dart`; `CostosMargenesScreen` búsqueda/filtros + flujo «plato cliente → costeo» + margen en bottom sheet; `RecetaProductoPanel` resumen agrupado vs editar; `ProductoItemsIncluidosPanel` incluidos + costo real; `InventarioAdminScreen` guía pasos, chips, tarjetas, FAB.
- **2026-06-08:** **Armonía guía costeo v1.0** — Fix doble merma modo mercado (`costoLineaIngrediente`); `unidad-costeo.util.ts` (g/kg, ml/L); subrecetas anidadas en API + `dialogo_subreceta_form`; validación unidades en recetas; migración `040` umbral 35%; UI food cost semáforo + resumen «Recalcular todo».
- **2026-06-08:** **Fase B costeo KYG — Subrecetas** — `GET /costeo/subrecetas/detalle/:id`, `PATCH /costeo/subrecetas/:id`, `POST .../recalcular`; listado con costo_total y num_items; cascada a productos que referencian la subreceta; Flutter `dialogo_subreceta_form.dart` (cantidad obtenida, margen %, autocomplete insumos, KPI costo/gr, editar).
- **2026-06-08:** **Fase A costeo KYG — Lista de mercado** — Spec `docs/ESPEC_COSTEO_MERCADO_KYG.md`; migración `037` (proveedor, precio_compra, peso bruto/neto, categoria); `insumo-mercado.util.ts` deriva costo real (`precio/neto`); `PATCH /inventario/:id` ampliado + cascada recalcular; Flutter `dialogo_insumo_form.dart` (compra mercado vs solo costo, vista previa), tab «Lista de mercado», editar insumo.
- **2026-06-08:** **S6 precio_para_llevar** — Migración `035` (columna + demo hamburguesa 19500 llevar); DTOs catálogo; `menu.service` + `pedidos.service.precioVentaProducto()`; Flutter: `LineaCarrito.subtotalPara`, admin diálogo dual en `MenuAdminScreen`, KPI llevar en `CostosMargenesScreen`, hint en `MenuScreenFoody`, aviso checkout; `actualizarPreciosCanal` en repo admin.
- **2026-06-08:** **S5 producto_items_incluidos** — Migración `034` (tabla + demo Rosquete/Huevo frito); `CosteoService` suma costos incluidos y expande stock; `GET/PUT /productos/:id/items-incluidos`; tab **Incluye** en `CostosMargenesScreen` + `ProductoItemsIncluidosPanel`; KDS muestra líneas incluidas.
- **2026-06-08:** **S1 admin reorganizado (código)** — Sidebar: «Insumos» + «Costos y márgenes» (orden Menú → Insumos → Costos); `CostosMargenesScreen` master-detail responsive + slider `margen_objetivo` + aplicar precio sugerido; `RecetaProductoPanel` reutilizable; enlace «Ver costos» en `MenuAdminScreen`; tab Costos quitado de `InventarioAdminScreen`; backend `PATCH margen_objetivo` + `POST /costeo/productos/:id/recalcular`; repos `actualizarMargenObjetivo` / `recalcularProducto`.
- **2026-06-08:** **Admin menú y costeo (spec)** — `docs/ADMIN_MENU_COSTEO.md`: orden Menú → Insumos → Costos; UI responsive; slider margen; precio local/llevar; **productos con ítems de menú incluidos** (restaurante rosquetes: huevo +1 rosquete, carne/hígado +2); distinto de combos; tabla objetivo `producto_items_incluidos`. Actualizado `MODULO_COSTEO.md` (sin contradecir).
- **2026-06-08:** **Paso 3 Fase 1 cierre costeo** — DTO receta con `tipo_item` (ingrediente/subreceta/empaque); `GET /costeo/subrecetas`; tab **Subrecetas** + editor receta en Flutter; migración `033` (demo carne preparada, empaques domicilio en hamburguesa); scripts 026–033.
- **2026-06-08:** **Paso 3 costeo industrial Fase 1 (parcial)** — Migración `032_costeo_industrial.sql`; módulo NestJS `costeo` (`CosteoService`: merma, subrecetas recursivas, combos, `precio_sugerido`, alertas margen); API `GET /costeo/resumen`, `POST /costeo/recalcular`, `POST /costeo/subrecetas`; inventario delega costos y cascada post-compra; pedidos descuenta stock vía `expandirIngredientesProducto` (empaques en domicilio); Flutter tab Costos enriquecido (`CosteoRepository`, food cost, combos, recalcular); scripts migración 026–032.
- **2026-06-08:** **Paso 2 alertas automáticas** — `AlertasRiesgoService` centralizado; disparadores: transferencia mesa (>2), cancelaciones frecuentes, cuadre caja (>$5k), subida costo ingrediente (>15%), demora entrega (>2× estimado); refactor stock/descuento/dispatch; `POST /alertas/evaluar/:sucursal_id` (margen bajo 7d, caída ventas); doc `docs/ALERTAS_AUTOMATICAS.md`; Flutter botón «Evaluar reglas».
- **2026-06-08:** **Paso 1 cierre operativo pedidos** — Backend: costo combo = suma productos del combo (`pedidos.service.ts`); `POST /pedidos/staff` (mesa staff → `confirmado`, requiere `mesa_id`); estado Kanban `pagando` (listo→pagando→entregado en mesa/para llevar). Flutter: selector mesa en `PedidoCajeroScreen` vía staff API; columna Pagando en Kanban; `DomiciliariosAdminScreen` + menú sidebar. Migración `031_paso1_demo_recetas.sql` (recetas hamburguesa/papas para descuento stock).
- **2026-06-08:** **Paso 0 verificación base** — Docker/Supabase + backend `:3000`; script `scripts/verificar-paso0.ps1` (logins demo, rutas admin/cocina/domiciliario/super/cliente, migraciones 027–030); doc `docs/PASO0_VERIFICACION.md`. Resultado: **25 OK, 0 FALLO** (API). UI Flutter por rol pendiente checklist manual.
- **2026-06-07:** Documentación **módulo costeo industrial** — `docs/MODULO_COSTEO.md`: análisis Excel KYG (~187 insumos, 40 subrecetas, 20 platos), decisiones (multi-tenant, combos suma ítems, empaques domicilio, subrecetas teórico/lote opcional, alertas margen), fórmulas backend, migración `031` borrador, API/UI planificada, fases 1–3 y checklist de implementación.
- **2026-06-05:** Fix **Zonas de domicilio** admin — `NumberFormat` con `parsearNumero` (PostgreSQL `numeric` → String). **Horarios** — `GET /sucursales/:id/horarios`, `PATCH /sucursales/horarios/:id`, `HorariosAdminScreen` en panel. Migración `030_fix_demo_operacion.sql` (repartidor demo `activo`, dedupe `horarios_sucursal`).
- **2026-06-05:** Entorno local Windows+WSL — migraciones `026`–`029` en `supabase-db`; fix `028` (`movimientos_ingrediente`); backend recompilado con `ws` para Realtime; scripts `generar-env-backend.sh`, `puesta-a-punto-completa.bat`.
- **2026-06-04:** **Bloque 2 (dinero)** — IVA al crear pedido (`iva_porcentaje`/`iva_valor` desde config fiscal); módulo `zonas` (`GET /zonas/cotizar-domicilio`, CRUD `/zonas`); `POST /pedidos/:id/descuento` (≤20% staff, >20% admin/gerente, >30% alerta); reglas cancelación (motivo obligatorio, >2 min o en cocina solo admin/gerente). Flutter: `ZonasAdminScreen`, cotización en checkout, descuento en Kanban. Migración `027_bloque2_dinero.sql`.
- **2026-06-04:** Auditoría integral del sistema → `docs/ANALISIS_SISTEMA.md` (brechas spec vs implementado, casos de restaurante, roadmap por bloques 1-5).
- **2026-06-04:** **Bloque 1 (cocina)** — módulo NestJS `cocinas`: CRUD `/cocinas` y `/impresoras` (permiso `editar_productos`); KDS `/cocina/cocinas`, `/cocina/tickets/:id`, `PATCH /cocina/items/:id/estado` (permiso `ver_cocina`, recalcula estado del pedido). `auth.service` da `ver_cocina` y dashboard `cocina` a roles `cocina_*`. Flutter: `CocinasRepository`, `CocinasAdminScreen`, `KdsScreen` (`/admin/cocina` + sección panel), selector de cocina al crear/editar producto. Migración `026_cocinas_kds.sql` (permiso + impresora demo + `cocina@foody.demo`/123456).
- **2026-06-04:** Login demo — migraciones `022`+`025` en BD (super@foody.demo, repartidor@foody.demo); mensajes HTTP en staff login; id super sin conflicto con domi@foody.demo.
- **2026-06-04:** Fix 403 aprobar QR — permisos `aprobar_pedido_mesa` en BD (migración `024`); JWT recarga permisos desde BD en cada request; Flutter sincroniza `/auth/perfil` al abrir panel.
- **2026-06-04:** Fix build backend — import `DatabaseService` en `domiciliario-independiente.guard`; `QueryResultRow` en facturación; sin build el API queda sin POST/QR mesas (404). Banner en grid mesas + mensaje 404 con ruta.
- **2026-06-04:** Transferir mesa — `POST /mesas/transferir` (auditoría `transferencias_mesa`, alerta >2); Flutter tap mesa ocupada → elegir destino; `MesasRepository.transferir`.
- **2026-06-04:** Super Admin CRUD — `POST/PATCH /super/ciudades`, `PATCH /super/restaurantes/:id`; panel FAB ciudad + toggle activa; bloquear restaurante.
- **2026-06-04:** Seguimiento cliente — hora en timeline (`estados_pedido_historial.fecha`).
- **2026-06-04:** Legacy — `lib/legacy/README.md` (reglas limpieza; `features/` no importa `screens/`).
- **2026-06-04:** Mesas CRUD — `POST/PATCH/DELETE /mesas`, `GET /mesas/:id/qr`; Flutter FAB crear mesa, long-press QR/renombrar/desactivar; `MesasRepository`.
- **2026-06-04:** Super Admin — `/super/ciudades`, `suscripciones`, `domiciliarios`, `configuracion`; panel tabs; seed `super@foody.demo`; migración `023`.
- **2026-06-04:** Sprint 7 dispatch independientes — `DispatchService` (radio 3–9 km, ofertas 60s, alerta tras 3 intentos); `POST /auth/login-domiciliario`; endpoints `/domiciliarios/sesion/*`, `ofertas`, `pedidos`; auto-dispatch al pasar pedido domicilio a `listo` si no hay planta libre; Kanban «Buscar independiente»; Flutter login + dashboard repartidor; migración `022`.
- **2026-06-04:** Sprint 9 facturación — módulo NestJS `facturacion` (config, listar, emitir, HTML PDF); borrador en `POST /pedidos` si `requiere_factura`; migración `021`; Flutter checkout toggle + `FacturacionAdminScreen`; permisos `ver_facturacion` / `gestionar_facturacion`.
- **2026-06-03:** Sprint 9 usuarios — `GET/POST /usuarios`, `PATCH /usuarios/:id/estado`, `UsuariosAdminScreen` (gerente/cajero/mesero/domiciliario).
- **2026-06-03:** Fix 404 admin — verificación API desactualizada, mensajes HTTP amigables, carga parcial menú/caja.
- **2026-06-03:** Sprint 5–6 cierre — fiados caja, toppings/bebidas CRUD + vínculos, conteo físico inventario.
- **2026-06-03:** Sprint 5–6 UI — `PedidoCajeroScreen`, editar precio menú admin, editor receta en inventario; script backend recompila siempre.
- **2026-06-03:** Sprint 5–6 — módulos NestJS `caja`, `catalogo`, `inventario`; Flutter `CajaAdminScreen`, `MenuAdminScreen`, `InventarioAdminScreen`; panel admin wired; fix parseo movimientos caja y `cerrar` caja por `caja_id`.
- **2026-06-03:** Sección **Referencias persistentes** (reglas, variables, UUIDs demo, tablas BD, estados, endpoints, mapa código).
- **2026-06-03:** Sprint 4 — `GET /menu/mesa/:qr_token`, listado pedidos con `estado_desde`, dashboard con QR/alertas, Kanban con reloj y botones Confirmar/Aprobar, mesas con aprobar/rechazar, ruta `/mesa/:qrToken`, migración `017` permisos admin QR.
- **2026-06-03:** Regla `foody-avance-documentar.mdc` + este documento. Sprint 3: transacción pedidos ampliada, menú/toppings cliente, seguimiento Realtime.
- **2026-06-03 (sesión previa):** Kanban admin, pedidos API staff, flujo cliente MVP, migraciones y fundación NestJS/Flutter.

---

## No repetir (anti-redundancia)

- No crear segundo `main_foody.dart` ni app paralela.
- No reimplementar listas simples de menú/ciudades si `*_screen_foody.dart` ya existe — **extender**.
- No volver a conectar pedidos a Supabase/Firestore desde Flutter.
- No duplicar documentación de estado en `MEMORIA.md` — actualizar **solo** esta tabla/changelog.

---

## Cómo actualizar este archivo (checklist agente)

1. Cambiar **Última actualización** y, si aplica, **Sprint actual** / **Próximo paso**.
2. Ajustar filas de la tabla del sprint tocado (estado + hecho/falta/por qué/cuándo).
3. Añadir viñeta en **Últimos cambios** (fecha + qué archivos/módulos).
4. Si algo pasó a ✅, quitar tareas duplicadas en “Falta” de otros ítems relacionados.
5. Mantener **No repetir** al día si aparece código legacy nuevo.
6. Si tocaste BD, API o config → actualizar **Referencias persistentes** (UUIDs, endpoints, columnas).

---

# Referencias persistentes (contexto que no se debe olvidar)

## Reglas de oro (no negociables)

| # | Regla |
|---|--------|
| 1 | **Flutter = solo UI.** Cero cálculo de totales, IVA, stock, precios finales. |
| 2 | **Escritura crítica → NestJS**, no Supabase desde cliente (salvo Storage imágenes). |
| 3 | **`sucursal_id` en casi todo query** de datos de restaurante. |
| 4 | **Confirmar pedido = transacción atómica** en PostgreSQL. |
| 5 | **Stock se descuenta al confirmar pedido**, no al entregar. |
| 6 | **`auditoria_logs` solo INSERT** (inmutable). |
| 7 | **Impresoras solo vía Python local**, nunca desde Flutter. |
| 8 | **Cliente sin login** → `device_id` en `dispositivos_cliente`. |
| 9 | **Precios en `pedido_items` se copian** al crear (no referencia viva al producto). |
| 10 | **Un repo, un `main.dart`** — evolución in-place; no “Foody v2”. |
| 11 | **Multi-sucursal:** operación aislada por `sucursal_id`; no mezclar menú/stock/caja/pedidos entre sedes. Ver inventario otra sede = **solo lectura** (`docs/MULTI_SUCURSAL.md`). |

**Respuesta API (siempre):** `{ exito, datos?, mensaje? }` o `{ exito: false, error, mensaje }`.

**Guards (orden):** JwtAuth → UsuarioActivo → SuscripcionActiva → Rol → SuperAdmin (solo `/super/*`).

---

## Variables y entorno local

| Variable / constante | Valor dev (revisar si cambia IP WSL) | Archivo |
|---------------------|----------------------------------------|---------|
| `Configuracion.urlBackend` | Web: `http://localhost:3000/api/v1` · Móvil: `http://{ipWsl}:3000/api/v1` | `lib/core/constantes/configuracion.dart` |
| `Configuracion.urlSupabase` | Web: `http://localhost:8000` · Móvil: `http://{ipWsl}:8000` | idem |
| `Configuracion.ipWsl` | `192.168.227.118` (actualizar con `hostname -I` en WSL) | idem |
| `timeoutConexion` / `timeoutRespuesta` | 10 s / 30 s | idem |
| Postgres | `foody_db`, puerto `5432` (docker-compose.dev) | `docs/ENTORNO_LOCAL.md` |
| Scripts arranque | `scripts/iniciar-foody-dev.bat`, `iniciar-backend-wsl.bat` | raíz repo |

**Colores UI:** primario `#FF6B35`, secundario `#2EC4B6`, acento `#FFE66D` → `ColoresFoody` / `TemaFoody`.

**Paquete Dart actual:** `reserva_canchas` (legacy; imports siguen ese nombre).

**Entry point:** `lib/main.dart` · Rutas: `lib/core/rutas/app_router.dart`.

---

## Datos demo (UUIDs fijos — usar en pruebas)

| Entidad | ID / token |
|---------|------------|
| Ciudad Valledupar | `a0000000-0000-4000-8000-000000000001` · slug `valledupar` |
| Restaurante demo | `b0000000-0000-4000-8000-000000000001` |
| **Sucursal Centro** | `c0000000-0000-4000-8000-000000000001` |
| Cocina principal | `d0000000-0000-4000-8000-000000000001` |
| Producto hamburguesa | `f0000000-0000-4000-8000-000000000001` |
| Mesa 1 QR | `30000000-0000-4000-8000-000000000001` · token **`demo-mesa-1`** |
| Admin staff | `admin@foody.demo` / pass **`123456`** · user id `90000000-0000-4000-8000-000000000001` |
| Super admin | `super@foody.demo` / **`123456`** · migración `023` |
| Domiciliario planta demo | `domi@foody.demo` / **`123456`** · migración `019_domiciliario_demo.sql` |
| Domiciliario independiente demo | `repartidor@foody.demo` / **`123456`** · migración `022` |

Seed principal: `foody_supabase/migrations/012_seed_demo.sql` (+ `014`–`017` admin/pedidos).

---

## Jerarquía de datos (columna vertebral)

```
ciudades → restaurantes → sucursales (TODO cuelga de sucursal_id)
  ├── categorias → productos (+ receta_id opcional) → toppings/bebidas/combos
  ├── cocinas → impresoras
  ├── mesas (qr_token único)
  ├── pedidos → pedido_items → toppings/bebidas en línea
  ├── ingredientes → recetas → receta_items → movimientos_ingrediente
  ├── cajas → movimientos_caja
  └── usuarios (staff, JWT) — clientes NO en usuarios, solo dispositivos_cliente
```

---

## Estados del pedido (orden operativo)

| Estado | Cuándo |
|--------|--------|
| `pendiente_aprobacion` | Pedido **mesa** por QR; mesera debe aprobar |
| `pendiente` | Cliente para llevar/domicilio; restaurante debe **Confirmar** |
| `confirmado` | Aceptado; espera cocina |
| `en_cocina` | Preparación |
| `listo` | Listo para entregar/recoger |
| `en_camino` | Solo domicilio |
| `entregado` / `pagado` | Cierre / pago |
| `cancelado` / `rechazado` | Con motivo en historial |

**Historial:** tabla `estados_pedido_historial` (`estado_anterior`, `estado_nuevo`, `fecha`, `usuario_id`, `motivo`).  
**Reloj Kanban:** tiempo desde última fila donde `estado_nuevo = pedidos.estado` (campo API `estado_desde`).

**Constantes negocio (MEMORIA):** domicilio backend `5000` COP · reloj rojo Kanban **15 min** · comisión Foody domicilio **15%** (futuro).

---

## Tablas críticas (columnas que más se usan)

### `pedidos` (migración `005_pedidos.sql`)

| Columna | Notas |
|---------|--------|
| `id`, `sucursal_id` | Obligatorios en todo query staff |
| `mesa_id`, `device_id` | Mesa QR vs cliente anónimo |
| `stock_descontado`, `mesera_id`, `aprobado_at` | Migración `041`: inventario y mesera al aprobar |
| `numero_pedido`, `tipo` | `mesa` \| `para_llevar` \| `domicilio` \| `encargo` |
| `estado` | Ver tabla estados arriba |
| `subtotal`, `costo_domicilio`, `descuento`, `total` | Calculados en **backend** |
| `metodo_pago` | `efectivo` \| `tarjeta` \| `transferencia` \| `nequi` \| `pendiente` |
| `cliente_nombre`, `cliente_telefono`, `direccion_entrega`, `lat`, `lng` | |

### `pedido_items`

| Columna | Notas |
|---------|--------|
| `pedido_id`, `producto_id`, `cocina_id` | `cocina_id` copiado del producto al crear |
| `cantidad`, `precio_unitario`, `costo_unitario` | Precio/costo **congelados** en el pedido |
| `estado_cocina` | `pendiente` \| `preparando` \| `listo` (cocina app futura) |

### `productos` + menú

| Columna | Notas |
|---------|--------|
| `sucursal_id`, `categoria_id`, `cocina_id`, `precio`, `disponible` | Cliente solo ve `disponible=true` |
| `receta_id` | Si null → **no** descuenta inventario al pedir |
| Relaciones | `producto_toppings`, `producto_bebidas` |

### Inventario y costeo (migración `006_inventario.sql` + plan `031`)

| Tabla | Uso |
|-------|-----|
| `ingredientes` | `stock_actual`, `stock_minimo`, `costo_unitario_actual`, `tipo_costeo`, `rendimiento_porcentaje`, `sucursal_id` |
| `recetas` / `receta_items` | `tipo_item`: ingrediente \| subreceta \| empaque · ver extensión en `docs/MODULO_COSTEO.md` |
| `combos` / `combo_items` | `precio_fijo`; **plan:** `costo_calculado` = suma ítems |
| `movimientos_ingrediente` | `tipo`: compra \| venta \| ajuste \| merma \| … · `pedido_id` opcional |
| `margenes_venta` | Foto margen por línea al crear pedido |
| **Spec costeo** | `docs/MODULO_COSTEO.md` · Excel: `INFRAESTRUCTURA/TABLA DE COSTEOS KYG.xlsx` |

### Caja (migración `007_caja.sql`) — Sprint 5

| Tabla | Uso |
|-------|-----|
| `cajas` | `estado` abierta \| cerrada · una abierta por sucursal a la vez |
| `movimientos_caja` | `tipo`: venta \| retiro \| gasto \| ingreso_extra \| apertura |
| Al confirmar pedido con pago ≠ `pendiente` | INSERT venta si hay caja abierta (ya en `PedidosCajaAuditoriaService`) |

### Auth / staff

| Tabla | Notas |
|---------|--------|
| `usuarios` | `email`, `rol`, `sucursal_id`, `restaurante_id`, `activo`, `hash_contrasena` |
| `roles_permisos` | Lista permisos por rol; JWT lleva `permisos[]` |
| `dispositivos_cliente` | PK `device_id`; clientes públicos |
| `suscripciones_restaurante` | `estado` (`prueba`/`activa`/`vencida`/`bloqueada`) → guard `SuscripcionActivaGuard`. `plan` (`basico`/`pro`/`enterprise`) → **solo metadata** (no limita features). Ver `docs/PLANES_SUSCRIPCION.md`. |

### Otras

| Tabla | Notas |
|-------|--------|
| `mesas` | `qr_token` UNIQUE · pedido activo por LATERAL en API mesas |
| `auditoria_logs` | Solo INSERT · acción ej. `CREAR_PEDIDO` |
| `alertas_riesgo` | Dashboard cuenta `revisada=false` |
| `estados_pedido_historial` | Realtime + seguimiento cliente |

**Esquema completo:** `INFRAESTRUCTURA/esquema_maestro_bd_v3.md` · Migraciones: `foody_supabase/migrations/001`…`017`.

---

## Endpoints — implementados vs pendientes

### Públicos (sin JWT)

| Método | Ruta | Estado |
|--------|------|--------|
| POST | `/dispositivos/registrar` | ✅ |
| GET | `/menu/:sucursal_id` | ✅ |
| GET | `/menu/mesa/:qr_token` | ✅ |
| POST | `/pedidos` | ✅ transacción parcial |
| GET | `/pedidos/:id/estado` | ✅ |
| GET | `/zonas/cotizar-domicilio` | ✅ |
| GET | `/geografia/buscar?q=` | ✅ Photon OSM |

### Staff (Bearer JWT)

| Método | Ruta | Permiso típico | Estado |
|--------|------|----------------|--------|
| POST | `/auth/login` | — | ✅ |
| GET | `/dashboard/resumen` | `ver_dashboard` | ✅ |
| GET | `/pedidos` | `ver_pedidos` | ✅ |
| PATCH | `/pedidos/:id/estado` | `ver_pedidos` | ✅ |
| PATCH | `/pedidos/:id/aprobar` | `aprobar_pedido_mesa` | ✅ |
| PATCH | `/pedidos/:id/rechazar` | `aprobar_pedido_mesa` | ✅ |
| POST | `/pedidos/:id/descuento` | `aplicar_descuento` | ✅ |
| CRUD | `/zonas` | `gestionar_sucursales` | ✅ |
| GET | `/zonas/sucursal/:id/configuracion-mapa` | `gestionar_sucursales` | ✅ |
| PATCH | `/zonas/sucursal/:id/ubicacion` | `gestionar_sucursales` | ✅ |
| GET | `/mesas/:sucursal_id` | `gestionar_mesas` | ✅ |
| POST | `/mesas` | `gestionar_mesas` | ✅ |
| PATCH | `/mesas/:id` | `gestionar_mesas` | ✅ |
| DELETE | `/mesas/:id` | `gestionar_mesas` | ✅ desactivar |
| GET | `/mesas/:id/qr` | `gestionar_mesas` | ✅ HTML + URL |
| POST | `/mesas/transferir` | `gestionar_mesas` | ✅ |
| GET | `/super/ciudades`, `/super/suscripciones`, `/super/domiciliarios`, `/super/configuracion` | super_admin | ✅ |
| POST | `/super/restaurantes` | super_admin | ✅ onboarding |
| GET | `/super/estadisticas` | super_admin | ✅ |
| GET/POST/PATCH | `/super/usuarios`, cambiar-contrasena, estado | super_admin | ✅ UI Foody Control |
| GET | `/super/restaurantes/:restauranteId/sucursales` | super_admin | ✅ selector usuario |
| PATCH | `/super/configuracion/:clave` | super_admin | ✅ |
| POST | `/super/domiciliarios/:id/aprobar-documento`, rechazar | super_admin | ✅ |
| GET/POST | `/sucursales/mi-restaurante`, `/sucursales` | `gestionar_sucursales` | ✅ |
| GET | `/sucursales/:sucursalId/horarios` | `gestionar_sucursales` | ✅ |
| PATCH | `/sucursales/horarios/:horarioId` | `gestionar_sucursales` | ✅ |
| POST | `/super/ciudades` | super_admin | ✅ |
| PATCH | `/super/ciudades/:id`, `/super/restaurantes/:id` | super_admin | ✅ |
| PATCH | `/super/suscripciones/:id` (plan, estado, `fecha_vencimiento`), `/super/domiciliarios/:id/estado` | super_admin | ✅ |
| GET | `/ciudades`, `/restaurantes/...` | público/staff | ✅ |
| POST/GET | `/caja/abrir`, `/caja/cerrar`, `/caja/activa/:id`, movimientos, gastos, retiro | `ver_caja` / `abrir_caja` | 🟡 |
| CRUD | `/categorias`, `/productos` (staff) | `editar_productos` | 🟡 |
| GET/POST/PATCH | `/inventario/...`, compras, receta producto, costos | `ver_inventario` / `editar_inventario` | 🟡 |
| GET | `/domiciliarios-planta/disponibles/:sucursal_id` | `gestionar_domiciliarios` | ✅ |
| POST | `/domiciliarios-planta/asignar` | `gestionar_domiciliarios` | ✅ |
| GET | `/domiciliario/pedidos-asignados` | `ver_pedidos` (planta) | ✅ |
| PATCH | `/domiciliario/pedidos/:id/en-camino`, `.../confirmar-entrega` | `ver_pedidos` (planta) | ✅ |
| POST | `/auth/login-domiciliario` | — | ✅ |
| POST | `/domiciliarios-planta/dispatch-independiente/:pedido_id` | `gestionar_domiciliarios` | ✅ |
| POST/GET/PATCH | `/domiciliarios/sesion/*`, `/ofertas-activas`, `/ofertas/:id/responder`, `/pedidos-activos`, `/pedidos/:id/*` | `domiciliario_independiente` | ✅ |
| GET | `/reportes/financiero`, `/productos`, `/pedidos` | `ver_reportes` | ✅ |
| GET | `/alertas/:sucursal_id` | `ver_alertas` | ✅ |
| POST | `/alertas/evaluar/:sucursal_id` | `ver_alertas` | ✅ |
| PATCH | `/alertas/:id/revisar` | `ver_alertas` | ✅ |
| GET/POST | `/usuarios` | `gestionar_usuarios` | ✅ |
| PATCH | `/usuarios/:id/estado` | `gestionar_usuarios` | ✅ |
| GET | `/facturacion/config/:sucursal_id` | `ver_facturacion` | ✅ |
| POST | `/facturacion/config` | `gestionar_facturacion` | ✅ |
| GET | `/facturacion/facturas/:sucursal_id` | `ver_facturacion` | ✅ |
| POST | `/facturacion/emitir/:pedido_id` | `gestionar_facturacion` | ✅ |
| GET | `/facturacion/facturas/:id/pdf` | `ver_facturacion` | ✅ HTML preview |

### Pendientes (guía — no reimplementar si ya existe arriba)

| Área | Rutas objetivo | Sprint | Nota |
|------|----------------|--------|------|
| Super | PATCH config global | 8 | Editar `configuracion_global_foody` |
| ~~FCM push~~ | — | 7 | **Pospuesto** |
| ~~Facturación DIAN~~ | proveedor FE | 9–11 | **Pospuesto** |
| ~~Impresión Python~~ | WebSocket | 10 | **Pospuesto** |

**Lista maestra:** `INFRAESTRUCTURA/endpoints_api_foody.md`.

---

## Código — mapa rápido (dónde tocar qué)

| Capa | Ruta |
|------|------|
| Flutter features nuevas | `lib/features/<dominio>/` |
| Flutter legacy (no extender) | `lib/screens/`, `lib/providers/`, `pedido_service.dart` |
| Core Flutter | `lib/core/` (red, tema, rutas, sesión, dispositivo) |
| Backend módulo | `foody_backend/src/modulos/<nombre>/` (`facturacion/` Sprint 9) |
| Backend core | `foody_backend/src/core/auth`, `database` |
| SQL | `foody_supabase/migrations/` |
| Reglas Cursor | `.cursor/rules/foody-*.mdc` |

**Realtime Supabase (broadcast):** backend emite tras commit — canal `sucursal_{uuid}` eventos `pedido_actualizado` / `mesas_actualizadas`; canal `pedido_{uuid}` evento `estado_actualizado`. Cliente: `lib/core/realtime/foody_realtime.dart`. Requiere `SUPABASE_SERVICE_KEY` en backend y migración `028` (RLS bloquea `postgres_changes` anon). **Estrategia completa:** `docs/ESTRATEGIA_REALTIME_FOODY.md`.

---

## Errores API frecuentes (backend → Flutter muestra `mensaje`)

| Código | Significado |
|--------|-------------|
| `STOCK_INSUFICIENTE` | Receta/incluidos sin stock; respuesta incluye `detalles[]` (`nombre`, `necesita`, `disponible`, `unidad`) |
| `MESA_ASIGNADA_OTRA_MESERA` | Otra mesera ya atiende esa mesa |
| `PRODUCTO_NO_DISPONIBLE` | `disponible=false` |
| ~~`PRECIO_INVALIDO`~~ | Obsoleto: el backend usa precio de BD (canal mesa/llevar) |
| `RESTAURANTE_CERRADO` | Fuera de `horarios_sucursal` |
| `MESA_NO_ENCONTRADA` | `qr_token` inválido |
| `CAJA_NO_ABIERTA` | Futuro: operación caja sin turno |

---

## Decisiones ya tomadas (no reabrir sin motivo)

| Tema | Decisión |
|------|----------|
| BD | PostgreSQL Supabase self-hosted, no Firebase para negocio |
| Realtime | Supabase **broadcast** vía backend (service key); no `postgres_changes` anon |
| Cliente | Sin login; `device_id` |
| IVA | Incluido en precio menú |
| Impresión | Python local + WebSocket (futuro) |
| Base UI | Reutilizar pantallas legacy Cancha Fácil; datos NestJS |
