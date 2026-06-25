# Foody — estado por módulo (qué hay / qué falta)

> **Documento vivo.** Consultar al planificar trabajo y **actualizar al cerrar cada tarea** que toque un módulo.
>
> - Detalle técnico (BD, endpoints, UUIDs): `docs/AVANCE_PROYECTO.md` → *Referencias persistentes*
> - Spec objetivo: `INFRAESTRUCTURA/GUIA_DESARROLLO_FOODY_CURSOR.md`
> - Regla agentes: actualizar **este archivo** + changelog en `AVANCE_PROYECTO.md`

**Última actualización:** 2026-06-19 — Auditoría E2E (`docs/AUDITORIA_FLUJOS_E2E.md`); brechas P0 mesas/pedidos/inventario documentadas.

---

## Cómo leer y mantener

| Símbolo | Significado |
|---------|-------------|
| ✅ | Listo para uso en dev (flujo principal cubierto) |
| 🟡 | Parcial — funciona pero falta spec, UX o integración |
| ⏳ | Pendiente o muy incompleto |
| 🚫 | Pospuesto por acuerdo (no implementar salvo petición explícita) |

**Al completar algo:** cambia el estado del módulo, mueve ítems de *Falta* → *Hecho*, añade fecha en *Últimos cambios* (abajo) y una viñeta en `AVANCE_PROYECTO.md`.

---

## ⚠️ Falta prioritario (siempre visible)

| # | Tema | Módulo | Estado |
|---|------|--------|--------|
| 1 | Impresión física `python-escpos` + agente local | Cocina / Impresión | ⏳ P4.1 |
| 2 | Health check Realtime (`SUPABASE_*`) | Infra | ✅ P4.2 |
| 3 | Deep link FCM web | FCM | 🟡 |
| 4 | DIAN / factura electrónica real | Facturación | 🚫 pospuesto |
| 5 | Dashboard consolidado multi-sede | Multi-sucursal | ⏳ |
| 6 | Scripts E2E extendidos (domi, inventario→menú) | QA | ✅ P5 |
| 7 | Centro de Análisis (BI: cocinas, riesgo, comparativas) | Analítica | 📅 spec `docs/MODULO_ANALITICA_BI.md` |
| 8 | Self-service: auto-registro, plan gratis, login Google, cobro Wompi | Suscripciones / Onboarding | 🟡 F1–F6 hecho; webhook prod + F7 pendiente |

**Última actualización:** 2026-06-24 — Self-service F1–F3: registro público, login Google, plan gratis. 2026-06-20 — Spec Analítica/BI.

**Próximo paso recomendado del proyecto:** **Impresión física** (P4.1). Brechas P0–P3 cerradas — `docs/AUDITORIA_FLUJOS_E2E.md`.

---

## Resumen global

| Área | % aprox. | Comentario |
|------|----------|------------|
| Operación diaria (pedidos, mesas, caja, cocina, inventario) | ~80% | Usable en demo; faltan impresión y pulidos |
| Cliente final | ~85% | Flujo completo; fotos Storage y QR cámara pendientes |
| Corporativo / multi-sede | ~70% | Selector admin OK; falta dashboard cadena |
| Facturación legal / DIAN | ~30% | Solo borrador HTML |
| Producción / infra | ~20% | RLS, E2E, limpieza legacy |

---

## 1. Cliente (app sin login)

| Campo | Contenido |
|-------|-----------|
| **Estado** | ✅ Avanzado |
| **Hecho** | Ciudad → restaurante → menú → carrito → checkout → seguimiento; mesa QR; toppings/combos; domicilio con mapa OSM; mis pedidos por `device_id`; promos con código; stories en menú |
| **Falta** | Subir imágenes a Storage (promos/historias); modal detalle combo más rico; escaneo QR con cámara nativa; deep link universal FCM al abrir app |
| **Archivos** | `lib/features/menu/`, `lib/features/pedidos/`, `lib/features/ciudades/` |
| **Prioridad falta** | Baja (Storage) / Media (QR cámara) |

---

## 2. Pedidos y checkout

| Campo | Contenido |
|-------|-----------|
| **Estado** | 🟡 Parcial |
| **Hecho** | POST transacción atómica; IVA; zonas domicilio; stock al confirmar; descuentos; cancelación; cobro mesa/caja; pago mixto; Kanban + Realtime; **flujo estados v2** (`docs/FLUJO_ESTADOS_PEDIDOS.md`): sin columna Confirmado, `pagando→entregado` |
| **Falta** | DIAN; impresión auto; scripts E2E P5 |
| **Prioridad falta** | Media (DIAN pospuesto) |

---

## 3. Mesas y QR

| Campo | Contenido |
|-------|-----------|
| **Estado** | 🟡 Parcial |
| **Hecho** | Grid, CRUD, QR, transferir, unir, reservar; turno mesas admin; aprobación QR con timer; panel mesero; cajero sin turno; cuenta acumulada; agregar ítems; cobrar cuenta |
| **Falta** | PDF/imprimir QR; banner QR pendientes más visible |
| **Prioridad falta** | Baja |

---

## 4. Panel admin y multi-sucursal

| Campo | Contenido |
|-------|-----------|
| **Estado** | ✅ Avanzado |
| **Hecho** | Sidebar por permisos y plan; **selector sede admin recarga todos los módulos** (`KeyedSubtree` + `didUpdateWidget`); gerente solo ve su sede (chip); scope API en pedidos, caja, mesas, catálogo, zonas, alertas, facturación |
| **Falta** | Dashboard consolidado cadena (KPIs multi-sede); rol `gerente_cadena` |
| **Archivos** | `lib/features/admin/presentation/panel_restaurante_screen.dart`, `docs/MULTI_SUCURSAL.md` |
| **Prioridad falta** | Media (solo si operan 2+ sedes a diario) |

---

## 5. Caja

| Campo | Contenido |
|-------|-----------|
| **Estado** | ✅ Avanzado |
| **Hecho** | Abrir/cerrar; movimientos; gastos; fiados; cobro mixto; devolución; arqueo ciego; cuadre en reportes |
| **Falta** | Cuentas por cobrar avanzadas |
| **Archivos** | `foody_backend/src/modulos/caja/`, `lib/features/caja/` |
| **Prioridad falta** | Baja |

---

## 6. Menú / catálogo admin

| Campo | Contenido |
|-------|-----------|
| **Estado** | 🟡 Parcial |
| **Hecho** | CRUD productos, toppings, bebidas, combos; precio local vs para llevar; selector cocina en producto; enlace «Ver costos» |
| **Falta** | Subir imágenes (Supabase Storage); precio sugerido llevar en pantalla Costos |
| **Archivos** | `foody_backend/src/modulos/catalogo/`, `lib/features/catalogo/` |
| **Prioridad falta** | Media (imágenes) |

---

## 7. Cocina / KDS / impresoras

| Campo | Contenido |
|-------|-----------|
| **Estado** | 🟡 Parcial |
| **Hecho** | CRUD cocinas e impresoras; KDS por ítem; sonido; alerta >20 min; KDS respeta sede seleccionada en panel admin; estado pedido recalculado por ítems |
| **Falta** | **Impresión física** (`python-escpos`); tickets automáticos a impresora al confirmar; agente Python en PC del restaurante |
| **Archivos** | `lib/features/cocinas/`, `foody_python_printer/`, `foody_backend/src/modulos/impresion/` |
| **Prioridad falta** | **Alta** |

---

## 8. Inventario

| Campo | Contenido |
|-------|-----------|
| **Estado** | ✅ Avanzado |
| **Hecho** | Insumos, compras, ajustes, conteo físico; recetas; subrecetas; traslados entre sedes; vista hermanas (solo lectura); alertas stock bajo; impacto stock por plato |
| **Hecho** | … + **ajuste stock → menú** (`CatalogoDisponibilidadService`, Realtime) |
| **Falta** | Propagación en compra/conteo (mismo hook pendiente extender) |
| **Prioridad falta** | Baja |

---

## 9. Costeo industrial (KYG)

| Campo | Contenido |
|-------|-----------|
| **Estado** | 🟡 Parcial |
| **Hecho** | Motor costos, merma, empaques domicilio; ítems incluidos; tab Costos; margen; precio sugerido; lista de mercado; subrecetas CRUD |
| **Falta** | Producción en lote (`usa_produccion_lote`); simulador popularidad mesa/domicilio |
| **Falta pospuesta** | Import Excel KYG (solo referencia fórmulas) 🚫 |
| **Archivos** | `docs/MODULO_COSTEO.md`, `foody_backend/src/modulos/costeo/` |
| **Prioridad falta** | Baja (Fase 2–3) |

---

## 10. Domiciliarios

| Campo | Contenido |
|-------|-----------|
| **Estado** | 🟡 Parcial |
| **Hecho** | Planta: asignación Kanban, app tabs; independientes: dispatch, ofertas 60 s, registro; push FCM ofertas; auto-dispatch sin planta libre |
| **Falta** | GPS tiempo real en mapa; tracking continuo repartidor |
| **Archivos** | `lib/features/domiciliarios/`, `foody_backend/src/modulos/domiciliarios/` |
| **Prioridad falta** | Media |

---

## 11. Zonas / mapas / horarios

| Campo | Contenido |
|-------|-----------|
| **Estado** | ✅ Avanzado |
| **Hecho** | Anillos km/precio; mapa OSM admin; cotización API checkout; horarios sucursal CRUD; geografía Photon (sin Google Maps) |
| **Falta** | — |
| **Archivos** | `lib/features/zonas/`, `lib/core/mapas/`, `foody_backend/src/modulos/zonas/` |
| **Prioridad falta** | — |

---

## 12. Promociones

| Campo | Contenido |
|-------|-----------|
| **Estado** | 🟡 Parcial |
| **Hecho** | Admin publicar URL; stories en menú cliente; código descuento en checkout |
| **Falta** | Subir foto a Storage (hoy URL manual) |
| **Archivos** | `lib/features/promociones/` |
| **Prioridad falta** | Media |

---

## 13. Reportes

| Campo | Contenido |
|-------|-----------|
| **Estado** | 🟡 Parcial |
| **Hecho** | Financiero, productos, pedidos; cuadre caja (pedidos vs movimientos) |
| **Falta** | Gráficos avanzados en dashboard; export PDF/Excel |
| **Archivos** | `lib/features/reportes/`, `foody_backend/src/modulos/reportes/` |
| **Prioridad falta** | Baja |

---

## 14. Facturación

| Campo | Contenido |
|-------|-----------|
| **Estado** | 🟡 Parcial |
| **Hecho** | Config fiscal; listado; borrador HTML; emitir/anular borrador; toggle en checkout |
| **Falta** | **DIAN / proveedor FE** (factura electrónica legal); PDF con numeración DIAN |
| **Falta pospuesta** | Integración DIAN real 🚫 hasta acuerdo comercial |
| **Archivos** | `lib/features/facturacion/`, `foody_backend/src/modulos/facturacion/` |
| **Prioridad falta** | Baja (pospuesto) |

---

## 15. Alertas

| Campo | Contenido |
|-------|-----------|
| **Estado** | 🟡 Parcial |
| **Hecho** | Listar; marcar revisada; evaluar reglas batch; disparadores automáticos (stock, cuadre, margen, transferencias, etc.) |
| **Falta** | Push/email para alertas críticas (hoy solo in-app + FCM eventos pedido) |
| **Archivos** | `lib/features/alertas/`, `docs/ALERTAS_AUTOMATICAS.md` |
| **Prioridad falta** | Baja |

---

## 16. Usuarios staff

| Campo | Contenido |
|-------|-----------|
| **Estado** | 🟡 Parcial |
| **Hecho** | Listar, crear, activar/desactivar; selector sucursal si corporativo (`gestionar_sucursales`) |
| **Falta** | Editar rol/permisos granulares en UI |
| **Archivos** | `lib/features/usuarios/` |
| **Prioridad falta** | Baja |

---

## 17. Super Admin (Foody Control)

| Campo | Contenido |
|-------|-----------|
| **Estado** | 🟡 Avanzado |
| **Hecho** | Panel 7 secciones; restaurantes; planes metadata; límites plan (sucursales/usuarios); cron suscripciones vencidas; usuarios globales; ciudades; **`OnboardingRestauranteService`** (onboarding atómico) |
| **Falta** | Cobro recurrente / pasarela Wompi; guard tenant estricto en todos `/super/*`; aprobar documentos domiciliario (flujo completo) |
| **Archivos** | `lib/features/admin/presentation/panel_foody_control_screen.dart` |
| **Prioridad falta** | Media |

---

## 18. FCM / notificaciones push

| Campo | Contenido |
|-------|-----------|
| **Estado** | 🟡 Parcial |
| **Hecho** | Cola + cron; eventos pedido/domi; móvil + web recibir; `/prueba` y `/prueba-web`; primer plano web (Notification API); logout desactiva token |
| **Falta** | `notificationclick` en `web/firebase-messaging-sw.js` (deep link segundo plano); fix ruta cliente en `pedidos-soporte.service.ts` |
| **Archivos** | `docs/FCM_FOODY.md`, `foody_backend/src/modulos/notificaciones/`, `lib/core/notificaciones/` |
| **Prioridad falta** | Media |

---

## 19. Impresión Python

| Campo | Contenido |
|-------|-----------|
| **Estado** | ⏳ Pendiente (MVP cola OK) |
| **Hecho** | Cola `impresion_cocina_jobs` en NestJS; WebSocket MVP simulado (`foody_python_printer/`) |
| **Falta** | `python-escpos` impresora real; instalador en PC restaurante; config impresora por cocina en producción |
| **Archivos** | `foody_python_printer/`, `foody_backend/src/modulos/impresion/` |
| **Prioridad falta** | **Alta** |

---

## 20. Producción / calidad / legacy

| Campo | Contenido |
|-------|-----------|
| **Estado** | ⏳ Pendiente |
| **Hecho** | Scripts verificación (`verificar-paso0`, `verificar-fcm`, `verificar-multi-sucursal`, etc.); legacy aislado en `lib/legacy/` |
| **Falta** | RLS exhaustivo Supabase prod; E2E automatizado / checklist CI; renombrar paquete `reserva_canchas`; borrar `lib/screens/` legacy; pulido animaciones; QA documentado por rol |
| **Archivos** | `docs/ENTORNO_LOCAL.md`, Sprint 11 en guía desarrollo |
| **Prioridad falta** | Alta antes de go-live |

---

## 21. Centro de Análisis (Analítica / BI)

| Campo | Contenido |
|-------|-----------|
| **Estado** | 📅 Planificado (solo documentación) |
| **Hecho** | Spec completa: `docs/MODULO_ANALITICA_BI.md` (arquitectura, endpoints, fórmulas, BD fuente, fases). Base reutilizable: módulo `reportes` (`/financiero`, `/productos`, `/pedidos`) |
| **Falta** | Backend `analitica` (resumen/ventas/cocinas/inventario/domi/caja/riesgo/comparativas), pantalla Flutter `lib/features/analitica/`, índices + cache, permiso `ver_analitica`, QA |
| **Por qué falta** | Módulo nuevo solicitado; se documenta primero para construir por fases sin fallos |
| **Cuándo** | Tras impresión física (P4.1) o según prioridad del usuario; fases F1→F7 en la spec |
| **Archivos** | `docs/MODULO_ANALITICA_BI.md`; futuros `foody_backend/src/modulos/analitica/`, `lib/features/analitica/` |
| **Prioridad falta** | Media-alta (alto valor para dueño/admin; vendible como tier Pro) |

---

## 22. Self-service / onboarding / plan gratis

| Campo | Contenido |
|-------|-----------|
| **Estado** | 🟡 Parcial (F1–F6) |
| **Hecho** | Migraciones `052`–`054`; onboarding + registro + Google; deep link móvil `foody://login`; chip Google en registro; plan `gratis`; cron avisos; Wompi checkout; **Flutter** `MejorarPlanScreen`, candados módulos, banner CTA, `PagosRepository`; `scripts/verificar-self-service.ps1` (8 pruebas) |
| **Falta** | Webhook Wompi en URL pública; F7 métricas embudo; captcha anti-spam |
| **Por qué falta** | Webhook requiere dominio/ngrok; F7 analítica planificada |
| **Cuándo** | Webhook al desplegar; F7 sprint analítica |
| **Archivos** | `lib/features/pagos/`, `lib/features/admin/presentation/widgets/suscripcion_aviso_banner.dart`, `foody_backend/src/modulos/pagos/` |
| **Prioridad falta** | Media-alta (habilita crecimiento sin super-admin manual) |

---

1. ⏳ Impresión física (`python-escpos`)
2. 📅 Centro de Análisis / BI (`docs/MODULO_ANALITICA_BI.md`) — F1 backend `/resumen` primero
3. 🟡 FCM: fix ruta cliente + `notificationclick` web
4. ⏳ Dashboard cadena multi-sede
5. 🟡 Storage imágenes (menú + promos)
6. 🟡 GPS domiciliario
7. 🚫 DIAN (cuando haya proveedor FE)
8. ⏳ Sprint 11 producción (RLS, E2E, legacy)

---

## Últimos cambios (este documento)

| Fecha | Cambio |
|-------|--------|
| 2026-06-24 | **Módulo 22 F4** — avisos FCM vencimiento, bloqueo escalonado, banner panel, script verificación |
| 2026-06-24 | **Módulo 22 Self-service F1–F3** — registro público, login Google, plan gratis, UI Flutter |
| 2026-06-20 | **Módulo 21 Analítica/BI** — spec `docs/MODULO_ANALITICA_BI.md`; añadido a backlog y falta prioritario |
| 2026-06-19 | **`docs/AUDITORIA_FLUJOS_E2E.md`** — 9 flujos, R1–R13, plan P0–P5; prioridades §Falta prioritario actualizadas |
| 2026-06-19 | Creación inicial del mapa 20 módulos; prioridades visibles; enlace desde `AVANCE_PROYECTO.md` |
| 2026-06-19 | **Pedidos — flujo estados v2** — Sin columna Confirmado; `pagando→entregado`; doc `FLUJO_ESTADOS_PEDIDOS.md` |
| 2026-06-19 | Módulo 18: FCM web operativo (`/prueba-web`, primer plano Chrome) |

---

## Plantilla para actualizar un módulo

Copia y rellena al cerrar una tarea:

```markdown
### [Nombre módulo] — YYYY-MM-DD
- Estado: ✅ / 🟡 / ⏳
- Completado: ...
- Sigue faltando: ...
- Archivos tocados: ...
```
