# Foody — avance del proyecto (documento vivo)

> **Estado consolidado del proyecto:** **`docs/MASTER_STATUS.md`** (fuente oficial única — implementado/pendiente/problemas/módulos).  
> Este archivo conserva detalle por sprint, changelog y **Referencias persistentes** (BD, env, endpoints).

> **Los agentes deben leer este archivo al inicio de cada sesión de implementación y actualizarlo al terminar.**
> Regla Cursor: `.cursor/rules/foody-avance-documentar.mdc`
> Especificación objetivo: `INFRAESTRUCTURA/GUIA_DESARROLLO_FOODY_CURSOR.md` (sprints 1–11).

**Última actualización:** 2026-11-22 — verificadas las escrituras aisladas de Caja, Inventario, Facturación interna y altas de Foody Control. La compilación web de Equipo quedó disponible para revisión local.

**Próximo paso:** cerrar la revisión visual de la oleada y completar los estados, formularios y vistas que faltan según la auditoría frontend. Cloudflare Tunnel sigue siendo el entorno de referencia. Reevaluar VPS/deploy al terminar la app.

### Últimos cambios (changelog)

- **2026-11-22:** Facturación interna conserva la opción de reintentar una emisión rechazada, evita solicitudes repetidas durante la emisión y actualiza la vista después de anular. El comprobante HTML adapta su ancho, expresa el estado correcto y preserva los caracteres de los datos fiscales como texto. En navegador, con cuenta Enterprise y Postgres aislado, se guardó configuración, se rechazó una anulación sin motivo y se confirmó la persistencia al anular y abrir la vista previa. Dos pruebas de widgets pasaron.
- **2026-11-22:** Caja e Inventario verificados contra NestJS y PostgreSQL aislados con datos sintéticos. Pasaron los dos escenarios E2E de Caja, el cobro de un fiado y el registro del conteo. Foody Control permite validar el alta de usuarios con contraseña inicial vacía, errores en los campos y reintento cuando falla la carga de sedes. Se comprobó el formulario en navegador, las altas de restaurante y cajero por API y respuestas 403 en acceso entre dos restaurantes y al intentar crear usuarios de plataforma desde una cuenta de restaurante.
- **2026-11-22:** En la API aislada, el alta de autoservicio asignó Free, permitió Inventario y bloqueó la tercera mesa, Analítica y Facturación. Con un cambio de plan sintético a Pro se habilitó Analítica y Facturación siguió reservada a Enterprise. El Pro vigente sigue a COP 100.000/mes, frente a los COP 50.000/mes definidos como objetivo comercial. La transición de suscripciones y el cobro por Wompi quedan fuera de esta comprobación.
- **2026-11-22:** **UX-CFG-VIEW-01** — `ConfiguracionAdminScreen` reorganizada en grupos Negocio/Servicio/Equipo, ancho máximo 1120, 1/2/3 columnas según ancho disponible y opciones por permisos. Navegación sigue usando callbacks/rutas existentes. `flutter analyze` focalizado en cuatro archivos: OK; faltan QA visual real en móvil/tablet/escritorio y modo claro/oscuro.
- **2026-11-22:** **QA-CFG-LOGIN-01** — flavor `equipo` sirvió Flutter web en `localhost:8083`; API `/salud` confirmó BD conectada, pero el login demo quedó en spinner tras enviar formulario. Se detuvo el servidor web de prueba; no se validó pantalla autenticada ni se cambiaron datos de negocio.
- **2026-11-22:** **ENV-TUNNEL-KEEP-01 / QA-ENV-REMOTE-01** — el founder reafirma `MODO=tunel` y `usarTunel=true`: aún no hay VPS y Cloudflare Tunnel permite usar Foody fuera de casa. El destino API público del preview local coincide con esa estrategia. Mantener como decisión aceptada hasta terminar la app; al cierre revisar VPS, deploy y configuración final.
- **2026-11-22:** **NAV-CFG-HUB-01 / DS-BASE-01** — agregado `ConfiguracionAdminScreen` como índice de pantallas de ajustes existentes; opciones filtradas por permisos. Se reorganizó el grupo Configuración sin retirar deep links ni añadir API. Guía visual documentada en `FRONTEND_DESIGN_AUDIT.md`; QA visual por rol pendiente.
- **2026-11-22:** **DS-REF-01** — registradas cuatro referencias aportadas por el usuario: dashboard SaaS oscuro, analítica móvil, dashboard tablet claro y tabla de inventario densa. Se especificó qué patrón adaptar por contexto y qué identidad/contenido ajeno no copiar. Rediseño vista por vista pendiente.
- **2026-11-22:** **QA-UI-REDISENO-01** — `flutter analyze` sobre 4 archivos tocados: sin issues. Análisis global: 65 infos + 1 warning previo (`lib/features/auth/data/auth_repository.dart:86`, `dead_null_aware_expression`). `verificar-ci.ps1`: 26 OK / 1 fallo por RLS ausente en `cobros_idempotencia`, `rate_limit_entries`, `usuario_permisos`; API/BD y módulos principales responden. La suite también encuentra `verificar-p2-pulido.ps1` roto al llamar `GetResponseStream` sobre `HttpResponseMessage`; salud local imprime agente de impresión offline y cola con 264 errores, por lo que no se pudo certificar impresión hardware.

- **2026-11-22:** **UX-INV-REDISENO-01** — hero azul oscuro con acento naranja, CTA escritorio y tabs con iconos y resumen derivado de datos existentes; guía redundante retirada. Sin cambios backend/API/modelos ni flujos. `dart analyze` sin incidencias; QA visual/manual pendiente.
- **2026-11-22:** **UX-INV-TRASLADOS-01** — formulario «Nuevo traslado» con shell de formulario compartido; cabecera adaptable, tarjetas de traslado con estado/acción claros y estados vacío/error/sin permiso mejorados. Solo UI; `dart analyze` limpio; QA manual pendiente.
- **2026-11-22:** **UX-INV-TABLA-01** — vista Mercado usa tabla densa en escritorio ancho siguiendo la referencia visual, grid en tablet y cards en compacto; filtros, costos/stock y menú de acciones existentes preservados. `dart analyze --fatal-infos` focalizado limpio; QA visual pendiente.
- **2026-11-22:** **UX-INV-MOV-01** — movimientos reorganizados como registro compacto con transición de stock destacada, metadatos secundarios y acceso preservado al insumo relacionado. Solo UI; análisis focalizado sin errores.
- **2026-11-22:** **DS-FORM-THEME-01** — shell común de formularios dejó de forzar blancos/grises; superficies, textos y bordes se derivan del tema Foody y los campos heredan el input theme global, extendiendo soporte claro/oscuro a 43 usos existentes.
- **2026-11-22:** **UX-SUBRECETA-THEME-01** — diálogo de subreceta ajustado para usar superficies y colores semánticos del tema en opción de stock, alerta de lote, filas de insumos y subtotal; no se altera cálculo ni guardado.
- **2026-11-22:** **UX-MENU-PRODUCTOS-01** — listado de productos presenta tabla compacta desde 1100 px y conserva tarjetas en móvil/tablet; incluye precio local/para llevar, cocina, estado de costeo, disponibilidad y acciones existentes. Menú de acciones compartido; sin cambios en repositorio/API/reglas; falta QA visual.
- **2026-11-22:** **UX-MENU-EXTRAS-01** — Toppings y Bebidas usan tabla compacta en escritorio ancho y conservan tarjetas en móvil/tablet; precio, costeo/margen, switch de disponibilidad y acceso a Costos preservados. `dart analyze` focalizado limpio; QA visual pendiente.
- **2026-11-22:** **UX-MENU-CAT-COMBOS-01** — gestión de Categorías usa diálogo responsive tema-aware; listado de Combos adopta tabla de escritorio y tarjetas compactas/tablet con contenido, precio, disponibilidad y carga de foto preservados. Análisis focalizado limpio; QA visual pendiente.
- **2026-11-22:** **UX-MENU-DIALOGOS-01** — asignar cocina y configurar toppings de plato ahora usan el shell de diálogo responsive Foody; el resumen de costo/precio usa superficies del tema. Análisis focalizado limpio; QA visual pendiente.
- **2026-11-22:** **UX-MENU-COPIAR-01** — diálogo de copiar menú adaptado a Foody con selección de sede agrupada y alcance explícito (incluye categorías/productos/toppings/bebidas; combos no se copian). Solo UI; análisis focalizado limpio.
- **2026-11-22:** **UX-FAC-LISTADO-01** — listado de facturas pasa a tabla en escritorio ancho y conserva tarjetas compactas; columnas estado, cliente, fecha, total y acciones existentes. `dart analyze` focalizado sin incidencias; QA visual pendiente.
- **2026-11-22:** **UX-FAC-FORM-01** — config fiscal, vista previa y anulación usan tema/shell compartido; vista previa tiene jerarquía de comprobante y motivo incluye ayuda visible. DIAN/elegibilidad fiscal no se modifican. `dart analyze` focalizado limpio.
- **2026-11-22:** **UX-CHECKOUT-01** — formulario de checkout limitado a 760 px en escritorio y centrado; tokens de entrada/selección/superficie/botones toman el tema activo y barra final se alinea al contenido. Solo UI; cálculo/envío permanecen backend-first. `dart analyze` limpio.
- **2026-11-22:** **UX-CARRITO-01** — lista, CTA fija y detalle de línea limitados a 760 px en escritorio; superficies, textos, controles y hoja inferior usan el tema activo. Swipe, stepper, extras y subtotal siguen intactos. `dart analyze` limpio.
- **2026-11-22:** Caja ajusta la composición al ancho del panel. Pedidos, Menú, Conteo/Subrecetas y diez vistas administrativas incorporan colores del tema activo. `dart analyze` focalizado: 0 errores y 0 advertencias, con cuatro avisos históricos de Reportes. API con BD conectada, inicio demo y lecturas de sedes y Caja verificadas.
- **2026-11-22:** El panel del restaurante incorpora navegación plegable, transiciones breves, barra superior adaptable, búsqueda inmediata y cargas que respetan el tema y la reducción de movimiento. Inicio carga por defecto después del login. El registro de notificaciones deja de bloquear el acceso y la espera del token al salir tiene límite. Se verificaron ingreso, cierre, Caja y navegación compacta con la compilación local de Equipo. Continúa la revisión de formularios y acciones por módulo.
- **2026-11-22:** El listado de Mesas valida la sede en el controlador. El contrato se comprobó en una instancia aislada de Nest con 400 para el valor inválido y 200 para el válido. No se reinició la API del túnel.
- **2026-11-22:** Los diálogos del panel adoptan el tema y movimiento compartidos. Conteo, fiado y anulación explican los datos inválidos dentro del formulario. Foody Control adapta navegación, carga y tema. Se comprobó en navegador la cancelación de formularios y en la API activa el 400 de Mesas.

- **2026-08-20:** **CAJ-TURNO / ANA-FILT-PROD / ANA-ESTADOS / COC-REIMP** — `horas_abierta` + alerta `caja_turno_longevo` (>12 h, sin auto-cierre) + banner caja; KPI/series con filtro ítem = `SQL_VENTA_LINEA_ITEM`; `estados` sin cancelados salvo `incluir_cancelados`; `POST /impresion/reimprimir` + botón KDS. Check: `verificar-lote-turno-ana-reimp.ps1`.
- **2026-08-19:** **Lote 🟡** — `tipo=mesa` exige `mesa_id`; descuento manual limpia `promocion_id`; DELETE promo SET NULL (mig 089); cancel domicilio libera sesión + cierra ofertas; ajuste stock alerta mínimo + movimientos con `usuario_id`; transfer copia mesera y UI cajero; filter no aplana detalle caja/códigos mesa; CHECK estados pedido. Check: `verificar-lote-amarillo.ps1` · `dart analyze` mesas_grid.
- **2026-08-11:** **VIRAL-FIX-01/03/04/05** — `REGISTRO_RESTAURANTE_ABIERTO` + cupo diario + max/min; `GET /auth/registro-estado`; UI waitlist; horarios/zona post-commit; `BCRYPT_ROUNDS`. Check: `verificar-viral-registro.ps1` OK (503 con ABIERTO=0) · Nest reiniciado · `dart analyze` auth OK.
- **2026-08-11:** **SEC-RLIMIT-03 + INFRA-EXT-UI-03** — `@RateLimitPublico` en `menu`/`ciudades`/`geografia`; SEC-RLIMIT-01 🟡 (`RATE_LIMIT_FORZAR`); KDS `_itemsEnVuelo`/`_conLockItem`; DK-COMPOSE-04 🟡 (archivos en árbol). Check: `verificar-sec-rlimit-kds.ps1` OK (429 con FORZAR=1) · Nest reiniciado · `dart analyze` kds 0 issues.
- **2026-08-11:** **AQ-CYCLE-04 + AQ-DUP-09 + DASH-CONS-COMP** — `PedidosRepository`/`PedidoAdminModel` → `features/pedidos/` (shim admin); `AnaliticaTokens` → `core/tema/` (shim analitica); KPI «Cerrados hoy»; CAP-INFRA nota réplicas en compose. Check: `verificar-aq-cycle-dup.ps1` OK · `dart analyze` paths OK · `GET /salud` OK.
- **2026-08-11:** **PERF-CACHE-02/03 + PERF-SQL-03 + API-VAL-02** — cache ciudades/restaurantes TTL 3 min; dashboard resumen TTL 30 s; top_productos_7d desde `pedidos`→items; ParseUUID en restaurantes/almacenamiento/facturación/categorías/inventario conteos/horarios. Check: `verificar-perf-cache-api-val.ps1` OK · Nest reiniciado.
- **2026-08-11:** **CONC-INV-LOCK-01 + INFRA-EXT-DOWN-01/02 + SEC-BAC sync** — `exigirIngrediente` `FOR UPDATE`; `ApiOfflineBanner` en panel; splash staff con diálogo Reintentar/Login si API caída (no entra a dashboard); SEC-BAC-03/04 reconfirmados ✅. Check: `verificar-conc-inv-infra-down.ps1` OK · Nest reiniciado · `dart analyze` paths 0 issues.
- **2026-08-11:** **CONS-COSTO-SNAPSHOT-01 + CONS-MARGEN-STALE-01** — editar cantidad actualiza `margenes_venta`; analítica invent./rentabilidad declara `fuentes_cogs` / `fuente_cogs` (snapshot vs costo actual). **CFG-GLOBAL-DEAD** reconfirmado ✅ (`verificar-f3-confianza.ps1` OK; docs auditoría sync). Check: `verificar-cons-costo-snapshot.ps1` OK · Nest reiniciado · `dart analyze` analitica (solo infos Share).
- **2026-08-11:** **CONS-CUADRE-SQL-01 + CONS-REP-OPEN-01 + CFG-POLIGONO-03** — script cuadre usa mismos filtros API (venta−devolución + coalesce fecha); API/`reportes` etiquetan Tickets vs Cobrado neto + `nota_universos`; mig `088` COMMENT depreca `zonas_cobertura.poligono`. Check: `verificar-cuadre-caja.ps1` OK (API=BD; diff tickets/caja esperable) · Nest reiniciado · `dart analyze` reportes (solo infos deprecados Share/Table).
- **2026-08-11:** **CFG-NOMBRE-MARCA-07** — `PATCH /sucursales/marca` con `nombre`/`telefono` + UI «Nombre / tel»; CFG-CACHE-MARCA-04 → 🟡 (listado ciudad sin caché Nest). Check: `scripts/verificar-cfg-nombre-marca.ps1` OK · Nest reiniciado · `dart analyze` sucursales 0 issues.
- **2026-08-11:** **CONS-PROMO-ADD-01 + CFG-PATCH-SUCURSAL-01** — add/delete/update ítems reaplica % promo (monto fijo topeado a subtotal); `PATCH /sucursales/:id` + UI «Editar sede». Check: `scripts/verificar-cons-promo-cfg-patch.ps1` OK · Nest reiniciado · `dart analyze` sucursales (warning unused local removido).
- **2026-08-11:** **RT-POLL/FALL + CONS-NODISP** — `PollRealtimeRespaldo` reevalúa RT cada ciclo (90s/30s); poll en menú cliente, POS, panel suscripción y domi planta; N/D cocina pone `productos.disponible=false` + invalida caché/RT catálogo (VIE-09 C merma intacta). Check: `scripts/verificar-rt-fall-poll.ps1` OK · Nest reiniciado · `dart analyze` paths OK (solo infos).
- **2026-08-11:** **Lote 🟣 abiertos** — FUZZ-LEN-01 `@MaxLength(80)` mesa; SEC-BAC-06 `gestionar_finanzas` (mig `087`) en mutaciones `/finanzas/*`; RT-ENV-01 una `SUPABASE_URL`; INFRA-EXT-TO-02 Dio `sendTimeout`; CAP-GROW-01/02 purga cron cola FCM (>14d) + auditoría (>90d); PERF-FL-MEM pulso mesas condicional + caja tope 80 en memoria. Sync MASTER: N1/DISK/LIFE/CAP-FL/DK-SEC/etc. Check: `scripts/verificar-lote-purpura-abiertos.ps1` OK · Nest reiniciado · mig 087 OK.
- **2026-08-11:** **DASH-*** — Inicio: poll 75s + «Actualizado HH:mm · no en vivo»; KPI Ventas→Reportes; KPI QR pendientes; top 7d `ORDER BY cantidad`; copy «Tendencia de la sede»; banner RT aclara Inicio. Check: `verificar-dashboard-general.ps1` OK · Nest `dist` reiniciado · `dart analyze` paths OK.
- **2026-08-11:** **Bloque D** — FL-STATE-01/02: `operacionSucursalProvider` (epoch pedidos + publicar caja); caja invalida al abrir/cerrar; mesas/kanban `ref.listen`. FL-WIDGET-01: `AsignarDomiciliarioSlot` extraído del kanban. AQ-SOLID-08: food cost/margen % desde API en receta/incluidos (sin `precio−costo` en KPIs). UTF-8 kanban reparado. Check: `verificar-bloque-d-flutter.ps1` OK · API `/salud` OK.
- **2026-08-11:** **AQ-SCALE-01 / PERF-POOL-01** — guard prod: `validarConfigProduccion()` ahora exige `DB_POOL_MAX` numérico y >=25 (evita fallback silencioso de pool 10). Smoke: `GET /api/v1/salud` OK tras reiniciar `start:prod`. Check: `GET /api/v1/salud` True.
- **2026-08-11:** **AQ-SCALE-02/05** — crons líder único con `pg_try_advisory_lock` + rate-limit multi-réplica vía Postgres (`rate_limit_entries`) y `RateLimitGuard` (fallback a Map si falla BD). Smoke: `GET /api/v1/salud` True + `scripts/verificar-rate-limit.ps1` devolvió `429` (OK).
- **2026-08-11:** **Huérfanos UI (Prompt 28) — HUER-REPO-03** — Finanzas: diálogo editar costo fijo conectado a `PATCH /finanzas/costos-fijos/:id`. Check: `dart analyze` finanzas; `verificar-huer-repo-03.ps1` (nuevo) OK.
- **2026-08-11:** **Huérfanos UI (Prompt 28) — D3** — KDS nota/observaciones (PATCH API), combos costeo cableados en Costos/Márgenes y badge «No disponible» ya no tiene `onTap: () {}`. Check: `verificar-huer-d3.ps1` OK · `dart analyze` touched paths OK.
- **2026-08-11:** **Huérfanos UI (Prompt 28) — HUER-CFG-01** — márgenes sede editables (`margen_objetivo_default`, `umbral_alerta_margen`) vía UI/`PATCH /sucursales/margenes/:sucursalId` + costeo usa fallback de sede. Check: `verificar-huer-cfg-01.ps1` OK · `flutter analyze` costeo OK.
- **2026-08-11:** **AQ-SCALE-03** — Menú: eliminadas N+1 de combos (1 query `combo_items` + agrupar por `combo_id`). Check: `scripts/verificar-menu-01.ps1` OK.
- **2026-08-11:** **AQ-SCALE-04 (parcial)** — Cache menú: single-flight por `sucursalId` + TTL 15 min (menos reconstrucciones por expiración). Smoke: `scripts/verificar-menu-01.ps1` OK.
- **2026-08-11:** **PERF-SQL-01** — dashboard “hoy”: `SQL_PEDIDO_ES_HOY` pasó a rango half-open (quita cast `created_at::date`). Check: `scripts/verificar-dashboard-general.ps1` OK.
- **2026-08-11:** **PERF-SQL-02 (parcial)** — dashboard `top_productos_7d` y reportes `/reportes/productos`: reemplazado `SQL_VENTA_LINEA_ITEM` correlacionado por joins a agregados (toppings/bebidas) sin romper consistencia. Check: `scripts/verificar-dashboard-general.ps1` + `scripts/verificar-reportes-analitica.ps1` OK.
- **2026-08-11:** **PERF-SQL-04** — reportes caja: `SQL_FECHA_CAJA_COALESCED_P2_P3` pasó de `COALESCE` a filtros `OR` (sargable). Check: `scripts/verificar-caja-coherencia.ps1` OK.
- **2026-08-11:** **DK-LOG / INF-DISK** — `docker-compose.prod.yml`: agregada rotación de logs (`json-file` max-size/max-file) para evitar crecimiento infinito en VPS. (No requiere VPS para verificar configuración)
- **2026-08-11:** **CAP local** — script `scripts/verificar-cap-local.ps1` OK: levantó 2do backend en `:3001` y probó `429` compartido alternando requests entre `:3000`/`:3001` (rate-limit en Postgres).
- **2026-08-11:** **Huérfanos UI — HUER-REPO-01** — depuración: retiro `InventarioRepository.costosProductos` (método muerto sin callers; duplica costeo). Check: `rg costosProductos(` solo definición + `flutter analyze inventario_repository.dart` OK.
- **2026-08-11:** **Huérfanos DB — HUER-DB-01/02** — deprecación documentada por falta de consumo: `presentaciones_compra` / `ajustes_stock` no aparecen en `foody_backend/src` ni en `lib/`. Check: `rg presentaciones_compra|ajustes_stock` no matches.
- **2026-08-11:** **Bloque D parcial** — HUER-HALF-01: facturación DIAN pausado ya no muestra “Resolución DIAN” en HTML/PDF (backend `FacturacionService`). Check: `verificar-huer-half-01.ps1` OK · `verificar-bloque-d-flutter.ps1`.
- **2026-08-11:** **USR-PERM-01b** — checklist solo plantilla del rol (mesero no ve `abrir_caja`); API rechaza permisos ajenos al rol; UI cobra exige `cobrar_pedido` (botón oculto / mensaje). Check: `verificar-usuario-permisos.ps1`.
- **2026-08-11:** **USR-PERM-01** — checklist de permisos **solo del usuario** editado/creado (no cambia el rol global). Mig `085_usuario_permisos.sql`; `AuthService.permisosEfectivos` (JWT/login); `permisos[]` en crear/actualizar; `GET /usuarios/:id/permisos`; catálogo + `permisos_disponibles`. UI Usuarios. Check: `verificar-usuario-permisos.ps1` OK · `dart analyze` usuarios OK.
- **2026-08-11:** **RBAC-MESERO-04 / RBAC-FIX-04** — `domiciliarios-planta` asignar/reasignar/dispatch/disponibles solo `@Permisos('gestionar_domiciliarios')` (sin OR `ver_pedidos`). Kanban: slot asignar + carga lista solo con ese permiso. Check: `verificar-rbac-mesero-04.ps1` OK. **Bloque C ✅**.
- **2026-08-11:** **API-PAGE** — `opcionesListado` + tope 200; usuarios/productos/insumos paginan con `?page=`; extras catálogo con LIMIT. Flutter sigue recibiendo array sin `page`. Check: `verificar-api-page.ps1` OK.
- **2026-08-10:** **UI Costos Stitch v2** — lista a pantalla completa (scroll único + FAB «ARMAR RECETA» móvil); detalle 2 columnas (preview+Estado Financiero | Mesa/Local+Incluidos+barra Aplicar a la carta); filas desktop con thumb/costo/precio sug.; resumen API +`imagen_url`/`categoria_nombre`/`receta_id`. Check: `dart analyze` costeo.
- **2026-08-10:** **UX-SHELL-01** — widget `SaasScrollableShell` (`NestedScrollView`): cabecera (títulos/KPIs/banners) scrollea; tabs quedan en body. Aplicado en Costos/Márgenes, Analítica, Menú, Insumos, Reportes, caja (respeta `ocultarCabecera`), usuarios, alertas, facturación, domiciliarios, zonas, horarios, sucursales, cocinas. Ya scrollables: Finanzas, Promociones. Check: `dart analyze` paths shell — 0 errors.
- **2026-08-10:** **UI Costos y Márgenes (Stitch)** — resumen Saludable/Margen bajo/Sin costear, margen global, pills Todos/Críticos/Saludables/Sin datos, badges de margen con glow, card Estado Financiero; tokens theme-aware. Lógica costeo intacta. Check: `dart analyze` costeo 0 errors.
- **2026-08-10:** **UI SaaS Insights+Finanzas** — kit `lib/core/saas_ui/` (tokens theme-aware, KPI, charts, filters, tables→cards, empty/alerts/insights); `TemaFoody.claro/oscuro` + `temaModeProvider` (SharedPreferences); toggle en AppBar panel; Analítica Resumen rediseñado (Personalizado `preset=rango`, dual-series vs anterior, heatmap horario, 9 filas); Finanzas hub (KPIs P&L, ingresos vs gastos, donut categorías, tablas CRUD, empty honestos presupuesto/proyección/facturas/flujo). Sin cambios Nest. Check: `dart analyze` paths 0 errors · `verificar-finanzas.ps1` OK · `GET /salud` exito.
- **2026-08-08:** **UX-PAYWALL-BLUR** — preview módulo bloqueado = esqueleto estático borroso (sin montar pantalla ni API) + card upgrade; búsqueda admin con candados. Check: `flutter analyze` OK.
- **2026-08-08:** **DOM-APP** — Shell NavigationBar (activos/historial|ofertas/ingresos/perfil); `TarjetaPedidoDomiciliario` (montos, método pago, tap mapa, sheet contacto WA/llamar); oferta con `ganancia_estimada` API; tab ingresos + filtros fechas; dispatch auto-retry post-expiración + intento vacío persiste radio; FCM/Kanban TTL dinámico. Doc `FRONTEND_DOMICILIARIO_APP.md`. HUER-API-DOM-01 ✅.
- **2026-08-08:** **Bloque D parcial** — FL-NAV-01: `mesas_grid` `push` cajero; FL-WIDGET-02: menú sin `watch` raíz del carrito (`Consumer`+`select`); PERF-FL-IMG: `memCacheWidth/Height` menú cliente + `cacheWidth` thumbs admin. Check: `flutter analyze` paths tocados.
- **2026-08-08:** **Bloque C parcial** — `salio-sin-pagar` usa `PedidosEstadoCommandService` (PED-BYPASS-01); `ParseUUIDPipe` en finanzas / domiciliarios-planta / super-admin; BN-CTRL-07 subtotal DTO; `verificar-ci.ps1 -Completo` incluye bn-* + rt-sec. Check: `verificar-bn-residuales` OK · ciclo-vida §D salio-sin-pagar OK (cobros A/C fallos ajenos previos).
- **2026-08-08:** **Bloque B / RT-SEC-01 ✅** — Topics staff `tipo_{id}_{hmac16}` (`realtime-topics.ts`); Nest emite solo firmados; login + `GET /auth/realtime-canales`; Flutter `realtime_canales` + `FoodyRealtime`. Catálogo/pedido públicos. B2: validador JWT corto en prod. B3: `RATE_LIMIT_FORZAR`. Check: `verificar-rt-sec.ps1` OK · `dart analyze` paths OK. **Re-login staff** tras deploy.
- **2026-08-08:** **F5 / Bloque A piloto ✅** — Founder confirmó pago sandbox → plan actualizado sin sync manual. Criterio A cerrado (waiver archivo + Wompi E2E + PC+túnel). Diferidos: térmica papel + VPS Ubuntu. Docs PRIORIDADES / CHECKLIST_F5 / MASTER / ROADMAP P0-06/07.
- **2026-08-08:** **Bloque A — sesión go-live** — Docker/Supabase/Nest + cloudflared + agente impresión archivo; `verificar-f5-golive` / `verificar-wompi-tunel` OK.
- **2026-08-08:** **PRIORIDADES_FOODY.md** — lista viva A→F consolidada.
- **2026-08-07:** **Residuales menores** — `GET /salud/completo`; `ParseUUIDPipe` en 15 controllers hot; `AprobarPedidoMesaDto` sin `= {}`; PIPE-04 documentado en `main.ts`. Check: `verificar-bn-residuales.ps1` OK (+ query-rest OK).
- **2026-08-07:** **Documentación cierre** — `docs/REMEDIACION_NEST_AUTH_2026-08-07.md`: implementado, scripts OK/FAIL gaps, § **Detalles a pulir**. MASTER + auditorías sincronizados.
- **2026-08-07:** **BN-DTO-01/02** — `RegistrarFcmDto` / `DesactivarFcmDto`; `verificar-bn-dto-fcm.ps1` OK. **BN-CTRL-02/03** — authz usuarios y gate traslados/hermanas bajados a services; `verificar-bn-ctrl-usuarios.ps1` + editar OK. **BN-EXC-18** documentado ✅ (job error auditable).
- **2026-08-07:** **BN-FIX-04 + BN-FIX-05** — `ValidarCodigoPromocionDto`, `BuscarGeografiaDto`; `@IsBoolean` en `CrearPedidoDto`; cron suscripciones retorna `renovaciones_fallos` (EXC-05). Check: `verificar-bn-dto-query.ps1` OK.
- **2026-08-07:** **BN-FIX-06 / BN-PIPE-03 / API-VAL-01** — `ValidationPipe({ whitelist, forbidNonWhitelisted, transform })` en `main.ts`. Props/query desconocidos → 400. Check: `verificar-bn-pipe-forbid.ps1` OK · auth-flow + bn-dto-inline OK.
- **2026-08-07:** **BN-FIX-01 / AQ-SOLID-03 / AQ-DUP-04** — `AlmacenamientoController` delgado (solo multer + scope); ownership SQL, UPDATE `imagen_url` e invalidación menú en `AlmacenamientoService.subirImagenEntidadCatalogo` (producto/promo/combo/categoría). Check: `verificar-bn-almacenamiento.ps1` OK.
- **2026-08-07:** **BN-FIX-03 + RT-SCRIPT-01** — DTOs class-validator BN-DTO-06…19 (pedidos/catálogo/cocina/domi/facturación) + `CotizarDomicilioDto` en query; `verificar-bn-dto-inline.ps1` OK. Script realtime lee `/health` (no `/salud`) para `realtime.conectado`. FL-LEAK-02 ya cubierto por `FoodyRealtime.liberarCanal` (doc sincronizado).
- **2026-08-07:** **AUTH-FLOW / AUTH-REV** — mig `084` (`usuarios`/`domiciliarios_independientes.token_version`); JWT claim `tv`; `UsuarioActivoGuard` rechaza mismatch (`SESION_REVOCADA`); `POST /auth/refresh` (re-emite sin bump) + `POST /auth/logout` (bump); password super-admin bumpea `tv`; Flutter: logout → API luego clear; Dio renueva si `JwtStaff.porExpirar` (30m) + **retry 1×** tras 401 (AUTH-FIX-04). Check: `verificar-auth-flow.ps1` OK · `dart analyze` auth paths OK · `jwt_staff_check` OK.
- **2026-08-07:** **FL-LEAK-01 + BN-DTO-03** — `try/finally` dispose TEC en diálogos inventario (compra/ajuste/lote/conteo); DTOs class-validator en `POST /dispositivos/registrar|vincular-auth` + body anonimizar. Check: `dart analyze` inventario OK · `verificar-f3-confianza.ps1` OK.
- **2026-08-07:** **VIE paquete 1C/2C/3C** — `pagado` exige cocina completa (`listo|no_disponible`) o admin/gerente+motivo; abono→`pagando` libre. Fallo prep `POST /cocina/items/:id/fallo-preparacion` → N/D + merma + alerta. Qty↓ en preparando/listo → `CANTIDAD_COCINA_INMUTABLE`. Check: `verificar-vie-politica.ps1` OK · Jest casos-limite+mesa+caja 7/7. Docs: CASOS_VIERNES + MASTER + INFORME.
- **2026-08-07:** **AQ-DUP-01 cierre** — `CosteoService.aplicarMovimientoStock` delega a `StockMovimientoService` (`tipo=produccion` + `produccion_id`); módulo `StockMovimientoModule` compartido (evita ciclo Costeo↔Inventario). Build OK. **Verificación API:** bloqueada — Docker/Postgres caído (`ECONNREFUSED :5432`); re-correr `verificar-produccion-lote.ps1` + `verificar-inventario-ciclo.ps1` cuando DB esté up.
- **2026-08-06:** **AUTH-WEB-01 (prod-risk)** — En `equipo.foodyy.store` (release) `flutter_secure_storage` lanzaba `MissingPluginException` al leer/guardar JWT → login correo y Google fallaban al persistir sesión (API OK). Fix: web usa SharedPreferences; móvil secure storage + fallback prefs. Rebuild `servir-web-tunel-release.ps1`. Ruido consolas: adblock (`ERR_BLOCKED_BY_CLIENT`), FCM push AbortError, Firebase Identity Toolkit `CONFIGURATION_NOT_FOUND` (**AUTH-FB-01**, no bloquea auth Nest/Supabase). Check: `verificar-f4-sesion.ps1` OK · login local `exito=true` · SPA :8080/túnel 200 · bundle sin canal secure_storage.
- **2026-08-06:** **UX producción en lote** — dos modos claros (stock al vender vs preparar lote); badge «Sin preparar» (no falso stock bajo); CTA Preparar lote; `Prep:` fuera de lista/alertas de insumos. Check: `verificar-produccion-lote.ps1` OK.
- **2026-08-06:** **Unidades receta/subreceta** — UI ya no fuerza `unidad_base` al guardar; selector g/kg o ml/L; backend convierte en costeo y en `expandirReceta` (stock). Check: `verificar-unidades-costeo.ps1` (250g de kg → costo 1050) OK · `dart analyze` paths sin errors.
- **2026-08-06:** **F7 AQ-DUP-01** — `StockMovimientoService` (UPDATE `ingredientes` + INSERT `movimientos_ingrediente`); callers: venta/restaurar/merma (PedidosInventario), ajuste/compra/conteo/traslados (Inventario). PedidosModule importa InventarioModule. Residual: `CosteoService.aplicarMovimientoStock` (`tipo=produccion`). Check: `verificar-inventario-ciclo.ps1` OK; `verificar-pedidos-ciclo-vida.ps1` stock OK (1 assert ajeno: items cobrados).
- **2026-08-06:** **Finanzas claro** — `GET /finanzas/resumen` (mes vs anterior, por pagar, consejos); UI panel ganancia/pérdida + tabs con conteo pendiente; diálogo pago monto/periodo; CTA a tab Rentabilidad; consejos en analitica. Check: `verificar-finanzas.ps1` OK · `dart analyze` sin errors.
- **2026-08-06:** **F7 AQ-CYCLE-01** — `PedidosDispatchHooksService`: PedidosModule ya no importa Domiciliarios; `DispatchService` se registra en `onModuleInit`. Check: `verificar-f7-deuda.ps1` + `verificar-flujo-domicilio.ps1` (auto-dispatch → asignado) OK.
- **2026-08-06:** **F7 — Deuda media (parcial)** — `ParseUUIDPipe` en menú/caja/pedidos/cocina (UUID basura→400); `FoodyRealtime.liberarCanal` + 9 pantallas; KDS botón Urgente + `marcarPrioridadItem`. Abiertos: AQ-DUP-01, AQ-CYCLE-01. Check: `verificar-f7-deuda.ps1` OK · `dart analyze` sin errors.
- **2026-08-06:** **F6 — Perf turno** — mig `083` (`idx_cajas_sucursal_estado`, `idx_movimientos_caja_*`); `GET /caja/:id/movimientos` paginado; Flutter loop páginas; DASH-TZ `(created_at AT TIME ZONE 'America/Bogota')`. Check: `verificar-f6-perf.ps1` OK · `dart analyze` caja_repository sin issues.
- **2026-08-06:** **F5 — Go-live P0 (parcial)** — BN-EXC-01/02: fallo fuente Wompi → `auditoria_logs` + `logger.error`; BN-EXC-18: encolar impresión deja job `error`; cron renovación cuenta fallos; `verificar-f5-golive.ps1` OK (aviso agente offline); checklist humano `CHECKLIST_F5_GOLIVE.md`. **No ✅** hasta térmica/Wompi dashboard/VPS.
- **2026-08-06:** **F4 — Sesión & totales** — JWT staff en `flutter_secure_storage` (+ migración prefs); `POST /pedidos/estimar` (mismo pricing que crear, sin INSERT); checkout muestra total servidor; sheets/badge = hint UI-only. Check: `verificar-f4-sesion.ps1` OK.
- **2026-08-06:** **F3 — Confianza Foody** — `ConfiguracionGlobalModule` carga `configuracion_global_foody` → umbrales/dispatch + `recargar()` tras super PATCH; tab Rentabilidad gated `ver_finanzas`; `DELETE anonimizar` posesión (`fcm_token`/auth) sin mutar `plataforma`; `prueba-web` `@Permisos('ver_dashboard')` + tokens propios. Check: `verificar-f3-confianza.ps1` OK · `dart analyze` 0 errors (4 infos Share deprecados).
- **2026-08-06:** **F2 — Política & stock** — permiso `cobrar_pedido` (admin/gerente/cajero); mesero 403 cobro + UI sin cobro; whitelist estados mesero (`pagando`/`cancelado`); cascade `sincronizarPorIngredienteEnTransaccion` en descontar/restaurar. Mig `082`. Check: `verificar-f2-politica.ps1` OK.
- **2026-08-06:** **F1 — Turno estable** — `onReconectado`+lifecycle en KDS/kanban/caja/mesas/sheet; `_cobrando`+`idempotency_key`; post-timeout GET; mig `081` (`uq_caja_abierta_sucursal` + `cobros_idempotencia`); caja insert+23505. Check: `verificar-f1-turno.ps1` OK · `dart analyze` sin errors en paths F1.
- **2026-08-06:** **F0 — Parar sangre** — IDOR `POST /caja/cerrar` scopea sucursal de la caja; prepago no bloquea cierre (`SQL_WHERE_PEDIDO_OPERACION_ABIERTA` + cocina→`pagado`); VIE-01 demote `listo`/`pagando`→`en_cocina`; COC-NODISP `no_disponible` resuelto. Checks: `verificar-idor-scope.ps1` · Jest casos-limite+cocina 6/6.
- **2026-08-06:** **Unificación docs** — `AUDITORIA_*.md` movidos a `archivo/auditorias-prompts/`; README hub corto; AGENTS + foody-avance apuntan a MASTER + INFORME_MAESTRO; qa-sesiones archivadas.
- **2026-08-06:** **Prompt 35 Informe maestro** — Consolida Prompts 01–34: inventario por severidad/módulo; fichas crítico/alto con archivo+causa+código+horas; plan F0–F8 por impacto restaurante (no por facilidad); §6 CAP/VIRAL como decisiones infra/$$ (no bugfix). Doc: `INFORME_MAESTRO_FOODY.md`.
- **2026-08-06:** **Prompt 34 Infra extremos** — Timeout Dio 15/45s mid-TX (COMMIT posible); doble cobro paralelo 1 OK/1 reject; mensajes offline OK; splash staff entra con API caída; resync = RT-RECON/LIFE. UI cobro mesa/kanban sin busy. IDs **INFRA-EXT-\***. Check: `verificar-infra-extremos.ps1`. Docs: `archivo/auditorias-prompts/AUDITORIA_INFRA_EXTREMOS.md`.
- **2026-08-06:** **Prompt 33 E2E** — Jest/Supertest 7 suites / 14 tests (mesa, QR, domicilio, cocina, caja + casos límite 28–30: VIE-01, VIE-05/13, VIE-06, PED-PREPAGO-01, COC-NODISP-01). Flutter `test/e2e` 5/5 + wrapper `integration_test`. Scripts `verificar-e2e-jest.ps1` / `verificar-e2e-flutter.ps1`. Stub Hello World → `/salud`. Gaps: click-through UI, GH Actions seed. Docs: `archivo/auditorias-prompts/AUDITORIA_E2E_AUTOMATIZADO.md`.
- **2026-08-06:** **Auditoría Prompt 32** — Spike viral registros D1 500 / D2 5k / D3 20k / D4 40k. Flujo real: registro síncrono + bcrypt + TX (~13 inserts); sin OTP WhatsApp/MATIAS/FCM bienvenida. Falla primero: pool PG + CPU bcrypt (no externos). Roadmap escalado F0–F7 (waitlist→Redis→PgBouncer→Nest→PG dedicado). IDs **VIRAL-\*** + **VIRAL-FIX-01…08**. Docs: `archivo/auditorias-prompts/AUDITORIA_VIRAL_SPIKE.md`.
- **2026-08-06:** **Auditoría Prompt 31** — Capacity planning 100/500/1k/5k/10k. Vivo: Nest 1 proceso, `DB_POOL_MAX=25`, PG `max_connections=100` / `shared_buffers=128MB`, ~44 backends; techo ~8–20 RPS (PERF). Tablas: `notificaciones_pendientes` ~39k sin purge, `auditoria_logs` ~33k. Veredicto: 100 parcial piloto; 500+ no sin PgBouncer/PM2/Redis; 1k+ réplica+partición. WhatsApp/MATIAS no son carga (no impl.). IDs **CAP-\*** + **CAP-FIX-01…10**. Docs: `archivo/auditorias-prompts/AUDITORIA_CAPACITY_PLANNING.md`.
- **2026-08-06:** **Auditoría Prompt 30** — Casos viernes alta demanda (13). REGLA_CLARA: transfer, race, no reopen, snapshots, cola impresión, restart PG. BUG: **VIE-01** add con pedido `listo`; **VIE-12** reconnect; **VIE-QTY-01** qty↓ vs merma. DECISIÓN_PENDIENTE (A/B/C): **VIE-05** split/cobro vs cocina; **VIE-09** agotado mid-prep; **VIE-13** cobro pre-listo. Vivo: ciclo+meseros+promos+kds OK. Docs: `archivo/auditorias-prompts/AUDITORIA_CASOS_VIERNES.md`.
- **2026-08-06:** **Auditoría Prompt 29** — Consistencia entre módulos (6 rutas). NEW: **CONS-STOCK-CASCADE-01** (venta no cascadea hermanos), **CONS-PROMO-ADD-01**, **CONS-NODISP-STOCK-01**, **CONS-KDS-UI-01**, **CONS-REP-OPEN-01**, **CONS-COSTO-SNAPSHOT-01**. Reconfirmados PED-PREPAGO / COC-NODISP / CFG-GLOBAL-DEAD / RT-RECON / DASH-*. Vivo: caja-coherencia OK; KPI analítica=reportes 438175; cuadre diff 141k; inventario+promos OK; script coherencia ya no llama `/caja/estado`. Docs: `archivo/auditorias-prompts/AUDITORIA_CONSISTENCIA_MODULOS.md`.
- **2026-08-06:** **Auditoría Prompt 28** — Funcionalidad huérfana: cruce `MAPA_FOODY` ↔ Nest ↔ Flutter. Producto: KDS prioridad/obs, costeo combos, ganancias indep., badge No disponible, tab Rentabilidad sin `ver_finanzas`, CFG-GLOBAL-DEAD, márgenes sede, repos muertos, tablas schema-only. Ops health/impresión/webhook = intencional. Docs: `archivo/auditorias-prompts/AUDITORIA_FUNCIONALIDAD_HUERFANA.md` · MASTER § HUER-\*.
- **2026-08-06:** **NOC Foody** — `SUPERADMIN_FOODY_CONTROL.md` = Centro de Operaciones (visión 10 módulos). **Fase A esencial ahora:** home semáforo + KPI Gratis/Pro/Ultra + freemium kill switch + plan auditado + errores agrupados + asistente por reglas. B/C diferidas. No construir visión completa pre-go-live.
- **2026-08-06:** **Auditoría Prompt 27** — Fuzz inputs: 45 casos (auth/menú/pedidos/staff); **0 stack** al cliente; API viva; 6× UUID/path basura → `ERROR_INTERNO` 500 (envelope OK); mesas nombre 5k aceptado (run previo). IDs **FUZZ-STABLE/STACK/500/LEN/VAL** + **FUZZ-FIX-01…04**. Check: `verificar-fuzz-inputs.ps1`. Docs: `archivo/auditorias-prompts/AUDITORIA_FUZZ_INPUTS.md`.
- **2026-08-06:** **Spec Foody Control** — Documento `docs/SUPERADMIN_FOODY_CONTROL.md`: KPI cuentas Gratis/Pro/Ultra; cambio plan con motivo; semáforo “¿escalar?” en lenguaje no técnico; incidentes inteligentes (INC-LOAD/ERR/FREE); cupos freemium + kill switch; API propuesta `/super/salud-operativa`. Backlog **SAC-KPI/PLAN/FREE/CAP/INC**. Base ya existente: `GET /super/estadisticas`, `PATCH /super/suscripciones`. Enlace en `docs/README.md` + MASTER §17.
- **2026-08-06:** **Auditoría Prompt 26** — Estrés/concurrencia: multi-tenant GET 60/60 OK; idempotency pedido OK; doble `en_cocina` serializado (FOR UPDATE + no-op); inventario LWW absoluto sin row lock; abrir caja TOCTOU (API-IDEM-03, race omitida si turno abierto); sostenido/pico ligeros 0 fail; mixto 100×3 p99~10s ≡ PERF-LOAD. IDs **CONC-MT/PED/INV/CAJ/LOAD** + **CONC-FIX-01…05**. Checks: `verificar-estres-concurrencia.ps1` · `estres-1000-usuarios.mjs`. Docs: `archivo/auditorias-prompts/AUDITORIA_ESTRES_CONCURRENCIA.md`.
- **2026-08-06:** **Auditoría Prompt 25** — OWASP: SQL parametrizado OK (`SqlParams`); BAC Prompt 06 reconfirmado (IDOR caja, cobro mesero, anonimizar, prueba-web) + finanzas `ver_finanzas` escribe; JWT fallback/DK-SEC; rate limit solo prod; RLS **74/74** FORCE (sin regresión post-080). Fix menor: `config/foody-entorno.env` → `.gitignore`. IDs **SEC-INJ/BAC/SECRET/RLIMIT/RLS** + **SEC-FIX-01…08**. Checks: `verificar-owasp.ps1` · `verificar-rls.ps1` · `verificar-idor-scope.ps1`. Docs: `archivo/auditorias-prompts/AUDITORIA_OWASP.md`.
- **2026-08-06:** **Auditoría Prompt 24** — Performance Flutter: listas (caja shrinkWrap unbounded = peor path; cerrados/mis pedidos/movs inv OK); memoria turno (Realtime sin `removeChannel`, `_movimientos` crece); imágenes (lazy scroll sí, 0 `memCache*`, Nest sharp WebP≤800, `flutter_image_compress` sin uso). IDs **PERF-FL-LIST/MEM/IMG** + **PERF-FL-FIX-01…09**. Check: `scripts/verificar-perf-flutter.ps1`. Docs: `archivo/auditorias-prompts/AUDITORIA_PERF_FLUTTER.md`.
- **2026-08-06:** **Auditoría Prompt 23** — Performance backend: EXPLAIN (Seq Scan `pedido_items`/`movimientos_caja`, `created_at::date`, SubPlan `SQL_VENTA_LINEA_ITEM`); caché solo menú; carga RunspacePool 10/50/200 → 0 fails pero p50 0.4s→7–10s (techo ~8–20 RPS, pool 25). IDs **PERF-SQL/IDX/CACHE/LOAD/POOL** + **PERF-FIX-01…09**. Check: `scripts/verificar-perf-backend.ps1`. Docs: `archivo/auditorias-prompts/AUDITORIA_PERF_BACKEND.md`.
- **2026-08-06:** **Auditoría Prompt 22** — Config restaurante: horarios/zonas/fiscal/cocinas/fiado con UI; **sin** PATCH sede ni márgenes sede; marca sin nombre; `poligono` muerto. Propagación: sin reinicio Nest, sin RT config; horario bustea menú cache; plan guard lee BD. **CFG-GLOBAL-DEAD** (Alta): UI super edita umbrales/comisión/radios pero runtime = hardcode. Check: `scripts/verificar-config-restaurante.ps1`. Docs: `archivo/auditorias-prompts/AUDITORIA_CONFIGURACION.md`.
- **2026-08-06:** **Auditoría Prompt 21** — Dashboard general: sin RT/poll ni hora «Actualizado»; sin cache Nest (SQL vivo); KPI Ventas→Caja; `pedidos_pendientes_qr` API-only; top «unidades» vs ORDER BY ventas; riesgo TZ `created_at::date` vs Bogota. Consistencia hoy OK: ventas_hoy=financiero=analítica **187200**. Gaps: **DASH-TZ-01**, **DASH-RT-01/02**, **DASH-ORPH-02**. Check: `scripts/verificar-dashboard-general.ps1`. Docs: `archivo/auditorias-prompts/AUDITORIA_DASHBOARD.md`.
- **2026-08-06:** **Auditoría Prompt 20** — Reportes/analítica: financiero+resumen+top producto = SQL crudo (239200/22/800); filtros analítica AND; reportes solo fechas; 365d ~30ms (Seq Scan, 528 pedidos); umbrales `UMBRALES_ALERTA` = spec; batch ≠ stock/cuadre. Gaps: **ANA-FILT-PROD-01**, **ANA-PERF-01**, **REP-LINE-01**, **ANA-ESTADOS-01**. Check: `scripts/verificar-reportes-analitica.ps1`. Docs: `archivo/auditorias-prompts/AUDITORIA_REPORTES.md` · `ALERTAS_AUTOMATICAS.md` actualizado.
- **2026-08-06:** **Auditoría Prompt 19** — Facturación: **0 refs MATIAS**; sin cola/reintentos/estados DIAN. Capa interna verificada: borrador→emitir (`FE-########`)→HTML; total factura=pedido; anular soft + stub NC; pedido `pagado` intacto; cancel pagado bloqueado. Gaps pospuestos: **FE-MATIAS-01**, **FE-QUEUE-01**, **FE-NC-01**, **FE-ITEMS-01**. Check: `scripts/verificar-facturacion-ciclo.ps1`. Docs: `archivo/auditorias-prompts/AUDITORIA_FACTURACION.md`.
- **2026-08-06:** **Auditoría Prompt 18** — Promociones/precios: desactivar promo con pedido abierto **mantiene** descuento (snapshot); pedido nuevo rechaza código; cobro = total congelado. Cambio precio catálogo: ítems abiertos conservan `precio_unitario`; ítems nuevos toman precio actual; cobro mixto OK. Combo + promo **se apilan**; máx. 1 promo (auto = mejor). Gaps: **PROMO-STACK-01**, **PROMO-DEL-01**, **PROMO-MANUAL-01**. Check: `scripts/verificar-promociones-precios.ps1`. Docs: `archivo/auditorias-prompts/AUDITORIA_PROMOCIONES.md` · MASTER § Promociones.
- **2026-08-06:** **Auditoría Prompt 17** — Clientes/QR: menú+`POST /pedidos` públicos → `pendiente_aprobacion` (sin JWT); **no** autoservicio sin mesero; precio body ignorado (BD); producto off/ajeno rechazado; token QR permanente tras mesa libre; multi-device OK; expiración dura solo cierre caja >30m. Gaps: **QR-AUTO-01**, **QR-MESA-ID-01**, **QR-EXP-01**. Check: `scripts/verificar-qr-cliente.ps1`. Docs: `archivo/auditorias-prompts/AUDITORIA_CLIENTES_QR.md` · MASTER § Mesas/QR.
- **2026-08-06:** **Auditoría Prompt 16** — Domicilios: ciclo `pendiente→…→entregado` con cobro al entregar (sin venta al crear); `listo→entregado` bloqueado; admin `ocupado` coherente; cancel mid-ruta solo admin (asignación `cancelado`, caja neto 0, merma). Gaps: **DOM-CANCEL-INDEP-01** (no restaura `disponible`), **DOM-CANCEL-OFERTA-01**, **DOM-EVID-01**. Check: `scripts/verificar-domicilios-ciclo.ps1`. Docs: `archivo/auditorias-prompts/AUDITORIA_DOMICILIOS.md` · MASTER § Domiciliarios.
- **2026-08-06:** **Auditoría Prompt 15** — Meseros/mesas: asignación turno + bloqueo otra mesera; transfer pedido en curso (`FOR UPDATE`, historial); split = cobro parcial post-cocina (mismo pedido, **no** hijo); carrera 2 adds serializada sin lost update; sin columna `version`. Aceptados: **MES-SPLIT-HIJO-01**, **MES-XFER-MESERA-01**, **MES-XFER-UI-01**, **MES-MSG-01**. Check: `scripts/verificar-meseros-mesas.ps1`. Docs: `archivo/auditorias-prompts/AUDITORIA_MESEROS_MESAS.md` · MASTER § Mesas.
- **2026-08-06:** **Auditoría Prompt 14** — Inventario: descuento **automático** al `en_cocina`/`confirmado` (`stock_descontado`; gap “solo manual” cerrado). Propagación plato→subreceta→insumo OK (script −100g Papa). Alerta `stock_minimo_alcanzado` (medio) → panel/RT, **sin FCM**. Ajuste `PATCH` registra `usuario_id`+motivo en `movimientos_ingrediente`, **no** en `auditoria_logs`; API/UI omiten quién. Aceptados: **INV-ALERT-FCM-01**, **INV-ALERT-AJUSTE-01**, **INV-AUD-01**. Check: `scripts/verificar-inventario-ciclo.ps1`. Docs: `archivo/auditorias-prompts/AUDITORIA_INVENTARIO.md` · MASTER § Inventario.
- **2026-08-06:** **Auditoría Prompt 13** — Caja: sync cobro=`pedidos.total` (tope anti-doble); mixto efectivo+tarjeta = N movimientos; reapertura `pagado` bloqueada (correcto); cancel sin cobro no mueve caja / prepago → devolución; cierre con cuadre+alerta; arqueo ciego oculta saldo. Aceptados: **CAJ-DOM-IMPAGO-01** (domi parcial bloquea cierre), **CAJ-MSG-01**, **CAJ-TURNO-01**. Check: `scripts/verificar-caja-ciclo.ps1`. Docs: `archivo/auditorias-prompts/AUDITORIA_CAJA.md` · MASTER § Caja.
- **2026-08-06:** **Auditoría Prompt 12** — Cocina/KDS: sync RT `cocina_{id}` + poll; pedido nuevo en tickets + `comanda_copia`; DELETE ítem staff post-prep OK (KDS lo pierde); cocina sin DELETE (solo `no_disponible`). Abiertos: **COC-NODISP-01** (ítem no_disponible impide pedido `listo`), **COC-UI-PRIO-01** (API prioridad sin UI). Parciales: **COC-CANCEL-01**, **COC-FSM-01**, **COC-REIMP-01**. OK: RT, FIFO+urgencia cliente, flujo todos-listo, reimpresión vía edición. Check: `scripts/verificar-kds.ps1`. Docs: `archivo/auditorias-prompts/AUDITORIA_COCINA_KDS.md` · MASTER § Cocina/KDS.
- **2026-08-06:** **Auditoría Prompt 11** — Pedidos ciclo de vida: mapa 13 estados + `TRANSICIONES_PEDIDO` + puerta `PedidosEstadoCommandService`. API Kanban **no** fuerza inválidas (script OK). Ciclo mesa `en_cocina→listo→pagando→pagado` dispara stock/caja/mesa/historial. Edición post-cocina: stock+reimpresión+merma. Abiertos: **PED-PREPAGO-01** (para llevar efectivo cobra en crear pero queda `en_cocina` → bloquea cierre caja), **PED-BYPASS-01** (`salio-sin-pagar` UPDATE fuera del command), **PED-DOC-01**. Aceptados: **PED-COBRO-SKIP-01**, **PED-EDIT-01**, **PED-CHECK-01**. Check: `scripts/verificar-pedidos-ciclo-vida.ps1`. Docs: `archivo/auditorias-prompts/AUDITORIA_PEDIDOS_CICLO_VIDA.md` · MASTER § Pedidos ciclo.
- **2026-08-06:** **Auditoría Prompt 10 + fix** — Realtime: **`RT-CHAN-01` corregido** (`catalogo_disponibilidad` se emitía solo en `sucursal_{id}` pero el menú cliente y el POS escuchaban `sucursal_{id}_catalogo` → suscripción muerta, productos agotados no refrescaban; ahora emite en ambos topics). Abiertos: **`RT-SEC-01`** (canales no privados: con la anon key + `sucursal_id` público se escucha `caja_movimiento`/alertas → sube OPS-07), **`RT-RECON-01`** (el socket sí reconecta y re-une topics, pero broadcast no tiene replay y nada refetchea al volver), **`RT-POLL-01`** (intervalo de respaldo se fija una sola vez al abrir la pantalla), **`RT-FALL-01`** (menú cliente/POS/panel sin poll), **`RT-LIFE-01`** (sin refetch en `resumed`), **`RT-LEAK-01`** (9 pantallas exactas con `unsubscribe` sin `removeChannel`, agrava la reconexión ≡ FL-LEAK-02), **`RT-ENV-01`** (`SUPABASE_URL` 2× activa en `.env`: gana la última, la primera se ignora en silencio), **`RT-SCRIPT-01`** (`verificar-realtime.ps1:63` lee un campo de salud inexistente → aviso falso permanente). Comprobado OK: **`RT-ORPH-01`** sin eventos huérfanos ni oyentes sin emisor (el `ping` de `foody_health_check` es interno y correcto). Consistencia 2 dispositivos: BD converge (`FOR UPDATE` + máquina de estados), UI es convergencia eventual (ventana ≤90 s). Nuevo check `scripts/verificar-realtime-canales.js` (16/16 OK) — el `verificar-realtime.ps1` existente solo comparaba nombres de evento, no topics. Docs: `archivo/auditorias-prompts/AUDITORIA_REALTIME.md` · MASTER § Realtime.
- **2026-08-06:** **Control financiero** — migr. `080_finanzas_control.sql` (gastos libro único + `empleados` + permiso `ver_finanzas`); Nest `FinanzasModule` (`/finanzas/costos-fijos|empleados|gastos`); `GET /analitica/rentabilidad` (ventas − COGS − gastos = utilidad neta + punto equilibrio); Flutter `FinanzasAdminScreen` + tab Rentabilidad; `verificar-finanzas.ps1` OK (403 rol + arqueo intacto). Spec completa: **`docs/MODULO_FINANZAS.md`** (hecho/parcial/pendiente/recomendaciones). Docs MASTER §23.
- **2026-08-06:** **Auditoría Prompt 09** — Infra: sin Nginx en repo (edge=Tunnel); `foody-assets` público intencional; R2 backups no activos; tunnel PC foreground (WiFi riesgo); SSL=Cloudflare; disco sin presupuesto + logs sin tope. IDs **INF-NGX/R2/TUN/SSL/DISK** + **INF-FIX-01…07**. Docs: `archivo/auditorias-prompts/AUDITORIA_INFRA.md` · MASTER § Infra. Sin cambios de código.
- **2026-08-06:** **Auditoría Prompt 08** — Docker/env: prod compose Nest-only + HC + `unless-stopped`; sin logging rotation (disco Hetzner); JWT example bypassa validador; compose/Dockerfile untracked; sin `.dockerignore`. IDs **DK-COMPOSE/SEC/HC/RST/LOG** + **DK-FIX-01…07**. Docs: `archivo/auditorias-prompts/AUDITORIA_DOCKER_ENV.md` · MASTER § Docker. Sin cambios de código.
- **2026-08-06:** **Auditoría Prompt 07** — BD/Supabase: RLS 73/73 deny-all (sin policies tenant); índices gap caja/movimientos; FK producto→pedido_items NO ACTION (historial seguro); N+1 menú/clone/stock; backups scripts listos, cron VPS+R2 no activos. IDs **BD-RLS/IDX/FK/N1/BKP** + **BD-FIX-01…07**. Docs: `archivo/auditorias-prompts/AUDITORIA_BD_SUPABASE.md` · MASTER § BD. Sin cambios de código.
- **2026-08-06:** **Auditoría Prompt 06** — RBAC: `@Permisos` es OR; mesero cobra y cambia estados vía API (no módulo `/caja`); IDOR crítico cerrar caja por UUID ajeno; `anonimizar` público; `prueba-web` FCM global. IDs **RBAC-GUARD/MESERO/CAJA/TENANT** + **RBAC-FIX-01…07**. Docs: `archivo/auditorias-prompts/AUDITORIA_RBAC.md` · MASTER § RBAC. Sin cambios de código.
- **2026-08-06:** **Auditoría Prompt 05** — Auth/JWT: sin refresh/logout server; TTL 7d; `UsuarioActivoGuard` corta desactivados en el siguiente request; Flutter SharedPreferences (no secure); mid-action → login sin retry; WhatsApp OTP ausente. IDs **AUTH-FLOW/EXP/REV/STORE/OTP** + **AUTH-FIX-01…06**. Docs: `archivo/auditorias-prompts/AUDITORIA_AUTH_JWT.md` · MASTER § Auth. Sin cambios de código.
- **2026-08-05:** **Auditoría Prompt 04** — APIs REST: creates 200 (no 201), conflictos caja/cobro como 400, sin `ParseUUIDPipe`/`forbidNonWhitelisted`, paginación solo pedidos+movimientos inventario (caja/usuarios/catálogo unbounded), idempotencia fuerte en crear pedido + Wompi (débil en cobro/abrir caja), envelope `{exito}` consistente con aplanado de códigos. IDs **API-HTTP/VAL/PAGE/IDEM/FMT** + **API-FIX-01…06**. Docs: `archivo/auditorias-prompts/AUDITORIA_APIS_REST.md` · MASTER § APIs REST. Sin cambios de código.
- **2026-08-05:** **Auditoría Prompt 03** — Flutter estructura: estado (1 Riverpod + setState masivo), god screens (>1k LOC×15), `ref.watch(carrito)` rebuilda menú, leaks TEC inventario + Realtime sin `removeChannel`, `go('/admin/cajero')` rompe back-stack, 0 Dio en widgets (repos embebidos). IDs **FL-STATE/WIDGET/LEAK/NAV/API** + **FL-FIX-01…07**. Docs: `archivo/auditorias-prompts/AUDITORIA_FLUTTER_ESTRUCTURA.md` · MASTER § Flutter. Sin cambios de código.
- **2026-08-05:** **Auditoría Prompt 02** — NestJS estructura: módulos SRP (overlap métricas, god Pedidos/Auth, salud/health duplicado), controllers (almacenamiento SQL, authz en usuarios), DTOs (~19 bodies inline sin class-validator, CotizarDomicilioDto huérfano), catch billing Wompi/renovación silenciosos, ValidationPipe sin `forbidNonWhitelisted`. IDs **BN-MOD/CTRL/DTO/EXC/PIPE** + **BN-FIX-01…06**. Docs: `archivo/auditorias-prompts/AUDITORIA_BACKEND_NESTJS.md` · MASTER § Backend NestJS. Sin cambios de código.
- **2026-08-05:** **Auditoría Prompt 01** — deuda estructural documentada: duplicación (stock paralelo, guards, crons DIY, math Flutter), ciclos Nest `pedidos↔domiciliarios` + Flutter admin↔pedidos/menu↔pedidos, violaciones Flutter=UI (carrito/costeo), acoplamiento hub pedidos, escala 50→500 (pool/N+1/rate-limit/crons), inconsistencias nombres. IDs **AQ-DUP/CYCLE/SOLID/COUPLE/SCALE/NAME** + backlog **AQ-FIX-01…07**. Docs: `archivo/auditorias-prompts/AUDITORIA_ARQUITECTURA_CALIDAD.md` · MASTER § Arquitectura/calidad · canvas Cursor. Sin cambios de código.
- **2026-08-05:** **MAPA_FOODY** — inventario vivo: módulos Nest (controllers/services/DTOs), pantallas Flutter por rol, endpoints `/api/v1`, 73 tablas + FKs (001–079), matriz tests (Jest casi vacío vs 58 `verificar-*.ps1`). Índice en `docs/README.md`.
- **2026-08-04:** **Icono app** — fuente `assets/logo_foody.png` (1024², fondo blanco) regenerado en Android/Windows/web PWA; adaptive bg `#FFFFFF`.
- **2026-08-04:** **Escanear mesa = solo cámara** — sin pegar URL/token (el QR de mesa basta); preview a pantalla completa también en web; fallback permiso. Maps JS: `loading=async` en `web/index.html`.
- **2026-08-04:** **Escanear mesa UX** — AppBar surface/ink; hero web; campo densificado; Pegar portapapeles + CTA ink; banner «Ya estás en mesa»; linterna + haptic al detectar. Sin cambios API.
- **2026-08-04:** **Historial cliente en la nube** — migración `079_cliente_auth_uid` (`dispositivos_cliente.auth_uid`, `pedidos.cliente_auth_uid`); `POST /dispositivos/vincular-auth`; `GET /pedidos/mios` acepta Bearer Supabase; crear pedido hereda uid; Flutter Google OAuth cliente (no staff) + banner en Mis pedidos; UX Analítica seguimiento/mis pedidos. `verificar-historial-cliente-auth.ps1` OK.
- **2026-08-04:** **Icono app Foody** — `assets/foody.png` vía `flutter_launcher_icons` en Android (mipmap + adaptive), Windows (`app_icon.ico` 256), web/PWA (`favicon` + Icon-192/512 + manifest Foody). Favicon/apple-touch en `web/index.html`.
- **2026-08-04:** **UX checkout cliente** — AppBar surface/ink + sede; tip datos; tipo/pago chips ink; campos densos; resumen card; CTA «Hacer pedido» ink. Lógica pedido/domicilio/promo intacta.
- **2026-08-04:** **Carrito detalle real** — `detalleIncluye`/`etiquetaTipo` en línea (snapshot al agregar); tap → sheet Incluye/extras/obs/subtotal; swipe elimina; Vaciar con confirm; `eliminarLinea`. Sin API.
- **2026-08-04:** **UX carrito cliente** — AppBar surface/ink; pasos pedido Analítica; cards densas + pill cantidad; CTA ink; tip cantidades. `FoodyPasosPedido` sin naranja/teal.
- **2026-08-04:** **UX menú cliente** — AppBar/chips/cards/CTA ink; tip «Toca +»; entrada staggered; botón + con rebote; snackbar «Ver» carrito; sheet producto/combo + upsell Analítica (precio animado, tip extras). Sin cambios API.
- **2026-08-04:** **UX sucursales cliente** — AppBar surface/ink + «Elegí una sede»; cards densas Analítica (anillo icono, CTA «Ver menú» ink); canvas + pull-to-refresh. Auto-nav sede única intacto.
- **2026-08-04:** **Estados premium** — `promocion_story_viewer`: long-press oculta chrome (barras/header/caption/CTA) + pausa; swipe down cierra (umbral + haptic); tiempo relativo (`created_at` → `2 h`). Sin cambios API.
- **2026-08-04:** **UX home lugares (cliente)** — AppBar surface/ink; estados anillo monocromo; búsqueda + cards sin gradiente naranja+teal; nav inferior ink. API/filtro intactos.
- **2026-08-04:** **UX elegir ciudad** — sin AppBar naranja; header Foody + título denso; tiles con icono/borde Analítica. Preferencia + FCM intactos. `dart analyze` 0 errores.
- **2026-08-04:** **UX splash cliente/equipo** — fondo neutro Analítica (sin gradiente naranja+teal); logo en card; spinner ink; animación suave. Lógica arranque intacta.
- **2026-08-04:** **UX registro repartidor** — card Analítica + espera ink; API intacta.
- **2026-08-04:** **UX Crear restaurante + login repartidor** — mismo shell Analítica que login staff (`AuthFormEstilo`); sin AppBar naranja; CTA ink; OAuth/ciudades/API intactos. `dart analyze` 0 errores.
- **2026-08-04:** **UX login staff** — canvas/gradiente sutil, card densa, marca ink, campos muted, CTA ink, Google outlined, demo en acordeón, links ink. Auth/OAuth/shake intactos. `dart analyze` 0 errores.
- **2026-08-04:** **UX chrome panel** — sidebar oscuro con activo/grupo/favoritos neutros (logo Foody solo en marca); AppBar surface/ink, chip sede outlined, iconos inkMuted, canvas Analítica. Navegación/favoritos intactos. `dart analyze` 0 errores.
- **2026-08-04:** **UX Pedidos (kanban/grid)** — header/KPI Activos+Total; chips canal + tabs estado ink; cards `AnaliticaTokens` con franja urgencia (≥8/≥15); CTA ink (Listo verde); columnas kanban ink. Realtime/filtros/API intactos. `dart analyze` 0 errores.
- **2026-08-04:** **Dashboard gráficos = Analítica** — reutiliza `AnaliticaChartCard` / `AnaliticaCharts` (línea con gradiente+tooltip, donut neutro, barras top). Sin API nueva.
- **2026-08-04:** **Dashboard operativo** — KPIs densos + acordeones por prioridad: Mesas demora (QR≥3 / cocina≥20 / cobro≥10), Domicilios planta tardíos, Stock bajo, Alertas top 8 (crítico→bajo). Gráficos estilo Analítica debajo. Sin API nueva (compone mesas/pedidos/inventario/alertas). `dart analyze` 0 errores.
- **2026-08-04:** **UX Config. cocinas e impresoras** — header + KPIs (sin impresora); dual Cocinas‖Impresoras ≥980; cards con badges/riesgo; menú «Añadir impresora» desde cocina; FoodyDialogo + dispose seguro. API intacta. `dart analyze` 0 errores.
- **2026-08-04:** **KDS Cocina | Listos** — dos pestañas arriba; al marcar Listo el ticket sale de Cocina y pasa a Listos (snackbar + Ver); Listos con «Volver a cocina»; sin mezclar pendientes y terminados. API intacta.
- **2026-08-04:** **UX Cocina en vivo (KDS)** — tickets sin alto fijo (Wrap + altura al contenido); urgencia por franja (10/20 min) + tiempo `1h 20m` (no todo rojo/`99+`); Listo grande + iconos secundarios; «Todo listo (N)» por ticket; barra activos/demorados; diálogo No disp. con dispose seguro. Lógica/Realtime intacta. `dart analyze` 0 errores.
- **2026-08-04:** **UX Gestionar repartidores** — KPIs; reglas≠liquidar/equipo; dual ≥980; CTA header; diálogo dispose seguro.
- **2026-08-04:** **UX Zonas domicilio (de verdad)** — no solo color: escritorio mapa‖lista (≥980); móvil mapa más bajo; leyenda + «Ubicación» sobre el mapa; anillos ordenados cerca→lejos; edición con chips km/precio. API intacta.
- **2026-08-04:** **UI Mis sucursales** — `sucursales_admin_screen`: canvas/tokens Analítica; marca con vista previa tipo app cliente; CTA ink, FoodyDialogo. Lógica marca/crear intacta.
- **2026-08-04:** **UI Mis sucursales** — `sucursales_admin_screen`: canvas/tokens Analítica; marca con vista previa tipo app cliente + tiles Portada/Logo (zoom, estado OK/Pendiente, subir/cambiar); CTA ink, FoodyDialogo. Lógica marca/crear intacta. `dart analyze` 0 errores.
- **2026-08-04:** **UI Horarios** — `horarios_admin_screen`: canvas/tokens Analítica, resumen cliente neutro, cards densas por día, switch ink, FoodyDialogo; edición por clic (lista por hora en punto, sin reloj). Lógica horarios intacta. `dart analyze` 0 errores.
- **2026-08-04:** **UI Usuarios** — `usuarios_admin_screen`: canvas/tokens Analítica, header denso, cards con iniciales + badges rol/cocina, switch ink, vacío/error, FoodyDialogo en crear/editar. Lógica staff intacta. `dart analyze` 0 errores.
- **2026-08-04:** **UI Alertas** — `alertas_admin_screen`: canvas/tokens Analítica, chip/CTA ink (sin naranja), cards densas con badges tipo/nivel (sin slugs crudos), vacío/error guiados, skeleton. Lógica listar/revisar/evaluar/Realtime intacta. `dart analyze` 0 errores.
- **2026-08-04:** **Mesas polish** — tarjetas sin wash de color (barra 3px + punto); KPIs neutros; `FoodyDialogo` (tema ink) en todos los modales de mesa/cuenta/cobro/comensal. Sin cambios API.
- **2026-08-04:** **UI Mesas (piso)** — `mesas_grid_widget` + `mesa_pedidos_sheet`: salón creativo (cards táctiles, CTA, filtros KPI, orden QR→ocupadas, banner semántico); sheet cuenta densificado. Sin cambios API/lógica. `dart analyze` 0 errores.
- **2026-08-04:** **UI Caja** — `caja_admin_screen`: canvas/tokens Analítica, header denso, apertura sin naranja, métricas/movimientos/CxC/acciones laterales, cerrar semántico. Lógica caja intacta. `dart analyze` 0 issues.
- **2026-08-04:** **UI Nuevo pedido** — `pedido_cajero_screen` + `OperacionTipoToggle`: canvas/tokens Analítica, header denso, chips ink, cards neutras, avisos semánticos, carrito + confirmar ink. Lógica POS/caja intacta. `dart analyze` 0 errores.
- **2026-08-04:** **UI Promociones** — `promociones_admin_screen`: canvas/tokens Analítica, header denso, vacío guiado, cards con badges (activa/video/24h/vistas), FAB ink, diálogo alineado. Sin cambios API. `dart analyze` 0 issues.
- **2026-08-04:** **UI Plan y pagos** — `mejorar_plan_screen`: canvas/tokens Analítica, header denso, suscripción con badge semántico, renovar ink, planes 3 columnas ≥980px, historial denso. Lógica Wompi/sync intacta. `dart analyze` 0 errores.
- **2026-08-04:** **UI Facturación** — `facturacion_admin_screen`: canvas/tokens, header denso, tabs, config agrupada (emisor / IVA / resolución), form responsive, lista facturas con badges emitida/borrador/anulada, acciones en ⋮. Sin cambios API. `dart analyze` 0 errores.
- **2026-08-03:** **UI Menú admin** — `menu_admin_screen`: canvas/tokens, búsqueda + chips (sin receta / bajo margen / no disponible), badges de riesgo (receta/cocina/margen), tabs Productos/Toppings/Bebidas/Combos, estados vacíos claros. Sin cambios API. `dart analyze` 0 errores.
- **2026-08-03:** **UI Costos y márgenes** — `costos_margenes_screen` + bloques/receta/incluidos: tokens Analítica, banners sin receta/bajo margen, tabs «Receta / Incluidos», guía de pasos en editor, Guardar primero + agregar secundario, lista densas responsive. Sin cambios API. `dart analyze` costeo: 0 issues.
- **2026-08-03:** **Wompi móvil seguro** — redirect HTTPS `GET /pagos/retorno-app` → `foody://plan` (Android intent + iOS scheme) con fallback web; al aprobar pago Realtime `suscripcion_actualizada`; panel/Mejorar plan refrescan perfil en resume + deep link (sin reiniciar app). `WOMPI_REDIRECT_URL` = bridge API; `WOMPI_EQUIPO_URL` = fallback.
- **2026-08-03:** **UI Insumos** — `inventario_admin_screen` + `stock_visual_widgets` + guía pasos: tokens Analítica, banner/alertas de riesgo (rojo/ámbar/verde), chips/tabs densos, tarjetas responsive (<520 stack), FAB compacto, movimientos/subrecetas/conteo alineados. Sin cambios API/lógica. `dart analyze` archivos tocados: 0 issues.
- **2026-08-03:** **Wompi pago prueba** — sandbox APPROVED activó `nitidoooo` → plan `pro` / `activa` hasta 2026-09-02 (pago `ee6cf4cf…`). UI mostraba Gratis porque `MejorarPlanScreen` usaba `widget.planActual` (sesión). Fix: `_planVista` desde API + `onPlanActualizado` si el plan subió. Webhook puede fallar por firma (`WOMPI_EVENT_KEY` ≠ Eventos del dashboard); sync/poll igualmente aprueba.
- **2026-08-03:** **UI Reportes** — alineado a Analítica (tokens/KPI/surfaces/charts/skeletons); lógica y API intactas. `dart analyze lib/features/reportes` 0 errores.
- **2026-08-03:** **UI Centro de Inteligencia** — rediseño visual completo de Analítica sin tocar repo/API/cálculos: header hero, KPI premium+sparklines, strip insights, skeletons shimmer, charts con tooltips/gradientes, filtros sheet, jerarquía Resumen. `dart analyze lib/features/analitica` 0 errores.
- **2026-08-03:** **Fase 0 VPS (PC+túnel)** — `DB_POOL_MAX=25`; Wompi redirect canónico + `verificar-wompi-tunel.ps1`; UptimeRobot exacto en `MONITOREO_SALUD.md`; backup Windows (`programar-backup-windows.ps1`); `verificar-listo-vps.ps1` OK; `PREPARACION_VPS.md` Fase 0/1; `setup-ubuntu-vps.sh` endurecido. Verificado: `/salud` público, backup 5.8MB, preflight exit 0.
- **2026-08-03:** **Arranque tunel endurecido** — `servir-web-tunel-release.ps1` verifica que **equipo :8080 y cliente :8081** escuchen (falla si no); sin depender de `Get-NetTCPConnection`. `iniciar-foody-subdominios.bat` usa `-SkipBuild` por defecto + chequeo API. Verificado: ambos puertos + URLs públicas 200.
- **2026-08-03:** **Config centralizada** — `config/foody-entorno.env` + `sincronizar-entorno.ps1` + `verificar-entorno.ps1`. CORS canónico (sin acumular puertos basura). Verificado: sync, round-trip puerto, modo local↔túnel, `/salud` local+público, orígenes foodyy/equipo 200.
- **2026-08-03:** **Cloudflare Tunnel** — diagnóstico: dominios/puertos fijos (no rotan); fallos = Flutter `:8080` apagado o `usarTunel=false`. `_escribir-configuracion-tunel` quirúrgico; `sincronizar-ip-movil` ya no borra hosts foodyy; `verificar-tunel-foodyy.ps1` + `iniciar-foody-foodyy-store.bat` + `iniciar-flutter-web-tunel.ps1`; doc `CLOUDFLARE_TUNNEL_FOODY.md`. Verificado: api.foodyy.store `/salud` OK; foodyy.store falla sin Flutter en `:8080`.
- **2026-08-01:** **OPT-04/05** — `cerrados-hoy` e inventario movimientos con `page`/`limit`; kanban e inventario «Cargar más»; auditoría timeline `LIMIT 500`; `PollRealtimeRespaldo` 90s/45s; KDS + domi independiente. `verificar-paginacion-ops.ps1` OK; analyze archivos tocados sin errores.
- **2026-08-01:** **OPS lote 1** — `backup-postgres.sh` + retención en `.ps1`; `docs/BACKUPS_FOODY.md`; migr. `078` FCM `intentos`/`abandonada` (máx 10); limpieza estados expirados (cron 6h + `POST /promociones/admin/limpiar-expiradas` + delete Storage al eliminar); `.env.example` `DB_POOL_MAX`/`FCM_MAX_INTENTOS`. Verificado: `verificar-ops-recomendaciones.ps1` **OK**.
- **2026-08-01:** **Recomendaciones → backlog** — `docs/RECOMENDACIONES_IMPLEMENTACION.md`: auditado lo recomendado (UX suscripción/ciudad/estados, pool, caché, índices ✅; backups auto, VPS, FCM tope, limpieza Storage, Wompi prod ⏳). Specs de implementación + orden. MASTER/README/AUDITORIA enlazados.
- **2026-08-01:** **Estados estilo WhatsApp** — Ciudad: un anillo por restaurante (`listarGruposStoriesCiudad`); al abrir, todos los estados del grupo. Menú sede: un anillo. Video ≤30s (`tipo_media`, migr. `077`, `POST /almacenamiento/video`, `video_player`). Admin: Foto | Video. Smoke: `valledupar` → 1 grupo / 2 promos; `/salud` OK; analyze promociones 0 errores.
- **2026-08-01:** **Toppings extras / bebidas producto** — Admin: diálogo checkboxes «Toppings del plato» (`GET/PUT /productos/:id/toppings`). Sheet: toppings como extras del ítem + bebidas como líneas producto. Migr. `076` elimina productos espejo de toppings. Bebidas siguen espejadas al crear.
- **2026-08-01:** **Extras/bebidas = productos** — Migr. `075` (`topping_origen_id`/`bebida_origen_id`); `CatalogoService` espeja al crear/actualizar; sheet producto/combo y POS cajero agregan líneas de producto (sin `pedido_item_toppings` en ese flujo). Cliente ve categorías Extras/Bebidas + cards al pedir un plato.
- **2026-07-31:** **Upsell menú (opción 1)** — `OpcionUpsellCard` / `SeccionUpsellOpciones` en detalle producto y combo; observaciones debajo; tip admin tab Bebidas; vacío chip Bebidas; migr. `074` relink toppings/bebidas a Rosquete/Papas/Huevo. Sin unificar catálogo extras→pedido.
- **2026-07-31:** **Stories polish + borrar estados** — Fix GoError CTA (`appNavigatorKey`); botón oval transparente + degradado inferior; `BoxFit.contain`; anillo gris visto (`PromocionVistosService`); `DELETE /promociones/:id` + menú Eliminar en admin. `flutter analyze` promociones: 0 issues; API rebuild + `/salud` OK.
- **2026-07-31:** **Cliente premium + estados WhatsApp** — AppBar contraste lugares; cards portada+logo; stories sin overflow + auto-avance/tap; CTA «Ir al producto»/`Ver menú`; nav sede única con `pushReplacement` (sin loop); menú deep-link `producto_id`; chips pastel. Backend: migr. `073` `producto_id` + default 24h; `GET/PATCH /sucursales/marca`; admin estados + marca. Migración aplicada en supabase-db · `nest build` OK.
- **2026-07-31:** **Cliente UX oleada A (CL-01…08)** — sin Acceso staff / AppBar duplicada; Agotado en menú; subtotal carrito con extras; sticky «Ver carrito»; `PedidoEstadoPill` mis-pedidos/seguimiento; stories CTA «Ver menú» + copy sin admin; `FoodyEstadoUi` restaurantes/seguimiento/mesa QR; checkout errores inline. Doc `FRONTEND_AUDITORIA_UX_CLIENTE.md`. `flutter analyze` archivos tocados: 0 errores (1 info previo async context).
- **2026-07-31:** **Auditoría UX cliente (solo doc)** — `docs/frontend/FRONTEND_AUDITORIA_UX_CLIENTE.md`: splash→seguimiento, promos/stories, QR/mesa; gap vs admin (`OperacionUi`, pills, breakpoints); backlog CL-01…23 (P0/P1/P2). Índice README frontend + ROADMAP. Sin tocar código.
- **2026-07-31:** **Pedidos Fase 1 — verify-docs** — confirmado en código: columnas por canal, cards/pills, `pedido_detalle_sheet`, POS domicilio real, `items_resumen`, tab Cerrados hoy; `verificar-pedidos-kanban.ps1` **OK** (activos+detalle+cerrados-hoy+aprobar); `flutter analyze` pedidos/kanban: 0 errores (6 infos `use_build_context_synchronously` previos). Plan Fase 2 (edición ítem) ya entregado aparte.
- **2026-07-31:** **Coherencia BI↔pedidos** — ranking/margen de analítica, reportes, dashboard y costeo usan `SQL_VENTA_LINEA_ITEM` (base + toppings×qty + bebidas), igual que cobro; cuenta mesa `subtotal_linea` alineado; filtros Analítica con `pendiente_aprobacion`/`confirmado`/`rechazado`; KPI activos dashboard +`pagando`/`asignado`. Script `verificar-coherencia-pedidos-analitica.ps1` OK (KPI ventas_netas ≈ reportes financiero).
- **2026-07-31:** **POS coherencia pedidos** — categoría Bebidas con producto vendible (migr. `072` + API); admin combo puede incluir productos+bebidas+toppings; POS abre `DetalleComboSheet` con extras de componentes; combos aceptan toppings/bebidas extra en DTO; **cambiar producto** = agregar primero → quitar viejo (también último ítem); DELETE ítem limpia FKs hijas (fix 500); sticky POS se limpia al volver a Pedidos. `verificar-pos-menu-cambiar.ps1` OK · `verificar-pedido-items.ps1` OK · `nest build` OK · analyze Flutter sin errores (infos previos).
- **2026-07-30:** **Pedidos Fase 2** — `PATCH /pedidos/:id/items/:itemId` (cantidad/toppings/nota, stock/totales, reset cocina + Copia N); `items_resumen` con `producto_id`/`topping_ids`; DELETE reimprime comanda; sheet `editar_pedido_item_sheet` + menú Editar/Cambiar/Quitar en detalle. `verificar-pedido-items.ps1` · `nest build` · analyze OK.
- **2026-07-30:** **Pedidos CTA + mesero + comanda** — `PATCH /pedidos/:id/aprobar` con `mesera_id` (admin obligatorio); `GET /usuarios/meseros-activos`; modal `asignar_mesero_sheet`; labels Confirmar/Listo/A cobrar/En camino; FCM `pedido_asignado_mesero` + `pedido_a_cobrar`; migr. `071` `comanda_copia` + pie ticket `Copia N`. `verificar-pedidos-kanban.ps1` OK · `nest build` OK · analyze Flutter OK.
- **2026-07-30:** **Pedidos UX (recomendado)** — vista default = pestañas de estado + grid responsive (kanban columnas solo toggle ≥720); card: cliente/mesa negrita → hora → `#pedido` secundario; `POST /domiciliarios-planta/reasignar` (pedido `asignado`/`en_camino`) + UI «Cambiar» en detalle; tab Cerrados. `verificar-pedidos-kanban.ps1` OK · `nest build` OK · analyze Flutter OK.
- **2026-07-30:** **UI Pedidos Fase 1** — columnas por canal (`pedido_columnas_por_canal`); cards ricas + pills; `pedido_detalle_sheet`; `GET /pedidos/cerrados-hoy` + `/:id/detalle` + `items_resumen` en listado; POS domicilio nombre/tel/dirección (sin mapa); propina en cobro llevar; `verificar-pedidos-kanban.ps1` OK. `nest build` OK · analyze Flutter OK.
- **2026-07-30:** **UI Analítica premium** — `GET /analitica/pedidos-recientes`; widgets KPI/chart/pill/tabla; Resumen hero; charts en Ventas (`por_categoria`)/Productos/Cocinas/Riesgo/Caja; polish Inventario/Domi/Sedes; `FoodyBreakpoints` grids. `nest build` OK · `verificar-analitica.ps1` OK · `dart analyze lib/features/analitica` sin errores.
- **2026-07-30:** **Cierre parciales MASTER** — POS: propina en para_llevar + diálogo CxC tras pago «Pendiente»; docs: menú/reportes/super/analítica/panel/multi promovidos a ✅; §20 producción actualizado (CI/RLS ya hechos).
- **2026-07-30:** **UX/responsive caja·POS** — `lib/core/layout/foody_breakpoints.dart`; split operación 900→720; sheet cobro mesa densificado (banner 1 línea, split/salio en avanzadas, ChoiceChips diálogo &lt;600); mesas grid 4@720 / 5@1100; doc RS-20 ✅.
- **2026-07-30:** **Analítica Fase 3** — `alertas_abiertas_lista` en resumen; riesgo `cocinas_prep_delta` + `categorias_caida` (con `comparar`); cron `cocina_prep_subida` / `caida_ventas_categoria`; UI Resumen→Riesgo. Sin xlsx nativo ni MV (YAGNI). `verificar-analitica.ps1` ampliado.
- **2026-07-30:** **Analítica Fase 2** — `GET /analitica/export` CSV UTF-8 BOM (Excel); `formato=xlsx` → mismo CSV; `adjuntarComparativaKpis` en ventas/productos/cocinas/inventario/domi/caja/riesgo; Flutter comparar en tabs + banner + rango custom + export CSV; `verificar-analitica.ps1` export+comparativa. `nest build` OK · `dart analyze lib/features/analitica` OK.
- **2026-07-29:** **Analítica Fase 1** — DTO/filtros SQL (`analitica-filtros.util`); UI sheet + charts + PDF (`analitica_filtros_sheet`, `analitica_export_foody`); duración historial; migr. `070`; distancia en asignaciones; alertas producto sin venta / mesero cancelación; script verificar multi-filtro. `dart analyze` OK · `nest build` OK. API viva no disponible en sesión (Supabase containers down; `foody_db` vacío).
- **2026-07-29:** **Plan Analítica/Reportes** — inventario Fase 0 + plan de extensión en `docs/PLAN_COMPLETAR_ANALITICA_REPORTES.md` (decisiones 1A·2A+B+C+D·3C·4C). Índice `docs/README.md` + ficha MASTER §21.
- **2026-07-26:** **NAV-DP** — FCM planta ≠ indep; redirect `/admin/panel`→domiciliario; cobro un sheet; sin mini-mapa; `DraggableScrollableSheet`; split ≥720; AppBar «Mi ruta»; `saldo_por_liquidar` + banner; copiar tel/dir web; snackbar asignación; tabs compactas; login hint. Doc `FRONTEND_AUDITORIA_NAV_DOMICILIARIO.md`. Analyze OK · `nest build` OK.
- **2026-07-26:** **F0 QA** — `verificar-flutter-ui` OK; FlujoApi **12/12**; RolesApi **38/38**; sesión `docs/archivo/qa-sesiones/2026-07-26.md`. UI manual click-through pendiente. Ajuste menor acciones Mesas (sin `SizedBox` fijo con Wrap).
- **2026-07-26:** **NAV-ADM2** — `pedido_id`/`ingrediente_id` en router+panel; alertas→pedido/insumo/costos; kanban lista &lt;720; `ocultarCabecera` operación; dismiss suscripción; KDS/POS/caja atajos; Reportes↔Analítica; CTAs cocinas/domi/promos/sucursales/usuarios; chips filtro estado; búsqueda max 720; banner mesas dismissible. Doc `FRONTEND_AUDITORIA_NAV_ADMIN2.md` (22/24; ADM2-06/24 diferidos). Analyze: solo infos previos.
- **2026-07-26:** **NAV-MS Mesero** — shell: refresh, nav≥720, `ocultarCabecera`; banner QR→Mesas; `onVerMesa`; lista móvil (kanban ≥720); CTA «Listo para cobrar» + cobro avanzado; sin cancelar/salió-sin-pagar; redirect panel→mesero; FCM `/admin/mesero?mesa_id&pedido_id`. Doc `FRONTEND_AUDITORIA_NAV_MESERO.md`.
- **2026-07-26:** **NAV-CK Cocina (KDS)** — Menú/Insumos/Costos N/A (`ver_cocina` solo). Timer `cocina_desde` (MIN ítem); cap 99+; rol cocina filtra estación + redirect `/admin/panel`→`/admin/cocina`; empty/error adaptativos; refresh sin full-spinner; icon CTAs móvil; badge Cobrado; estación en AppBar. Doc `FRONTEND_AUDITORIA_NAV_COCINA.md`.
- **2026-07-26:** **NAV-CJ Cajero** — headers únicos; sync caja→POS; auto tab Caja si bloqueado; filtro Por cobrar; sin QR/transfer/arqueo ciego; nav superior ≥720. Doc `FRONTEND_AUDITORIA_NAV_CAJERO.md`.
- **2026-07-26:** **Rol Cocina** — migr. `069_usuarios_cocina_id.sql` (`usuarios.cocina_id`); crear/editar staff con rol `cocina` + estación; JWT/`perfil` con `cocina_id`; KDS `/cocina/cocinas` filtra a su estación; tickets/ítems ajenos → 403. UI Usuarios: «Cocina (KDS)» + selector. Demo `cocina@foody.demo` → `cocina` + principal. Script `verificar-rol-cocina.ps1` OK.
- **2026-07-26:** **NAV-MG ✅** — nombre sede en sidebar (`ver_dashboard` → `mi-restaurante`); empty Menú sin copiar HQ; Costos→Insumos; CTA hermanas; copy Traslados; hermanas→Traslados; GuiaPasos Menú/Costos; docs `gerente` vs `gerente_cadena`. MG-08 YAGNI.
- **2026-07-26:** **NAV-MC Baja ✅ / ciclo cerrado** — `_barraCrear` tonal en toppings/bebidas/combos; Movimientos tap → Mercado+editar; Recalcular icono/label alineado; `inventario`→`insumos`. Doc auditoría 28/28.
- **2026-07-26:** **NAV-MC Alta+Media** — `_irCostosConProducto` + `?producto_id`; Costos sin auto-abrir primer plato; selector sede móvil; diálogo precios con costo/margen; Insumos→Costos (CTA + SnackBar); fade TabBars; empty/error Menú; badges extras; alerta→filtro bajo_stock. Doc `FRONTEND_AUDITORIA_NAV_MENU_COSTEO.md`. Analyze OK.
- **2026-07-26:** **Overflow móvil (~360–390px)** — trailing densos → precio en subtitle + Switch/⋮ (menú cliente/admin, promo, caja fiados, cocinas, usuarios, mesa sheet); grids POS/mesas 2 cols &lt;400px; FAB padding promo/sucursales/seguimiento; TabBar `isScrollable` costeo/popularidad/facturación/domi; `FoodyScrollHorizontalFade` en chips; KDS badges en `Wrap`. `flutter analyze` archivos tocados: solo infos previos.
- **2026-07-23:** **Recetas bebidas/toppings** — migr. `068_receta_bebidas_toppings.sql`; `configurarReceta`/`resumen`/`recalcular` con `tipo_entidad`; pedidos expanden extras al validar/descontar stock; Costos lista platos+bebidas+toppings; Menú atajo «Ver costos» en extras; `scripts/verificar-receta-extras.ps1` **8/8 OK**.
- **2026-07-22:** **Costos scroll único** — detalle plato = un `ListView` (sin Flexible+Expanded TabBarView → adiós bloque blanco); cabecera compacta/colapsable; stock e incluidos colapsables; paneles receta/incluidos con `scrollExterno`. Insumos: subtítulo más corto.
- **2026-07-22:** **Formularios Foody** — shell `lib/core/tema/foody_formulario.dart` (cards, métricas, campos adaptativos). Rediseño responsive: subreceta (fix overflow), insumo, compra/ajuste/producción/conteo, menú (producto/precios/combo/extras/categoría). Colores Foody, no tema externo.
- **2026-07-22:** **NAV-MC Alta 04–07** ✅ — crear insumo/empaque desde Costos; guía Orden recomendado colapsable; Subrecetas ⋮; badge Menú→Costos. Archivos: `receta_producto_panel`, `dialogo_insumo_form`, `costeo_ui_bloques`, `inventario_admin_screen`, `menu_admin_screen`.
- **2026-07-22:** **NAV-MC-01…03** ✅ — Costos móvil: editor receta `ListView` único (adiós overflow 96 px); back único contextual + breadcrumb solo PC (sin link duplicado); acciones header en ⋮ móvil + título `maxLines:1`. Archivos: `receta_producto_panel.dart`, `costos_margenes_screen.dart`. Nueva auditoría vivo `FRONTEND_AUDITORIA_NAV_MENU_COSTEO.md` (cadena insumos→subrecetas→menú, 19 ítems NAV-MC).
- **2026-07-22:** **NAV-ADM Baja** ✅ — breadcrumb/volver Costos↔Menú; empty+CTA zonas/sucursales; preview horarios; dialogs maxWidth 560; Mejorar plan solo banner (+ módulo bloqueado).
- **2026-07-22:** **NAV-ADM Media** ✅ (salvo 14/24) — AppBar móvil ⋮; búsqueda→pedido; KPIs mesas/reportes/pedidos; kanban default+ancho flex+Nuevo; caja movimiento→pedido; copy sidebar; factura Ver pedido+preview; alertas SnackBar+Wrap. Archivos: `panel_restaurante_screen`, `pedidos_kanban_widget`, `caja_admin_screen`, `facturacion_admin_screen`, `alertas_admin_screen`, dashboards, `menu_admin_item`.
- **2026-07-22:** **NAV-ADM Alta 01–06** ✅ — favoritos ★, sheet pedidos atajos, ⋮ mesas, banner QR Revisar, menú overflow móvil, Modo caja + Cobrar todo con monto.
- **2026-07-22:** **NAV-ADM-03** ✅ — ⋮ opciones mesa en grid admin (`mesas_grid_widget`).
- **2026-07-22:** **NAV-ADM-02** ✅ — atajos sheet Pedidos (cobrar mesa, caja, factura+emitir, KDS).
- **2026-07-22:** **NAV-ADM-01** ✅ — favoritos sidebar: ★ en tiles, bloque en rail tablet, ★ en popup grupos (`panel_sidebar_nav.dart`); AR-29 ✅.
- **2026-07-22:** **Nav admin (diagnóstico)** — Documento vivo `FRONTEND_AUDITORIA_NAV_ADMIN.md` con 24 ítems NAV-ADM-01…24.
- **2026-07-02:** DOM-UI — dashboard independiente inDriver (`MapaFoody`, `TarjetaOfertaInDriver`, `PanelEntregaActiva`, countdown 60s, múltiples ofertas, desconectar turno); planta activos mapa + chip GPS; `GET /domiciliarios/sesion/estado`; `scripts/verificar-ofertas-independiente.ps1` E2E OK.
- **2026-07-02:** AR-28 búsqueda admin (pedido #, mesa, módulo); navegación alertas mesa/caja; menú AppBar blanco; ciudades sin slug; `FoodyAsyncBody`; `verificar-foody-loc.ps1`; QA roles API 37/37.
- **2026-07-02:** Sprint 1 frontend — FF-01…06, `FoodyFormato`/`FoodyEstadoUi`/`mensajeErrorCliente`, splash Foody, carrito +/−; `verificar-flutter-ui.ps1` OK.
- **2026-07-02:** Arquitectura Flutter — `FRONTEND_FLUTTER_ARCHITECTURE.md` (6 god files &gt;1000 LOC, 1 provider Riverpod, estrategia FL-10…63, Fase 9).
- **2026-07-02:** UI/QA — cancelar pedido ≤2min (`created_at` API + seguimiento); banner cuenta unificada mesa QR + `total_pendiente_mesa`; scope mesa sin mis-pedidos/salir; cajero bloqueo tabs; mesero banner QR en tab Pedidos; repartidor chip GPS; `verificar-flutter-ui.ps1`; `docs/FACTURACION_ELECTRONICA_PAUSADA.md`; checklist actualizado.
- **2026-07-02:** Auditoría UI — `AbrirAppCliente` (flavor equipo → URL cliente); delete cocina/impresora; recalcular subreceta + historial producciones; doc `docs/archivo/auditorias-prompts/AUDITORIA_PANTALLAS_BOTONES.md`.
- **2026-07-02:** `verificar-qa-roles-api.ps1` (37 pasos API por rol); `Ensure-HorariosDemoAbiertos` + `Ensure-AsignacionDomiPlanta` en qa-helpers.
- **2026-07-01:** RT-QA UI — `scripts/verificar-realtime-qa-manual.ps1` (guia 2 pestanas + modo `-Asistido`); integrado en `verificar-qa-manual.ps1 -Realtime`.
- **2026-07-01:** RT-8b — dedup `event_id` en Flutter (`evento_dedup.dart`); `catalogo_disponibilidad` para toppings/bebidas; `scripts/verificar-realtime-api.ps1` (caja retiro, topping, desasign domi); QA detectó migración `055` faltante en BD local.
- **2026-07-01:** CAJ-021b — **fix doble resta al cancelar** (`revertirVentasPedido` borraba la venta **y** agregaba devolución, dejando la caja en −monto): ahora conserva la venta y registra una única devolución por el neto cobrado (`netoCobradoPedidoEnCaja`), así cancelar un para-llevar prepagado regresa la caja al saldo original. Fix SQL cierre caja: `pedidos.updated_at` → `created_at` (la columna no existe). Script cubre escenario para-llevar prepagado.
- **2026-07-01:** CAJ-021c — **ventas netas** (indicador «Ventas» ya no infla con pedidos cancelados): `total_ventas` de caja, `ventas_caja`/`por_metodo` en reportes y analítica ahora restan devoluciones (`SUM(venta) − SUM(devolucion)`), conservando ambos movimientos para auditoría. Chequeo de coherencia usa neto (`venta − devolucion ≤ total`). Meseras «Salió sin pagar» (`POST /mesas/:id/salio-sin-pagar` → CxC por saldo impago, pedido `pagado` solo por lo abonado, alerta `salio_sin_pagar`, libera mesa; sin venta en caja) verificado coherente.
- **2026-07-01:** QA manual — `verificar-flujo-cruzado-api.ps1` + `verificar-qa-manual.ps1 -FlujoApi` (12/12 checklist §4); sesion `docs/archivo/qa-sesiones/2026-07-01.md`; usuarios demo cajero/mesero documentados.
- **2026-07-01:** CAJ-020 — E2E `verificar-todos-e2e.ps1` **9/9 OK**; split ítem COALESCE; limpieza demo ampliada; reconciliar-cuadre-demo; fiado `-CicloCompleto`.
- **2026-07-01:** QA suite ampliada — inventario-menu, CxC, self-service, operación mesas, transferencia, multi-sucursal, receta-empaque, producción-lote OK; `verificar-carga-qr.ps1` reparado (ASCII, mesa demo, Start-Job); cuadre caja con diferencia histórica esperada (pedidos totales vs movimientos).
- **2026-07-01:** CAJ-019 — fixes auditoría pedidos/caja: `dto.pagos` respeta `debeRegistrarVentaAlCrear`; cancelar revierte ventas caja; descuento ajusta `monto_pagado` + devolución exceso; split ítem incluye toppings/bebidas y cap post-abono; tope idempotente `SUM(ventas)≤total`; API `mesera_nombre`/`monto_pagado`; abonos con `responsable_nombre`; filtro `mesera_id` en listado; Flutter: nota cocina, bloqueo sin caja, atribución mesa/kanban/KDS, cobrar para-llevar.
- **2026-07-01:** CAJ-018 — coherencia caja/pedidos: `debeRegistrarVentaAlCrear` excluye domicilio (caja solo al cobrar/entregar); para-llevar con método marca `monto_pagado=total`; domicilio→entregado vía Kanban registra saldo idempotente; `usuarioId` en todos los `registrarVentaEnCaja`; movimientos y fiados devuelven `responsable`; cobro mesa atribuye `pedido_id` correcto; UI caja muestra responsable+método; `scripts/reconciliar-caja-domicilios.ps1` + `scripts/verificar-caja-coherencia.ps1` (descuento OK con `factura_id`).
- **2026-07-01:** DOM-017 — contabilidad del domicilio: por defecto la caja registra **solo el producto** (`total − costo_domicilio`) y el domicilio queda fuera de caja, rastreado por domiciliario (`GET /domiciliarios-planta/domicilios/:sucursal_id`). Toggle `domicilio_ingresa_a_caja` por sucursal (`PATCH .../config-domicilio-caja/:sucursal_id`) para restaurantes que sí lo cobran. **Pago mixto** en la entrega (`metodo_pago_domicilio`: producto por transferencia, domicilio en efectivo). Desglose producto/domicilio en dashboard domiciliario. Aplica a planta e independiente y al fiado (el domi solo debe el producto). Migración `066`, util `repartirCobroDomicilio` + `scripts/verificar-cobro-domicilio.ps1`.
- **2026-07-01:** DOM-016 — fiado/liquidación de domiciliario de planta: método `pendiente_liquidacion` en entrega crea CxC ligada a `domiciliario_planta_id` (no toca caja); admin liquida a caja (efectivo) al recibir el dinero; toggle `permite_fiado_domiciliario` por sucursal. Migración `065`, `scripts/verificar-fiado-domiciliario.ps1`.
- **2026-07-01:** FCM producción dispatch — push planta al auto-asignar, staff si sin repartidor, independientes en oferta (`dispatch.service`, `pedidos-estado.service`).
- **2026-07-01:** PED-005 merma al cancelar pedido listo/en cocina (`pedidoRequiereMermaAlCancelar`, alerta `merma_cancelacion_pedido`).
- **2026-07-01:** PED-020 encargo — `fecha_entrega_deseada` DTO + date picker checkout (mín. 2 días) + validación `es_encargo`.
- **2026-07-01:** QR-012 — `qr_pendientes_count` en `mesas.service` + badge grid admin.
- **2026-07-01:** DOM-009 `GET /domiciliarios-planta/comisiones-independientes/:sucursal_id` + tarjeta payout admin.
- **2026-07-01:** DOM-002 RT — `domiciliarios_admin_screen` + `FoodyRealtime.suscribirSucursal`.
- **2026-07-01:** X-005 `scripts/verificar-carga-qr.ps1` (20 POST paralelos). X-001 cron suscripciones verificado ✅.
- **2026-07-01:** Escenarios negocio — 122 ✅ · 8 🟡 · 1 ❌ (restantes: DIAN PED-011/012, QR-011, FAC-003; impresión COC-008, X-009).
- **2026-07-01:** UX escenarios — timer QR grid (MES-012), tracking mapa domicilio RT (DOM-007), preview borrador FAC-001.
- **2026-07-01:** **F-17** — split bill: `ITEMS_EXCEDEN_SALDO`, FIFO abono, `verificar-pagos-mesa.ps1`; UX sheet mesa + banner QR MES-018.
- **2026-07-01:** P3-09 — auditoría docs: MASTER, MODULOS, AVANCE resumen, README, ROADMAP; tablas sprint históricas = referencia.
- **2026-07-01:** P3-06 parcial — `Dockerfile` bookworm-slim + `verificar-docker-prod.ps1` (build OK).
- **2026-07-01:** `docs/ESTRATEGIA_BACKEND_PRIMERO.md` — frontend pausado; prioridad API/BD/infra.
- **2026-07-01:** P3-04 — eliminados `pedido_service.dart`, `menu_catalog_service.dart`, `lib/providers/` (11 archivos), utils reserva legacy.
- **2026-07-01:** Fix `verificar-multi-sucursal.ps1` (em-dash rompía PowerShell en Windows).
- **2026-07-01:** Verificado `verificar-ci.ps1` 3/3 OK tras limpieza; `flutter analyze` sin errores en features/core.
- **2026-07-01:** P3-01 — `verificar-ci.ps1`, GitHub Actions, `docs/CI_E2E.md`. Verificado: `verificar-ci.ps1` 3/3 OK.
- **2026-07-01:** P2-19 `POST /inventario/traslados/:id/cancelar` + UI cancelar/recibir + `usuario_nombre` en listado.
- **2026-07-01:** P2-20 snackbar éxito en `_VistaConfig` panel super-admin.
- **2026-07-01:** P2-21/22 `ESCENARIOS_NEGOCIO_FOODY.md` — 82 ✅ · 47 🟡 · 1 ❌ (COC-015).
- **2026-07-01:** `scripts/iniciar-backend-wsl.bat` deja de arrancar NestJS en WSL (crash silencioso de `sharp` con `node_modules` de Windows). Ahora compila y ejecuta con Node en Windows; comprueba Docker y si la API ya responde.
- **2026-06-28:** P2-17 editar rol/permisos staff UI.

> **Checklist maestro para terminar el software:** **`docs/ROADMAP_TERMINAR_FOODY.md`** (P0→P3, 52 ítems accionables).

> **Registro irregularidades (checklist vivo):** `docs/REGISTRO_IRREGULARIDADES_FLUJOS.md` — **32/33 resueltos** (solo **R5** impresión física pendiente).
> **Auditoría E2E (histórico + trazado):** `docs/archivo/auditorias-prompts/AUDITORIA_FLUJOS_E2E.md` — estado vivo en REGISTRO + `MASTER_STATUS.md`.
> **Antigravity (archivado 2026-06-24):** `docs/archivo/*-antigravity.md` — fixes ya en código.
> **Auditoría arquitectura:** `docs/archivo/auditorias-prompts/AUDITORIA_ARQUITECTURA_CALIDAD.md` (Prompt 01, AQ-\*) · histórica jun-12: `docs/archivo/auditorias-prompts/AUDITORIA_ARQUITECTONICA_FOODY.md` · analista jun-04: `docs/archivo/ANALISIS_SISTEMA.md`.
> **Flujos por rol (HTML):** `INFRAESTRUCTURA/foody_flujo_completo_pantallas.html` · mapa código `docs/MAPA_FLUJOS_PANTALLAS.md`.
> **Planes comerciales (básico/pro/enterprise):** 🟡 módulos + **límites numéricos** (sucursales/usuarios) — ver `docs/PLANES_SUSCRIPCION.md`.

---

## Resumen de 1 minuto (léelo primero)

> **Frontend en pausa.** Estado vivo: **`MASTER_STATUS.md`**. Prioridad: **`ESTRATEGIA_BACKEND_PRIMERO.md`**.

| Qué | Estado |
|-----|--------|
| **Backend NestJS** | ✅ 27 módulos · ~221 endpoints · guards + multi-sucursal |
| **PostgreSQL** | ✅ Migr. **001–064** · RLS exhaustivo (073 tablas) |
| **CI / QA API** | ✅ `verificar-ci.ps1` **5/5** (paso0 + rls + salud + P2 + multi-sucursal) |
| **Realtime broadcast** | ✅ Health `/health/realtime` · poll respaldo en cliente |
| **Impresión cocina** | 🟡 Cola + agente · modo archivo OK · falta hardware (P0-01) |
| **Wompi / suscripciones** | 🟡 Código F1–F7 + recurrente · falta webhook HTTPS prod |
| **Docker prod** | 🟡 `verificar-docker-prod.ps1` build OK · deploy VPS pendiente |
| **Legacy Flutter** | ✅ `lib/screens/` eliminado · paquete `reserva_canchas` sin renombrar |
| **Cliente / admin UI** | ✅ En código · **no se toca** hasta retomar frontend |

**Verificación rápida:** `.\scripts\verificar-ci.ps1`

> Detalle técnico (env, endpoints, changelog): secciones **Referencias persistentes** y **Últimos cambios** abajo.

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
| Legacy `menu_sede_screen` | ✅ | Eliminado P3-03 | — | — | — |
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
| Traslados stock entre sedes | ✅ Avanzado | Backend traslados + `POST .../cancelar` + scope; UI cancelar/recibir + `usuario_nombre` | — | Fase 2 |
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
| `lib/screens/`, Provider, Firebase pedidos | ✅ Eliminado P3-03/04 | Ver `lib/legacy/README.md` |
| ~~`pedido_service.dart`~~ | ✅ Eliminado | Usar `PedidosClienteRepository` |
| Paquete `reserva_canchas` | 🟡 | Renombrar en P3-05 |
| ~~`menu_sede_screen.dart`~~ | ✅ Eliminado | `MenuScreenFoody` |

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

## Auditoría Antigravity (2026-06-24)

Sesión externa de QA/arquitectura. Documentos fuente (conservar como referencia):

| Documento | Contenido |
|-----------|-----------|
| `docs/archivo/auditoria_flujos_foody-antigravity.md` | 9 flujos E2E, matriz R1–R13 (archivado) |
| `docs/archivo/implementation_plan-antigravity.md` | Plan freemium + tickets (archivado) |
| `docs/archivo/walkthrough-antigravity.md` | Resumen sesión Antigravity (archivado) |
| `docs/archivo/inventario_sistema_foody-antigravity.md` | Snapshot código jun-24 (archivado) |

### Implementado en código (post-Antigravity)

| Ítem | Archivos | Estado |
|------|----------|--------|
| **Plan gratis freemium** — inventario, costeo, cocina, domi, reportes desde `gratis` (solo facturación = enterprise) | `plan-features.config.ts`, `plan_modulos.dart` | ✅ |
| **Límites numéricos plan gratis** — 1 sucursal, **2 staff**, **2 mesas**, **5 productos**, **5 ingredientes** | `plan-features.config.ts`, `PlanFeaturesService.assertLimite*` | ✅ |
| Validación al crear mesa / producto / ingrediente → `403 PLAN_LIMITE_EXCEDIDO` | `mesas.service.ts`, `catalogo.service.ts`, `inventario.service.ts` | ✅ |
| **R1** — No `entregado` en mesa con saldo pendiente | `pedidos-estado.service.ts` (`PAGO_REQUERIDO_PARA_LIBERAR_MESA`) | ✅ |
| **R4** — Ajuste manual stock→0 propaga `productos.disponible` (CTE recursivo subrecetas) | `catalogo-disponibilidad.service.ts` | ✅ |
| **R10** — `FOR UPDATE` stock/mesa en creación QR | `pedidos-crear.service.ts`, `pedidos-inventario.service.ts` | ✅ |
| **R3** — Domicilio: `entregado` solo desde `en_camino` | `pedido-estados.ts` (`transicionEstadoPermitida`) | ✅ Antigravity |
| **R6** — Transferencia mesa con `auditoria_logs` | `mesas.service.ts` | ✅ Antigravity |
| **R7** — `FOR UPDATE` mesas origen+destino en transferir | `mesas.service.ts` | ✅ Antigravity + liberar origen |
| **R8** — Auto-asignar planta libre al pasar a `listo` | `dispatch.service.ts` | ✅ 2026-06-24 |
| **R11** — KDS desmarca ítem → pedido `en_cocina` (no `confirmado`) | `cocinas.service.ts` | ✅ Antigravity |
| **R13** — Hard stop cierre caja con pedidos/mesas activas | `caja.service.ts` (`CAJA_CIERRE_OPERACION_ABIERTA`) | ✅ 2026-06-24 |
| Fix JWT plan obsoleto tras upgrade Wompi | `plan-features.guard.ts`, `auth.service.perfil` + token | ✅ |

### Riesgos detectados — aún pendientes

| ID | Riesgo | Prioridad | Cuándo |
|----|--------|-----------|--------|
| R2 | `estado_operativo` mesa puede desincronizarse en casos borde | P1 | Sprint mesas |
| R10 (parcial) | QR simultáneo en mesas distintas: stock valida al aprobar, no al crear `pendiente_aprobacion` | P2 | Sprint pedidos |

---

## Últimos cambios (changelog)

- **2026-06-28:** **P2-17** — Staff: `GET /usuarios/catalogo-roles`, `PATCH /usuarios/:id` (nombre, rol, sucursal; sync `domiciliarios_planta`); diálogo **Editar** en `UsuariosAdminScreen` con chips de permisos read-only por rol; `verificar-usuarios-editar.ps1` OK.
- **2026-06-28:** **P2-16** — Reportes admin: export PDF (informe completo) y CSV/Excel vía `ReporteExportFoody` + menú descarga en `ReportesAdminScreen`; `verificar-reportes-export.ps1` OK.
- **2026-06-28:** **P2-15** — Dashboard admin: gráficos ventas 7d, mix canal hoy y top productos; `GET /dashboard/graficos`; `DashboardGraficosWidget`; `verificar-dashboard-graficos.ps1` OK.
- **2026-06-28:** **P2-14** — Editor receta: grupo empaques domicilio, desglose mesa vs llevar, botones rápidos por tipo, margen error % al guardar, badge empaque; `GET producto-ingredientes` incluye `costo_domicilio`; seed 033 con categoría empaque; `verificar-receta-empaque.ps1` OK.
- **2026-06-28:** **P2-13** — Simulador popularidad: ventas por canal mesa vs domicilio/llevar, clasificación ABC y matriz menú; `GET /costeo/popularidad/:sucursal_id`; icono insights en Costos; `verificar-popularidad.ps1` OK.
- **2026-06-28:** **P2-12** — Producción en lote: migr. `063_producciones_lote`, `POST/GET /costeo/producciones`, ingrediente preparado (`es_subreceta`), descuento insumos + stock lote, costo real; toggle en diálogo subreceta + botón registrar; `verificar-produccion-lote.ps1` OK.
- **2026-06-28:** **P2-10/11** — CxC: resumen API, alertas +7d, historial, cobro con método de pago; UI caja admin; `verificar-cxc.ps1`. Costos: precio sugerido canal llevar en `resumenSucursal` + panel detalle Flutter.
- **2026-06-28:** **P2-04** — Banner cuenta unificada vs tickets en `MesaPedidosSheet`; API `cuenta` en pedidos mesa; «Cobrar este ticket» + ayuda.
- **2026-06-28:** **P2-06/07/09** — `POST /pedidos/:id/llamar-mesera` + FCM; propina opcional checkout; cobro parcial mesa/caja → estado `pagando` + realtime. Backend reiniciado y `verificar-analitica.ps1` OK.
- **2026-06-24:** **P2 pulido** — PDF/compartir QR mesa; banner QR mesero; `POST /pedidos/:id/cancelar` + UI seguimiento cliente.
- **2026-06-24:** **P1-08 analítica QA** — `GET /analitica/comparativa-sedes`; tab «Sedes» corporativo; migr. `062`; `verificar-analitica.ps1`.
- **2026-06-24:** **P1-07 analítica tier Pro** — `ModuloPlan.analitica` en `plan-features.config.ts`; `@RequiereModulo('analitica')`; candado sidebar Flutter (`plan_modulos.dart`).
- **2026-06-24:** **P1-06 Flutter analítica** — `AnaliticaScreen` (8 tabs, presets, fl_chart); menú «Centro de Análisis» en panel Finanzas.
- **2026-06-24:** **P1-05 analítica F3** — `/inventario`, `/domiciliarios`, `/caja`, `/riesgo` (consumo, ranking domi, cuadre, alertas y umbrales).
- **2026-06-24:** **P1-04 analítica F2** — `GET /analitica/ventas`, `/productos`, `/cocinas` (series, rankings, cocinas con margen y tiempo prep).
- **2026-06-24:** **P1-03 analítica F1** — `AnaliticaModule` + `GET /analitica/resumen` (KPIs, presets, comparativa Δ%); migr. `061` `ver_analitica`; scope sucursal corporativo.
- **2026-06-24:** **P1-02 rol `gerente_cadena`** — Migración `060` (permisos = admin); `roles-food.ts` + `esCorporativo()`; checkout/renovar y avisos suscripción; crear usuario solo corporativo; `roles_foody.dart` en panel/usuarios/inventario.
- **2026-06-24:** **P1-01 dashboard consolidado** — `GET /dashboard/consolidado` (corporativo); KPIs cadena + desglose por sucursal; `DashboardConsolidadoWidget`.
- **2026-06-24:** **P1-15 FCM alertas riesgo** — Push nivel alto/crítico a admin/gerente; `TransactionHooksService` post-commit; deep link `/admin/panel?seccion=alertas`.
- **2026-06-24:** **P1-14 SuscripcionActivaGuard** — Auditoría controllers; `notificaciones` con guard; decorador `@OmitirSuscripcionActiva` en pagos/auth (checkout con plan vencido); código error `RESTAURANTE_BLOQUEADO`.
- **2026-06-24:** **P1-13 guard tenant `/super/*`** — `SuperAdminGuard` consulta BD: solo `super_admin` sin `restaurante_id` ni `sucursal_id`; errores `SUPER_ADMIN_REQUERIDO` / `SUPER_ADMIN_SIN_TENANT`.
- **2026-06-24:** **P1-12 documentos domiciliario** — `POST/GET /domiciliarios/documentos` (cedula frente/reverso, vehículo); registro devuelve JWT; `DomiciliarioDocumentosScreen`; Foody Control repartidores con preview y activación; FCM `domiciliario_cuenta_activa` / `domiciliario_documento_rechazado`.
- **2026-06-24:** **P1-10 cobro recurrente Wompi** — Tabla `fuentes_pago`; guarda `payment_source_id` tras pago; `POST /pagos/renovar` (cobro con fuente o checkout); cron renovación automática; UI renovación en `MejorarPlanScreen`.
- **2026-06-24:** **P1-09 paywall plan** — Interceptor `ClienteDio` (403 `PLAN_LIMITE_EXCEDIDO` / `PLAN_NO_INCLUYE_MODULO`); `PaywallLimitePlanDialog` → `/admin/mejorar-plan`; API expone `limite`/`actual` en filtro HTTP.
- **2026-06-24:** **P1-11 historial suscripción** — `GET /pagos/estado` devuelve `historial` (15 pagos); tarjeta estado + lista en `MejorarPlanScreen`.
- **2026-06-24:** **Impresión cocina sin hardware** — Modo `archivo`, reintentos cola, migr. `058`, `GET /health/impresion`, `GET /impresion/jobs`, ticket enriquecido, `docs/IMPRESION_RESTAURANTE.md`, `scripts/iniciar-impresora.ps1` + `verificar-impresion.ps1` (OK).
- **2026-06-24:** **`docs/ROADMAP_TERMINAR_FOODY.md`** — checklist maestro P0–P3 (52 ítems) para terminar el software punto por punto.
- **2026-06-24:** **QR cámara + FCM web deep link** — `EscanearQrMesaScreen` (`mobile_scanner` + entrada manual); ruta `/cliente/escanear-qr`; `RutaMesaUtil.tokenDesdeTextoQr`; `notificationclick` en `firebase-messaging-sw.js` + `fcm_click_web.dart`; retry navegación en `NavegadorFcmFoody`.
- **2026-06-24:** **Wompi prod-ready + F7 métricas** — Poll auto-activación plan tras pago; `sincronizar` sin TX si webhook aprobó; `metricasSelfService` en `GET /super/estadisticas`; KPIs en Foody Control; guía `docs/WOMPI_PRODUCCION.md`.
- **2026-06-24:** **GPS domiciliarios + seguimiento cliente** — `POST /domiciliario/ubicacion`; historial + Realtime; mapa cliente con repartidor; modal combo con imagen.
- **2026-06-24:** **Storage combos/categorías + R5 impresión** — endpoints imagen combo/categoría; admin menú gestión fotos; `foody_python_printer` con `python-escpos` (red :9100) + fallback archivo; jobs envían `impresora.ip_local`.
- **2026-06-24:** **Producto — brechas menú/promos/inventario** — Compra y cierre de conteo propagan disponibilidad al menú (`inventario.service.ts` + `CatalogoDisponibilidadService`); admin promos con `image_picker` → Storage (`POST /almacenamiento/promociones/:id/imagen`); `cached_network_image` en `menu_screen_foody.dart`; script `scripts/aplicar-migracion-supabase.ps1` (057 bucket).
- **2026-06-24:** **Optimización escalabilidad fase 1** — `056_indices_rendimiento.sql`; caché menú 5 min (`MenuCacheService` + invalidación catálogo); paginación opcional `GET /pedidos?page&limit`; `/salud` con `timestamp`; logs 500 en `HttpExceptionFilter`; `docker-compose.prod.yml` + `foody_backend/Dockerfile`; `DB_POOL_MAX`. Ver `docs/OPTIMIZACION_ESCALABILIDAD_FOODY.md`.
- **2026-06-24:** **OAuth Google web ✅** — `LaunchMode.platformDefault` (PKCE misma pestaña); mensajes `AuthException` legibles; limpia `?code=` tras retorno; backend `login-google` 401 con mensaje real. — `logout()` cierra JWT + Supabase + marcador OAuth; `cerrarSesionStaff` en todos los paneles (sin `/splash`); OAuth solo si hay marcador `foody_oauth_destino_staff` + `?code=` (evita re-login tras cerrar sesión); login no re-procesa sesión Supabase vieja; registro no re-ejecuta `loginGoogle` con token precargado; menú admin muestra error si falta `sucursalId` o falla crear categoría/producto.
- **2026-06-24:** **A-01…A-04 ✅ deuda transversal** — `PedidosInventarioService` vía DI; `CajaMovimientosService` única vía caja; `AuditoriaService.registrarEnTransaccion`; helpers `pedidoTerminalOperativo` + SQL fragmentos en `pedido-estados.ts`.
- **2026-06-24:** **R9 ✅ Realtime híbrido** — `PollRealtimeRespaldo` (30/60 s) en Kanban, mesas, sheet mesa, caja, alertas y seguimiento cliente; banner con reverificación; health check al arranque del backend.
- **2026-06-24:** **F-07 ✅ stock QR** — Reserva virtual de ingredientes en pedidos `pendiente_aprobacion`; re-validación al aprobar.
- **2026-06-24:** **F-11 ✅ estados centralizados** — `PedidosEstadoCommandService` único escritor con guards por origen.
- **2026-06-24:** **F-13 ✅ legacy confirmado** — Eliminada rama muerta en `pedidos-crear.service.ts`.
- **2026-06-24:** **F-09 ✅ QR expirado** — Al cerrar caja, pedidos `pendiente_aprobacion` >30 min → `rechazado` + alerta.
- **2026-06-24:** **F-15 ✅ mesa reservada** — Cliente QR no puede pedir en mesa `reservada` (`MESA_RESERVADA`).
- **2026-06-24:** **F-16 ✅ cancelar domi** — Asignación pasa a `cancelado` (migración `055`).
- **2026-06-24:** **F-08 ✅ factura borrador** — Sincroniza subtotal/IVA/total al agregar/eliminar ítems, descuento y antes de emitir.
- **2026-06-24:** **F-14 ✅ emitir factura** — Solo si pedido `pagado` o domicilio `entregado` sin saldo (`PEDIDO_NO_FACTURABLE`).
- **2026-06-24:** **F-10 ✅ cierre caja domi** — Bloqueo si hay `entregado` con saldo pendiente (`caja.service.ts`).
- **2026-06-24:** **F-04 ✅ para llevar sin cobro** — `entregado` bloqueado salvo domicilio en ruta; cierre = `POST .../cobrar` → `pagado`.
- **2026-06-24:** **F-05/F-06 ✅ cocina ↔ caja** — KDS muestra pedidos cobrados con ítems pendientes; cocina no regresa `pagando`/`pagado`.
- **2026-06-24:** **F-03 ✅ cobro domi independiente** — `confirmarEntrega` con `pagos_pedido` + caja; picker método pago en app independiente.
- **2026-06-24:** **F-02 ✅ dispatch KDS→domi** — `CocinasService.intentarDispatchDomicilioSiListo` + `DomiciliariosModule` en `CocinasModule`.
- **2026-06-24:** **F-01 ✅ salió sin pagar** — `MesasService.registrarSalidaSinPagar`: cierra pedidos activos (`pagado` + historial CxC), libera mesa(s) del grupo, broadcast Realtime; export `PedidosCuentaMesaService`.
- **2026-06-24:** **`docs/REGISTRO_IRREGULARIDADES_FLUJOS.md`** — checklist de 33 irregularidades (R1–R13 + F-01…F-16 + A-01…A-04) con simulación, archivos, corrección propuesta y orden P0; 11 ya resueltos en código.
- **2026-06-24:** **Cierre riesgos Antigravity** — R8 auto-asignación planta (`dispatch.service.ts`); R13 bloqueo cierre caja (`CAJA_CIERRE_OPERACION_ABIERTA`); transferir mesa libera origen + lock ambas mesas; alerta domi solo si no hubo asignación; Flutter `ManejoErrorPlan` + snack «Ver planes» al crear mesa.
- **2026-06-24:** **Antigravity integrado** — docs `*-antigravity.md`; plan freemium + límites gratis **2 mesas / 5 productos / 5 insumos / 2 staff**; bugs R1/R3/R4/R6/R7/R10/R11 en backend.
- **2026-06-24:** **OAuth Google staff móvil** — `GoogleOAuthStaffService` (redirect web `/admin/registro` vs `foody://login`); detección sesión en registro; chip «Cuenta Google conectada»; diálogo correo duplicado; `AndroidManifest` + `Info.plist` + script Supabase `foody://login`.
- **2026-06-24:** **Self-service F6 UI** — `MejorarPlanScreen` + `PagosRepository`; candados en sidebar (módulos Pro/Enterprise visibles con lock); `ModuloBloqueadoPlaceholder`; banner gratis/vencimiento con CTA; ruta `/admin/mejorar-plan`; ítem «Mejorar plan» en menú admin.
- **2026-06-24:** **Self-service F1–F3** — Migración `052_self_service_planes.sql` (plan `gratis`, OAuth en `usuarios`, `origen` en `restaurantes`); `OnboardingRestauranteService` compartido (super-admin + auth); `POST /auth/registro-restaurante` (rate limit 5/min) crea rest+sucursal+admin plan gratis; `POST /auth/login-google` (Supabase token→JWT); `plan-features.config.ts` tier `gratis` (3 staff, 1 sucursal); cron excluye plan gratis; Flutter `/admin/registro` + botón Google en login.
- **2026-06-24:** **Costeo UI fixes** — editor receta usa costo del backend (merma/rendimiento) coherente con margen/precio sugerido; diálogo margen muestra fórmula en vivo `costo÷(1−m%)`; `TabController` estable (pestaña «Qué va incluido» ya no expulsa); recarga silenciosa sin resetear pestañas; pestaña receta = solo receta (no suma incluidos).
- **2026-06-20:** **Spec módulo Analítica/BI** — `docs/MODULO_ANALITICA_BI.md` (Centro de Análisis: cocinas, inventario, domi, caja, riesgo, comparativas mes/rango; scope dueño vs admin; fórmulas; fases F1–F7). Solo documentación; extiende módulo `reportes`.
- **2026-06-19:** **QA E2E 4/4** — `scripts/verificar-todos-e2e.ps1` + `limpiar-demo-qa.ps1` (`Restaurar-InventarioDemo`); fixes: domiciliario ocupado ignora pedidos cancelados (`domiciliarios.service.ts`), libera asignación al cancelar pedido, scripts usan `pedido_id` en mesas y menú staff para disponibilidad.
- **2026-06-19:** **P4.2 + P5** — `GET /health/realtime`, banner admin Realtime, scripts `verificar-flujo-domicilio.ps1`, `verificar-inventario-menu.ps1`, `verificar-transferencia-mesa.ps1`, extensión `verificar-pagos-mesa.ps1`.
- **2026-06-19:** **P0–P3 auditoría E2E** — ver `docs/archivo/auditorias-prompts/AUDITORIA_FLUJOS_E2E.md` + `REGISTRO_IRREGULARIDADES_FLUJOS.md`.
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
- **2026-06-12:** **I1 refactor PedidosService (cierre)** — `PedidosItemsService` (`agregarItems`, `eliminarItemPedido`), `PedidosDescuentoService` (`aplicarDescuento`); `pedidos.service.ts` ~224 LOC fachada (listar, delegación); `npm run build` OK. Ver `docs/archivo/auditorias-prompts/AUDITORIA_ARQUITECTONICA_FOODY.md` I1 ✅.
- **2026-06-12:** **Auditoría fases C–E** — Fase C: UI eliminar ítem en `MesaPedidosSheet`, Realtime sheet mesa, máquina estados `pagando`→`pagado` (`pedido-estados.ts`), admin **Turno mesas** (`POST /mesas/asignar-turno`). Fase D: `PlanFeaturesGuard` + `@RequiereModulo`, `plan`/`modulos` en login/perfil/JWT, sidebar filtra por plan; Realtime `caja_movimiento` + `alerta_nueva`. Fase E: `endpoints_api_foody.md`, `ANALISIS_SISTEMA.md` histórico, migración `045_demo_plan_pro.sql`. Ver `docs/archivo/auditorias-prompts/AUDITORIA_ARQUITECTONICA_FOODY.md`.
- **2026-06-12:** **Auditoría RT-2 + C5 + I3** — Realtime: `pedido_asignado` (planta), `oferta_nueva` (independiente); Flutter dashboards suscritos + poll 60s. Promociones: migración `044` (`codigo`, `descuento_*`, `pedidos.promocion_id`); `GET /promociones/validar-codigo`; checkout con código. Mesas: `SucursalScopeService` en controller.
- **2026-06-12:** **Fix auditoría arquitectónica (Fase A + C4 + RT-1)** — C1: `cobrarCuentaMesa` → `movimientos_caja` + auditoría + exige caja abierta; C2: no venta caja en `pendiente_aprobacion` / mesa diferida + reversa al rechazar; M5: selector método pago en `MesaPedidosSheet`; C4: `DELETE /pedidos/:id/items/:itemId` + alerta `item_eliminado_post_cocina`; RT-1: `cocina_actualizada` + KDS suscrito (poll 60s backup). Ver `docs/archivo/auditorias-prompts/AUDITORIA_ARQUITECTONICA_FOODY.md`.
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
- **2026-06-04:** Auditoría integral → `docs/archivo/ANALISIS_SISTEMA.md` (histórico).
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
| `suscripciones_restaurante` | `estado` → guard `SuscripcionActivaGuard`. `plan` → **`PlanFeaturesGuard`** + límites numéricos. Ver `docs/PLANES_SUSCRIPCION.md`. |

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
| POST | `/dispositivos/vincular-auth` | ✅ Google/Supabase → device + reclama pedidos |
| GET | `/pedidos/mios?device_id=` | ✅ + Bearer opcional (auth_uid) |
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
| POST | `/auth/refresh` | JWT válido | ✅ AUTH-FLOW (mismo `tv`) |
| POST | `/auth/logout` | JWT | ✅ bumpea `token_version` |
| GET | `/auth/perfil` | JWT | ✅ |
| GET | `/dashboard/resumen` | `ver_dashboard` | ✅ |
| GET | `/pedidos` | `ver_pedidos` | ✅ |
| PATCH | `/pedidos/:id/estado` | `ver_pedidos` | ✅ |
| PATCH | `/pedidos/:id/aprobar` | `aprobar_pedido_mesa` | ✅ body opcional `mesera_id` (obligatorio si no es mesero) |
| PATCH | `/pedidos/:id/items/:itemId` | `crear_pedido` | ✅ cantidad/toppings/nota (Fase 2) |
| DELETE | `/pedidos/:id/items/:itemId` | `crear_pedido` | ✅ + reimpresión comanda |
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
| GET | `/domiciliarios-planta/comisiones-independientes/:sucursal_id` | `gestionar_domiciliarios` | ✅ |
| GET | `/domiciliarios-planta/liquidacion/:sucursal_id` | `gestionar_domiciliarios` / `ver_caja` | ✅ |
| POST | `/domiciliarios-planta/liquidar/:domiciliario_planta_id` | `gestionar_domiciliarios` / `ver_caja` | ✅ |
| PATCH | `/domiciliarios-planta/config-fiado/:sucursal_id` | `gestionar_domiciliarios` | ✅ |
| POST | `/domiciliarios-planta/asignar` | `gestionar_domiciliarios` | ✅ |
| POST | `/domiciliarios-planta/reasignar` | `gestionar_domiciliarios` / `ver_pedidos` | ✅ |
| GET | `/domiciliario/pedidos-asignados` | `ver_pedidos` (planta) | ✅ |
| PATCH | `/domiciliario/pedidos/:id/en-camino`, `.../confirmar-entrega` | `ver_pedidos` (planta) | ✅ |
| POST | `/auth/login-domiciliario` | — | ✅ |
| POST | `/domiciliarios-planta/dispatch-independiente/:pedido_id` | `gestionar_domiciliarios` | ✅ |
| POST/GET/PATCH | `/domiciliarios/sesion/*`, `/ofertas-activas`, `/ofertas/:id/responder`, `/pedidos-activos`, `/pedidos/:id/*` | `domiciliario_independiente` | ✅ |
| GET | `/pedidos` (activos + `items_resumen`), `/pedidos/cerrados-hoy`, `/pedidos/:id/detalle` | `ver_pedidos` | ✅ kanban |
| GET | `/reportes/financiero`, `/productos`, `/pedidos` | `ver_reportes` | ✅ |
| GET | `/analitica/resumen`, `/ventas`, `/productos`, `/cocinas`, `/inventario`, `/domiciliarios`, `/caja`, `/riesgo`, `/export`, `/comparativa-sedes` | `ver_analitica` | ✅ |
| POST | `/impresion/reimprimir` | `ver_cocina` | ✅ COC-REIMP |
| GET | `/analitica/pedidos-recientes` | `ver_analitica` | ✅ dashboard Resumen |
| GET | `/analitica/rentabilidad` | `ver_finanzas` | ✅ P&L (ventas − COGS − gastos) |
| CRUD | `/finanzas/costos-fijos`, `/finanzas/empleados`, `/finanzas/gastos` | `ver_finanzas` | ✅ + pagar fijos/nómina |
| GET | `/alertas/:sucursal_id` | `ver_alertas` | ✅ |
| POST | `/alertas/evaluar/:sucursal_id` | `ver_alertas` | ✅ |
| PATCH | `/alertas/:id/revisar` | `ver_alertas` | ✅ |
| GET/POST | `/usuarios` | `gestionar_usuarios` | ✅ |
| GET | `/usuarios/meseros-activos` | `aprobar_pedido_mesa` / `ver_pedidos` / `gestionar_mesas` | ✅ picker QR |
| GET | `/usuarios/catalogo-roles` | `gestionar_usuarios` | ✅ P2-17 |
| PATCH | `/usuarios/:id` | `gestionar_usuarios` | ✅ P2-17 |
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
