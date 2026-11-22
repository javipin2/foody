# Foody — Análisis integral del sistema (auditoría de analista)

> **Fecha:** 2026-06-04 · **ARCHIVADO** — fotografía inicial. Estado actual: **`docs/MASTER_STATUS.md`**. No usar para backlog.

### Resuelto desde jun-04 (referencia rápida)

| Hallazgo original | Estado jun-12 |
|-------------------|---------------|
| C1–C3 Cocina/KDS/impresoras CRUD | ✅ KDS + CRUD; impresión Python ⏳ pospuesta |
| C5 Estado por ítem | ✅ |
| C7 Descuentos | ✅ Kanban + auditoría |
| C8 Zonas domicilio | ✅ |
| C10 Cliente Realtime directo | ✅ Broadcast vía backend |
| C11–C12 Super admin / sucursales | 🟡 Avanzado (planes, multi-sucursal Fase 1) |
| Cobro mesa sin caja | ✅ C1 auditoría |
| Promociones checkout | ✅ C5 auditoría |
| Planes sin restricción | ✅ `PlanFeaturesGuard` |
| Reportes vs caja | ✅ `cuadre_caja` en financiero |

---

## 1. Veredicto general

Base sólida: separación Flutter=UI / NestJS=cerebro, transacción atómica en pedidos, JWT con permisos por rol recargados desde BD en cada request, multi-tenant por `sucursal_id`. La brecha está entre la **especificación (ERP completo)** y lo **implementado**, y faltan 3 piezas del flujo operativo de cocina que el usuario pidió explícitamente.

---

## 2. Hallazgos críticos

| # | Problema | Impacto | Bloque |
|---|----------|---------|--------|
| C1 | No existe app/pantalla de COCINA (KDS). Sin `/pedidos/cocina/:id` ni marcar ítem preparando/listo | 🔴 Crítico | 1 |
| C2 | Admin no puede crear cocinas (tabla y `productos.cocina_id` existen, sin endpoint/UI) | 🔴 Crítico | 1 |
| C3 | Admin no puede crear/gestionar impresoras | 🔴 Crítico | 1 |
| C4 | El producto no permite elegir cocina al crearlo | 🔴 | 1 |
| C5 | Pedido sin estado por ítem real (Kanban mueve el pedido completo) | 🟠 | 1 |
| C6 | IVA siempre 0; `POST /pedidos` no calcula IVA | 🟠 | 2 |
| C7 | Descuentos sin endpoint ni reglas (20%/30%, alerta, auditoría) | 🟠 | 2 |
| C8 | Costo domicilio fijo $5.000; no usa `zonas_cobertura` | 🟠 | 2 |
| C9 | Cancelar pedido sin reglas (2 min, solo admin después, motivo) | 🟠 | 2 |
| C10 | Cliente lee Supabase Realtime directo sobre `pedidos` sin RLS | 🔴 Seguridad | 4 |
| C11 | Super admin incompleto (crear restaurante, usuarios globales, config PATCH, estadísticas, documentos) | 🟠 | 3 |
| C12 | Admin no puede crear sucursales ni cambiar entre sucursales | 🟠 | 3 |

---

## 3. Flujo del cliente — mejoras

Flujo actual correcto: Ciudad → Restaurantes → Sucursal → Menú → modal producto → Carrito → Checkout → Pedido → Seguimiento.

- Producto: asegurar observaciones + cantidad.
- Carrito: selector Mesa/Llevar/Domicilio con costo de domicilio en vivo (del backend).
- Checkout domicilio: geolocalización (lat/lng) + costo por zona.
- Falta **"Mis pedidos"** por `device_id` (historial).
- Historias/promos estilo WhatsApp: sin UI (media prioridad).

---

## 4. Qué le falta a cada rol

- **Super admin:** crear restaurante + onboarding (restaurante→sucursal→admin atómico), usuarios globales, config global PATCH, aprobar documentos domiciliario, estadísticas reales.
- **Admin restaurante:** crear cocinas e impresoras, asignar cocina a producto, crear sucursales, zonas de cobertura, descuentos, subir imágenes (Storage).
- **Cajero:** descuentos, arqueo con IVA.
- **Mesero:** estado "pagando", crear pedido manual en mesa libre.
- **Cocina:** no existe (hueco mayor).
- **Domiciliario:** GPS real + push (pospuesto).

---

## 5. Casos hipotéticos del restaurante + solución

| Caso | Hoy | Solución |
|------|-----|----------|
| Cocina no ve el pedido | Se pierde | KDS + impresión |
| 2 cocinas (asados/bebidas) | Todo a una | `producto.cocina_id` + ticket por cocina |
| 2 personas piden por QR a la misma mesa | Se mezcla | Pedidos se agregan a la mesa activa |
| Mesera no aprueba en 3 min | Nada | Recordatorio + alerta admin a los 5 min |
| Sin un ingrediente | Se sigue vendiendo | Auto-ocultar a stock 0 + toggle manual |
| Cliente pide factura | Borrador HTML | Calcular IVA real (DIAN pospuesto) |
| Caja cierra con diferencia | No alerta | Alerta > $5.000 |
| Mesa transferida 3+ veces | Sin control | Alerta `transferencia_multiple_mesa` |
| Dos cajas abiertas | Inconsistencia | Validar una caja por sucursal |

---

## 6. Roadmap por bloques

1. **Cocina:** CRUD cocinas + CRUD impresoras + selector cocina en producto + KDS + estado por ítem.
2. **Dinero:** IVA real + descuentos con reglas + zonas de cobertura.
3. **Super admin completo:** crear restaurante/onboarding + usuarios globales + config PATCH + sucursales para admin.
4. **Seguridad:** RLS en tablas escuchadas por Realtime o broadcast por backend.
5. **UX cliente:** Mis pedidos + geolocalización + historias.

Pospuesto por acuerdo: FCM, DIAN, servidor Python.

---

## 7. Estado de implementación de los bloques

| Bloque | Estado |
|--------|--------|
| 1 — Cocina/KDS | ✅ Hecho — CRUD cocinas/impresoras, selector cocina en producto, KDS (`/admin/cocina`), estado por ítem que recalcula el pedido. Migración `026_cocinas_kds.sql` (permiso `ver_cocina`, impresora + usuario `cocina@foody.demo`). |
| 2 — Dinero | ⏳ Pendiente |
| 3 — Super admin | ⏳ Pendiente |
| 4 — Seguridad | ⏳ Pendiente |
| 5 — UX cliente | ⏳ Pendiente |
