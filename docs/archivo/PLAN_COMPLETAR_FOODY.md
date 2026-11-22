# Foody — Plan para completar la app (qué falta y qué hacer)

> **Fecha:** 2026-06-04. Documento operativo derivado de `docs/ANALISIS_SISTEMA.md`.
> Léelo junto a `docs/AVANCE_PROYECTO.md` (estado vivo) y `INFRAESTRUCTURA/` (especificación).
>
> Objetivo de este doc: que cualquiera (tú o un agente) sepa **exactamente qué falta**, en qué orden, y cómo probarlo, para considerar Foody "terminado".

---

## 0. Cómo leer este documento

- **✅ Hecho** = ya está en código y compila.
- **🟡 Parcial** = existe pero le falta lógica/UX de la spec.
- **⏳ Falta** = no está hecho.
- Cada tarea indica: **dónde** (backend / Flutter / BD), **qué** y **por qué**.
- "Pospuesto" = acordado no hacer aún (FCM, DIAN, Python).

---

## 1. Lo que YA funciona (no rehacer)

| Área | Estado | Nota |
|------|--------|------|
| Cliente sin login | ✅ | Ciudad → restaurantes → sucursal → menú → carrito → checkout → pedido → seguimiento |
| Pedido por QR de mesa | ✅ | `/mesa/:qr_token` → menú → checkout tipo mesa → aprobación mesero |
| Backend pedidos | 🟡 | Transacción, combos, borrador factura, **IVA/descuentos/zonas** |
| Login staff + roles | ✅ | JWT recarga permisos desde BD en cada request |
| Panel admin (Kanban, mesas, caja, menú, inventario, reportes, alertas, usuarios, facturación) | ✅/🟡 | Operativo; varios módulos a nivel "parcial" |
| Mesas (CRUD + QR + aprobar/rechazar + transferir) | ✅ | |
| Super Admin | 🟡 | Onboarding restaurantes, usuarios globales, config editable, estadísticas, documentos |
| Domiciliarios (planta + independiente + dispatch) | 🟡 | Falta GPS real y push |
| **Cocinas + impresoras + KDS** | ✅ | **Bloque 1 — recién terminado** (aplicar `026_cocinas_kds.sql`) |

**Logins demo (contraseña `123456`):** `admin@foody.demo`, `super@foody.demo`, `domi@foody.demo`, `repartidor@foody.demo`, `cocina@foody.demo`.

---

## 2. Lo que FALTA, por bloques (orden recomendado)

### Bloque 1 — Cocina ✅ HECHO
CRUD cocinas/impresoras, selector de cocina en producto, KDS con estado por ítem. Migración `026`.
**Pendiente de ti:** aplicar migración + reconstruir backend + probar.

---

### Bloque 2 — Dinero correcto (IVA · descuentos · domicilio por zona) 🟡

**Por qué:** hoy el IVA siempre es 0 y el domicilio es fijo $5.000; los descuentos no tienen reglas. Para un POS real esto debe ser exacto.

| Tarea | Estado | Nota |
|-------|--------|------|
| 2.1 Calcular IVA en el pedido | ✅ | `pedidos.service` + `FacturacionService.calcularIvaParaPedidoEnTransaccion` |
| 2.2 Desglose en factura | ✅ | Borrador usa total del pedido; IVA alineado con config fiscal |
| 2.3 Endpoint aplicar descuento | ✅ | `POST /pedidos/:id/descuento` + alerta >30% + auditoría |
| 2.4 UI descuento Kanban | ✅ | Diálogo monto/% + motivo en `pedidos_kanban_widget.dart` |
| 2.5 Zonas de cobertura backend | ✅ | `ZonasModule`, Haversine, fallback $5.000 |
| 2.6 UI zonas admin | ✅ | `ZonasAdminScreen` en panel (permiso `gestionar_sucursales`) |
| 2.7 Reglas cancelación | ✅ | Motivo obligatorio; >2 min o en cocina → admin/gerente |
| 2.8 Checkout cotización | ✅ | `GET /zonas/cotizar-domicilio` (sin GPS usa zona más económica) |
| **Pendiente de ti** | ⏳ | Aplicar migración `027_bloque2_dinero.sql` + reiniciar backend |

**Criterio de hecho:** un pedido en régimen común muestra IVA en factura; un descuento del 35% genera alerta; el domicilio cambia según zona.

---

### Bloque 3 — Super Admin completo (control de la plataforma) 🟡

**Por qué:** tú (super admin) debes poder crear todo. Hoy faltan piezas clave.

| Tarea | Estado | Nota |
|-------|--------|------|
| 3.1 Crear restaurante + onboarding | ✅ | `POST /super/restaurantes` — restaurante + sucursal + admin + suscripción prueba 14 días |
| 3.2 Usuarios globales | 🟡 | GET + POST + PATCH estado + cambiar contraseña; UI listar/toggle/long-press contraseña |
| 3.3 Editar configuración global | ✅ | `PATCH /super/configuracion/:clave` + tab Config en panel |
| 3.4 Estadísticas globales | ✅ | `GET /super/estadisticas` — pedidos hoy + ingresos Foody |
| 3.5 Aprobar/rechazar documentos domiciliario | ✅ | Endpoints + tab documentos pendientes |
| 3.6 UI super admin | ✅ | Panel ampliado: 6 tabs + FAB crear restaurante |
| 3.7 Admin crea sucursales | ✅ | `POST /sucursales` + `SucursalesAdminScreen` |
| 3.8 Multi-sucursal (admin) | ✅ | Selector en AppBar del panel restaurante |
| 3.9 **Restricciones por plan** (básico/pro/enterprise) | ⏳ Pendiente | Plan = metadata en BD; no limita módulos. Ver `docs/PLANES_SUSCRIPCION.md` |

**Criterio de hecho:** desde el panel Foody creas un restaurante nuevo con su admin y este puede entrar y operar.

**Pendiente menor:** formulario super admin para crear usuario global (hoy vía API; onboarding cubre admin inicial). **Pendiente mayor:** matriz plan→features y guards en backend/Flutter (`docs/PLANES_SUSCRIPCION.md`).

---

### Bloque 4 — Seguridad (antes de producción) ✅

| Tarea | Dónde | Detalle |
|-------|-------|---------|
| 4.1 RLS en Postgres | BD | Migración `028_bloque4_seguridad_rls.sql` — RLS FORCE + REVOKE anon/authenticated en tablas de negocio. **Aplicar en Postgres.** |
| 4.2 Realtime por backend (broadcast) | Backend + Flutter | `RealtimeBroadcastService` emite tras commit; cliente escucha `onBroadcast` en `FoodyRealtime`. |
| 4.3 Endurecer QR token | Backend | `randomBytes(16).hex` (32 chars); constraint BD en migración 028. |
| 4.4 Rate limit + CORS | Backend | `RateLimitGuard` global + `@RateLimitPublico` en `/pedidos` y `/dispositivos/registrar`; `CORS_ORIGEN` en `.env`. |
| 4.5 Secretos | Infra | `.env.example` documenta `JWT_SECRET`, `SUPABASE_SERVICE_KEY`; no commitear `.env`. |

**Criterio de hecho:** un usuario anónimo no puede leer pedidos de otra sucursal; las escrituras pasan siempre por el API. **Verificar** tras aplicar migración 028.

---

### Bloque 5 — UX del cliente (pulir el flujo) ✅

| Tarea | Dónde | Detalle |
|-------|-------|---------|
| 5.1 "Mis pedidos" | Flutter + API | `GET /pedidos/mios`, pantalla `/cliente/mis-pedidos`, cache local |
| 5.2 Geolocalización en checkout domicilio | Flutter | GPS + mapa → lat/lng → cotización zona |
| 5.3 Observaciones + cantidad en producto | Flutter | Campo observaciones + contador en `DetalleProductoSheet` |
| 5.4 Combos en modal cliente | Flutter | `DetalleComboSheet` con ítems incluidos |
| 5.5 Historias/promos estilo WhatsApp | Flutter + backend | Módulo `/promociones`, admin + stories bar menú |
| 5.6 Subir imágenes (Supabase Storage) | Flutter + backend | ⏳ Pendiente — hoy URL manual en promos/productos |
| 5.7 Encargos | Backend + Flutter | Sección menú `es_encargo`, checkout tipo `encargo` |

---

## 3. Qué le falta a CADA ROL (resumen)

| Rol | Qué ya hace | Qué le falta |
|-----|-------------|--------------|
| **Cliente** | Pedir, pagar, seguir pedido | Mis pedidos, geolocalización, combos en modal, historias |
| **Super admin** | Ciudades, bloquear restaurante | Crear restaurante/onboarding, usuarios globales, config editable, estadísticas, documentos |
| **Admin** | Todo el panel + cocinas/impresoras | Crear sucursales, zonas de cobertura, descuentos, multi-sucursal, subir imágenes |
| **Gerente** | Igual que admin sin usuarios | Igual que admin (según permisos) |
| **Cajero** | Caja + pedidos para llevar | Descuentos, arqueo con IVA |
| **Mesero** | Mesas, aprobar/rechazar/transferir | Estado "pagando", crear pedido manual en mesa libre |
| **Cocina** | ✅ KDS por ítem (Bloque 1) | Impresión real (servidor Python, pospuesto) |
| **Domiciliario planta** | Ver/confirmar entregas | GPS real, push |
| **Domiciliario independiente** | Dispatch + ofertas | GPS real, push, calificación |

---

## 4. Pendientes transversales (pospuestos por acuerdo)

| Tema | Sprint spec | Estado |
|------|-------------|--------|
| **FCM** (push cliente/staff/ofertas) | 7 | ⏳ Pospuesto hasta pedido explícito |
| **DIAN** (factura electrónica real) | 9–11 | ⏳ Pospuesto (hoy basta borrador HTML) |
| **Servidor Python** (impresión local WebSocket) | 10 | ⏳ Pospuesto |
| ERP de costeo avanzado (recetas anidadas, mermas, conteos, food cost) | 5 | 🟡 Tablas existen; lógica/UX parcial |
| Reportes financieros completos (punto de equilibrio, food cost) | 13 | 🟡 UI básica |
| RLS producción / E2E / renombrar paquete `reserva_canchas`→`foody` | 11 | ⏳ |

---

## 5. Pasos de entorno para cada bloque (cómo correrlo)

1. **Aplicar migraciones nuevas** a Postgres (Supabase self-hosted). Bloques 1–4 = `026` … `028_bloque4_seguridad_rls.sql`.
2. **Reconstruir backend** NestJS (en WSL/Docker donde corre) y reiniciarlo.
3. **Reconstruir Flutter** (`flutter build web` o `flutter run`).
4. **Probar con los logins demo** según el rol del bloque.

> Detalle de entorno local en `docs/ENTORNO_LOCAL.md`.

---

## 6. Checklist "Foody completo" (criterios de cierre)

- [ ] Cliente: pedir mesa/llevar/domicilio + ver historial + seguir en tiempo real.
- [ ] Cocina: recibe e imprime tickets por estación (impresión = Python pospuesto).
- [ ] Dinero: IVA correcto por régimen, descuentos con reglas, domicilio por zona, caja cuadra.
- [ ] Admin: crea cocinas, impresoras, productos con cocina, mesas, usuarios, sucursales, zonas.
- [ ] Super admin: crea ciudades, restaurantes (con admin), usuarios, edita configuración, ve estadísticas.
- [ ] Seguridad: RLS activo, escrituras solo por API, secretos fuera del repo.
- [ ] Estabilidad: pruebas E2E del flujo de pedido y paquete renombrado a `foody`.

---

## 7. Orden recomendado (resumen)

1. **Bloque 1 — Cocina** ✅ (aplicar migración `026` y probar)
2. **Bloque 2 — Dinero** ✅ (aplicar migración `027` y probar)
3. **Bloque 3 — Super Admin** ✅ (código listo; probar onboarding)
4. **Bloque 4 — Seguridad** ✅ (aplicar migración `028`; configurar `SUPABASE_SERVICE_KEY` + `CORS_ORIGEN` en backend)
5. **Bloque 5 — UX cliente** ✅ (falta 5.6 subir imágenes)
6. Luego, cuando lo pidas: **FCM → DIAN → Python**.
