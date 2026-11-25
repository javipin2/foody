# Foody — Consistencia entre módulos (Prompt 29)

> **Fecha:** 2026-08-06  
> **Alcance:** relaciones **entre** módulos (no calidad intra-módulo).  
> **Base:** [`MAPA_FOODY.md`](MAPA_FOODY.md) + auditorías PED/COC/CAJ/INV/PROMO/CFG/DASH/REP/RT + cruce código.  
> **Estado oficial:** [`MASTER_STATUS.md`](MASTER_STATUS.md) § Consistencia módulos (CONS-\*).  
> **Al cerrar un CONS-\*:** marcar ✅ aquí + MASTER + viñeta en `AVANCE_PROYECTO.md`.

**Método:** trazas Nest (`pedidos-*`, cocina, caja, inventario, reportes, analitica, config) + scripts vivos + reuso de IDs abiertos (PED-/COC-/CFG-/DASH-/ANA-/RT-).

---

## Veredicto

| Ruta | Consistencia global | Riesgo principal |
|------|---------------------|------------------|
| Pedido → Cocina → Caja → Inventario → Análisis | 🟡 | `no_disponible` no ajusta el valor facturable; universos contables pendientes |
| Meseros → Pedidos → Cocina | 🟡 | KDS UI ≠ `pedidos.estado`; RT sin replay |
| Promociones → Pedido → Caja | 🟡 | Snapshot OK; add ítems congela % |
| Inventario → Productos → Cocina | 🟡 | Cascade parcial al vender |
| Caja → Reportes | 🟡 | Universos distintos (movs vs `pedidos.total`) |
| Configuración → Todos | 🔴 | CFG-GLOBAL-DEAD + márgenes sin write |

**Happy path mesa** (crear → cocina → cobro → caja → stock) **sí** cierra bien. Los rotos son **combinaciones** (prepago, N/D cocina, stock compartido, config mentira).

Leyenda: 🟣 abierto · 🟡 aceptado/parcial · ✅ OK · **NEW** = hallazgo Prompt 29

---

## Verificación en vivo (esta sesión)

| Script / check | Resultado |
|----------------|-----------|
| `GET /api/v1/salud` | ✅ `exito: true` |
| `verificar-caja-coherencia.ps1` | ✅ exit 0 — 0 pedidos con venta > total |
| `verificar-coherencia-pedidos-analitica.ps1` | 🟡 KPI analítica = reportes **438175**; falló al final en `GET /caja/estado` (**ruta inexistente** → ver CONS-SCRIPT-01) |
| `verificar-cuadre-caja.ps1` | ❌ exit 1 — pedidos **478175** vs caja API **337175** (diff **141000**); BD cruce también diverge |
| `verificar-inventario-ciclo.ps1` | ✅ descuento auto + 3 capas + alerta |
| `verificar-promociones-precios.ps1` | ✅ snapshot + precio congelado + apilado combo |

Click-through multi-pantalla en dispositivo: **no corrido**.

---

| Pedido → Cocina → Caja → Inventario → Análisis | 🟡 | `no_disponible` no ajusta el valor facturable; universos contables pendientes |

### ¿Se refleja un cambio?

| Cambio | Cocina | Caja | Inventario | Análisis/Reportes |
|--------|--------|------|------------|-------------------|
| Crear mesa staff → `en_cocina` | Tickets + RT | No (cobro después) | `stock_descontado` + movs | No hasta “venta” criterio |
| Crear para llevar + efectivo | Tickets | **Sí** venta al crear | Sí | Cuenta `pedidos.total` |
| Ítem `listo` (todos) | Pedido → `listo` | — | — | — |
| Ítem `no_disponible` | Alerta + job | — | **Stock NO vuelve** | Consumo ya contado |
| Cobrar | — | Movimiento `venta` | — | Coincide cobro |

### Hallazgos

| ID | Estado | Sev | Hallazgo | Evidencia |
|----|--------|-----|----------|-----------|
| **PED-PREPAGO-01** | ✅ | Alta (cerrado) | Pedido para llevar prepago sigue `en_cocina` mientras se prepara, pero no bloquea cierre con saldo cero; cocina lo pasa a `pagado` al resolver todos los ítems. Reintento SIN_SALDO es esperado. | `SQL_WHERE_PEDIDO_OPERACION_ABIERTA`; `caja.service.ts`; `cocinas.service.ts`; E2E casos 28–30 |
| **COC-NODISP-01** | ✅ | Alta | `no_disponible` cuenta como resuelto; al terminar el resto, el pedido pasa a `listo` | `pedido-estados.ts:176-206`; `cocinas.service.ts:456-480`; E2E cocina 4/4 |
| **CONS-NODISP-STOCK-01** | ✅ | Media | Cocina registra merma y marca producto fuera de menú cuando stock ya fue descontado | `cocinas.service.ts:394-450`; `pedidos-inventario.service.ts:658-688` |
| **PED-DELETE-NODISP-STOCK-01** | ✅ | Media | Eliminar línea N/D ya no repone stock tras merma registrada; verificada con E2E | `pedidos-items.service.ts:807-840`; `cocina.e2e-spec.ts`; QA inventario |
| **CONS-KDS-UI-01** | ✅ | Media | KDS y backend consideran `listo`/`no_disponible` líneas resueltas | `kds_screen.dart:1055-1109`; `pedido-estados.ts:176-206`; E2E cocina 4/4 |
| **COC-NODISP-COMMERCE-01** | 🟣 | Alta | La línea N/D no ajusta total/pago/factura; posibilidad de cobrar por producto no servido | `cocinas.service.ts:394-480`; `pedidos-items.service.ts:850-900`; falta E2E de saldo |
| **CONS-COSTO-SNAPSHOT-01** | ✅ | Media | Canon documentado en API; ledger sync al editar qty | `verificar-cons-costo-snapshot.ps1` |
| **CONS-MARGEN-STALE-01** | ✅ | Baja | `UPDATE margenes_venta` en `actualizarItemPedido` | `pedidos-items.service.ts` |
| **ANA-FILT-PROD-01** | ✅ | Media | Con filtros por producto/categoría/cocina el KPI y las series suman líneas filtradas | `analitica.service.ts:133-177`; `AUDITORIA_REPORTES.md`; batería analítica 9/9 |
| **REP-LINE-01** | 🟡 | Baja | Header = `SUM(pedidos.total)`; ranking = líneas+extras | Intencional dual |
| **AQ-DUP-01** | ✅ | Alta | Write-path unificado `StockMovimientoService` (residual costeo `produccion`) | AUDITORIA_ARQUITECTURA_CALIDAD |

**Combinaciones que rompen el sistema:** prepago para llevar + cierre caja; último ítem N/D + despacho/cobro; cancel post-prep (ramas merma vs restore).

---

## Ruta 2 — Meseros → Pedidos → Cocina

### ¿Se refleja?

| Acción mesero | Pedidos | Cocina |
|---------------|---------|--------|
| Crear / aprobar QR | `en_cocina` + `mesera_id` | Tickets + RT |
| Add ítems post-cocina | Stock + reimpresión | Nuevo ticket |
| Transferir mesa | Mismo `pedido_id` | Sigue el pedido |
| Cobrar / split | Estado + caja | Ítems cobrados |

### Hallazgos

| ID | Estado | Sev | Hallazgo | Evidencia |
|----|--------|-----|----------|-----------|
| **COC-NODISP-COMMERCE-01** | 🟣 | Alta | Mesero/caja/cliente mantienen el importe original de una línea no servida; el flujo de pago no ofrece conciliación específica | Path 1 |
| **RT-RECON-01** | 🟣 | Alta | Sin replay/refetch tras corte → mesero ≠ cocina hasta poll | AUDITORIA_REALTIME |
| **PED-BYPASS-01** | ✅ | Media | `salio-sin-pagar` → `PedidosEstadoCommandService` (2026-08-08) | AUDITORIA_PEDIDOS |
| **MES-SPLIT-01** | ✅ | — | Split = mismo pedido; API coherente | AUDITORIA_MESEROS |

Happy path mesa: ✅ (scripts meseros/pagos previos + inventario ciclo).

---

## Ruta 3 — Promociones → Pedido → Caja

### ¿Se refleja?

| Cambio | Pedido abierto | Pedido nuevo | Caja |
|--------|----------------|--------------|------|
| Aplicar promo | Snapshot `descuento` / `promocion_id` | — | Cobro = total congelado |
| Desactivar promo | **Mantiene** descuento | Rechaza código | OK |
| Cambiar precio catálogo | Ítems viejos congelados | Nuevos = precio actual | Cobro mixto OK |
| **Agregar ítems** con % promo | Recalcula % sobre el subtotal nuevo | — | Descuento mantiene la tasa; monto fijo se limita al subtotal |

### Hallazgos

| ID | Estado | Sev | Hallazgo | Evidencia |
|----|--------|-----|----------|-----------|
| **PROMO-SNAP-01** | ✅ | — | Desactivar no recalcula abiertos | `verificar-promociones-precios` A |
| **PRECIO-COBRO-01** | ✅ | — | Cobro = snapshot | Script B |
| **CONS-PROMO-ADD-01** | ✅ | — | Add/delete/update reutilizan `recalcularDescuentoTrasCambioSubtotal`: lee la promo por ID+sucursal, recalcula porcentaje y limita monto fijo al subtotal | `pedidos-items.service.ts:58-90, 638, 882, 1230`; verificador de agregar |
| **PROMO-STACK-01** | 🟣 | Media | Combo + promo se apilan | Script C |
| **PROMO-DEL-01** | ✅ | — | Borrado de promo deja referencias abiertas en NULL por FK | Migración 089 |
| **PROMO-MANUAL-01** | ✅ | — | Descuento manual limpia `promocion_id` | `pedidos-descuento.service.ts:126` |

**Duplicado intencional:** `estados_promociones` conserva la regla porcentual/monto fijo y `pedidos` conserva el snapshot aplicado. Al cambiar líneas, la ruta lee la definición vinculada (incluida si fue desactivada) para recalcular el descuento; la desactivación no reescribe pedidos abiertos. La aplicación inicial y el cambio posterior de líneas son operaciones distintas.

**Regla por confirmar:** si la promoción se desactiva mientras el pedido sigue abierto, agregar/editar/eliminar líneas conserva la referencia de promo y el helper no requiere `activa=true`; por tanto la tasa puede aplicarse a las líneas modificadas del pedido existente. Alta de pedidos nuevos valida vigencia por separado. Esto puede ser el comportamiento intencional del snapshot, pero falta decisión de producto y E2E desactivar→cambiar líneas; no tratarlo como defecto resuelto por el test de add actual.

---

## Ruta 4 — Inventario → Productos → Cocina

### ¿Se refleja?

| Trigger | `productos.disponible` | Menú cliente/POS | KDS |
|---------|------------------------|------------------|-----|
| Ajuste admin stock | Cascade **completa** por ingrediente (+ subrecetas) | RT + cache bust | Tickets existentes quedan |
| Venta / descuento pedido | Solo marca **el** `producto_id` de la línea si stock≤0 | RT parcial | Sin efecto en tickets ya tomados |
| Cocina N/D | Marca producto fuera de menú al producir merma | — | Ítem marcado como no disponible |

### Hallazgos

| ID | Estado | Sev | Hallazgo | Evidencia |
|----|--------|-----|----------|-----------|
| **CONS-STOCK-CASCADE-01** | ✅ | Alta | La venta actualiza disponibilidad de todos los productos que comparten ingredientes modificados | `pedidos-inventario.service.ts:567-585`; `CatalogoDisponibilidadService` |
| **CONS-NODISP-STOCK-01** | ✅ | Media | Cocina registra merma y marca producto fuera de menú cuando stock ya fue descontado | `cocinas.service.ts:394-450`; `pedidos-inventario.service.ts:658-688` |
| **RT-CHAN-01** | ✅ | — | Topics duales menú | AUDITORIA_REALTIME |
| **RT-FALL-01** / **RT-RECON-01** | 🟣 | Media/Alta | Menú/POS sin poll / sin refetch → UI stale | AUDITORIA_REALTIME |
| Inventario admin cascade | ✅ | — | Script inventario-ciclo + `sincronizarPorIngrediente` | Prompt 14 |

**Usuario ve distinto:** Inventario (stock) ≠ Menú admin (`disponible`) ≠ Cliente (cache/RT) ≠ KDS (ítems ya pedidos).

---

## Ruta 5 — Caja → Reportes

### Universos de “ventas”

| Superficie | Fuente | Incluye abiertos / prepago |
|------------|--------|----------------------------|
| Caja turno | `movimientos_caja` | Solo lo cobrado (o venta al crear) |
| Reportes `ventas_total` | `SUM(pedidos.total)` excl. cancel/rechazo | **Sí** (mesa abierta, prepago `en_cocina`, etc.) |
| Cuadre reportes | pedidos − movimientos | Diferencia **esperable** |
| Dashboard `ventas_hoy` | Similar pedidos + riesgo TZ | Puede ≠ reportes de noche |
| Analítica resumen | Pedidos + filtros | ≈ reportes (hoy demo OK) |

### Hallazgos

| ID | Estado | Sev | Hallazgo | Evidencia |
|----|--------|-----|----------|-----------|
| **CONS-REP-OPEN-01** | ✅ | Media | Etiquetas + `nota_universos` (tickets ≠ cobrado); UI Reportes | `reportes.service.ts` · `reportes_admin_screen` |
| **CONS-CUADRE-SQL-01** | ✅ | Media | Script usa neto venta−devolución + mismos filtros fecha API | `verificar-cuadre-caja.ps1` OK |
| **PED-PREPAGO-01** | ✅ | — | Cierre de caja ya excluye pedidos totalmente pagados aunque sigan en cocina; la definición contable de abiertos/ventas se sigue auditando en FIN-REC-OPEN-01 | Path 1 |
| **DASH-TZ-01** | 🟣 | Media | `created_at::date` vs Bogota | AUDITORIA_DASHBOARD |
| **DASH-RT-01** | 🟣 | Media | Dashboard snapshot; caja RT | AUDITORIA_DASHBOARD |
| **DASH-ORPH-02** | 🟣 | Media | KPI Ventas → navega Caja (universo distinto) | AUDITORIA_DASHBOARD |
| **CAJ-DOM-IMPAGO-01** | 🟡 | Media | Domi parcial bloquea cierre; reportes pueden sumar | AUDITORIA_CAJA |
| KPI 7d analítica ≈ financiero | ✅ | — | Ambos **438175** esta sesión | coherencia-pedidos-analitica |

**¿Misma pantalla distinta cifra?** Sí: Caja viva vs Dashboard/Reportes (universo + frescura + TZ).

---

## Ruta 6 — Configuración → Todos los módulos

| Config | ¿Propagación live? | Módulos |
|--------|-------------------|---------|
| Horarios sede | Sí (bust cache menú) | Pedidos / menú |
| Fiscal IVA | Siguiente HTTP; pedidos viejos snapshot | Pedidos / FE |
| Fiado / flags caja-domi | Siguiente acción | Caja / estado |
| Márgenes sede | Costeo lee BD | **Sin UI/API write** |
| `configuracion_global_foody` | **Casi muerta** | Alertas / dispatch |

### Hallazgos

| ID | Estado | Sev | Hallazgo | Evidencia |
|----|--------|-----|----------|-----------|
| **CFG-GLOBAL-DEAD** | ✅ | **Alta** | `ConfiguracionGlobalService` carga BD → `UMBRALES_ALERTA` + dispatch (F3) | `verificar-f3-confianza.ps1` |
| **CFG-MARGEN-UI-02** | 🟣 | Media | Márgenes sede sin panel | costeo lee; sin PATCH |
| **CONS-CFG-NO-RT-01** | 🟣 **NEW** | Baja | Sin broadcast config; roles ven cambio en próximo fetch; menú cliente TTL | AUDITORIA_CONFIGURACION |
| **AQ-DUP-07** | 🟣 | Media | Fórmulas costeo también en Flutter → desalineación | AUDITORIA_ARQUITECTURA_CALIDAD |
| Horario → menú cache | ✅ | — | Bust en cambio horario | CFG audit |

---

## Eventos que deberían propagarse y no (o a medias)

| Evento | Emisor | Esperado | Real |
|--------|--------|----------|------|
| Ítem N/D cocina | Cocinas | No ajusta importe; deja pedido listo | Merma + fuera de menú; total original pendiente de resolución |
| Config global | Super | Alertas/dispatch | No (**CFG-GLOBAL-DEAD**) |
| Corte Realtime | RT | Refetch | No (**RT-RECON-01**) |
| Cobro prepago | Crear | Estado `pagado` o excluir de abiertos | Queda `en_cocina` (**PED-PREPAGO**) |
| Add/delete/update ítems + % promo | Items | Recalcular descuento desde la promoción vinculada | Implementado; verificador de integración cubre add; delete/update llaman el mismo helper |

---

## Información duplicada que puede desincronizarse

| Par / trío | ¿Desync? | Notas |
|------------|----------|-------|
| `pedidos.estado` ↔ `pedido_items.estado_cocina` | **Sí** | COC-NODISP + CONS-KDS-UI |
| `monto_pagado` + movs caja ↔ `estado` | **Sí** | PED-PREPAGO |
| `productos.disponible` ↔ stock insumos | **Sí** | CONS-STOCK-CASCADE |
| `pedidos.descuento` ↔ promoción | Snapshot intencional | En cambios de línea, helper recalcula % o limita monto fijo desde la promoción vinculada |
| `pi.costo_unitario` / `margenes_venta` / costo actual | **Sí** | CONS-COSTO-SNAPSHOT |
| RT buffer ↔ UI | **Sí** | RT-RECON / DASH-RT |

---

## Tooling / scripts (meta)

| ID | Estado | Sev | Hallazgo | Evidencia |
|----|--------|-----|----------|-----------|
| **CONS-SCRIPT-01** | ✅ | Baja | `verificar-coherencia-pedidos-analitica.ps1` llamaba `GET /caja/estado` (404); ruta real `GET /caja/activa/:sucursal_id`. Línea muerta eliminada (no se usaba el resultado). | Script · `caja.controller.ts:27` |

---

## Combinaciones que rompen consistencia del sistema

1. **Para llevar prepago en cocina** → sigue en flujo operativo pero su saldo cero no bloquea cierre; al quedar todos los ítems listos pasa a `pagado` (PED-PREPAGO-01 cerrado).
2. **Ítem `no_disponible`** → pedido queda `listo` cuando las demás líneas terminan, pero conserva el total original y carece de flujo de sustitución/ajuste/devolución (COC-NODISP-COMMERCE-01).  
3. La cascada de disponibilidad de insumos compartidos ya corre en la transacción de venta; falta ampliar regresión QA para varios productos hermanos.
4. **Editar umbrales en Foody Control** → alertas/dispatch no cambian (CFG-GLOBAL-DEAD).  
5. **% promo + cambios en líneas** → helper compartido conserva la regla porcentual o monto fijo en add/delete/update (CONS-PROMO-ADD-01 ✅); la integración registrada comprueba agregar líneas.  
6. **Dashboard vs Caja a la misma hora** → cifras distintas (universo + sin poll + TZ).

---

## Prioridad de remediación

| Prio | ID | Fix sugerido |
|-----:|----|--------------|
| 1 | FIN-REC-OPEN-01 | Definir el periodo de reconocimiento contable (pedido confirmado, entregado o cobrado) y conciliar abonos, impagos y devoluciones; no confundir con bloqueo de caja resuelto en PED-PREPAGO-01 |
| 2 | COC-NODISP-COMMERCE-01 | Definir e implementar confirmación, sustitución o ajuste de línea con conciliación de abonos, Caja y factura |
| 3 | CONS-STOCK-CASCADE-01 | ✅ resuelto en código; conservar regresión por insumos compartidos |
| 4 | CFG-GLOBAL-DEAD | Leer claves en alertas/dispatch **o** ocultar UI |
| 5 | CONS-NODISP-STOCK-01 | ✅ merma + off menú; verificar anulaciones en estado mixto |
| 6 | CONS-PROMO-ADD-01 | ✅ Corregido en fuente; mantener regresión integrada y ampliar casos específicos para eliminar/editar líneas |
| 7 | CONS-REP-OPEN-01 + DASH-ORPH-02 | Etiquetar “tickets” vs “cobrado”; deep-link correcto |
| 8 | RT-RECON-01 | Refetch on reconnect |
| 9 | CONS-SCRIPT-01 | Arreglar path en script coherencia |

---

## Qué está bien (no reabrir)

- Happy path mesa: stock al activar cocina, cobro → caja, historial, mesa libre.  
- Promo desactivar + precios catálogo con pedidos abiertos (snapshots).  
- Inventario admin → cascade completa + alerta stock bajo.  
- Sin doble cobro neto > total pedido (`verificar-caja-coherencia`).  
- KPI analítica 7d ≈ reportes financiero (misma sesión).  
- RT canales menú duales (RT-CHAN-01 corregido).

## Addendum de verificación actual (2026-11-24)

El código actual resuelve COC-NODISP-01, CONS-NODISP-STOCK-01, CONS-KDS-UI-01, CONS-STOCK-CASCADE-01 y CONS-PROMO-ADD-01; no deben seguir figurando como defectos abiertos. Para promociones, `PedidosItemsService` comparte el recálculo en agregar, eliminar y actualizar; `verificar-cons-promo-cfg-patch.ps1` valida el caso de agregar. Resta ampliar QA específico de editar/eliminar. E2E cocina 4/4 cubre transición, bloqueo de despacho y eliminación N/D sin restaurar stock. Resta COC-NODISP-COMMERCE-01: total/pago de una línea no servida sin reconciliación. La batería QA `verificar-todos-e2e.ps1` pasó 9/9 scripts; suite Jest 8/8 suites, 27/27; unitarias 31/31 suites, 72/72; Flutter de pedido/mesa/KDS 50/50. Los detalles del flujo y alcance contable están en `AUDITORIA_PEDIDOS_CICLO_VIDA.md`.
