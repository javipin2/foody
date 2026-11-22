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
| Pedido → Cocina → Caja → Inventario → Análisis | 🟡 | Prepago + `no_disponible` + universos venta |
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

## Ruta 1 — Crear pedido → Cocina → Caja → Inventario → Análisis

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
| **PED-PREPAGO-01** | 🟣 | Alta | Cobrado al crear pero estado `en_cocina` → bloquea cierre caja; cobro posterior `SIN_SALDO` | `pedidos-caja-auditoria.service.ts:35-48` · AUDITORIA_PEDIDOS |
| **COC-NODISP-01** | 🟣 | Alta | `no_disponible` no cuenta para pedido `listo` → pedido trabado en `en_cocina` | `cocinas.service.ts:379-399` |
| **CONS-NODISP-STOCK-01** | 🟣 **NEW** | Media | Marcar N/D en cocina **no** restaura stock ni desmarca catálogo | `cocinas.service.ts:355-377` (solo alerta/impresión) |
| **CONS-KDS-UI-01** | 🟣 **NEW** | Media | KDS trata `listo\|\|no_disponible` como “fuera de cocina”; BD pedido puede seguir `en_cocina` | `kds_screen.dart:838-841` vs Nest L393-398 |
| **CONS-COSTO-SNAPSHOT-01** | ✅ | Media | Canon documentado en API; ledger sync al editar qty | `verificar-cons-costo-snapshot.ps1` |
| **CONS-MARGEN-STALE-01** | ✅ | Baja | `UPDATE margenes_venta` en `actualizarItemPedido` | `pedidos-items.service.ts` |
| **ANA-FILT-PROD-01** | 🟣 | Media | Filtro producto suma total pedido, no líneas | AUDITORIA_REPORTES |
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
| **COC-NODISP-01** + **CONS-KDS-UI-01** | 🟣 | Alta/Media | Mesero/caja ven `en_cocina`; KDS puede mostrar ticket “cerrado” | Path 1 |
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
| **Agregar ítems** con % promo | Descuento **absoluto** reusado | — | % efectivo baja |

### Hallazgos

| ID | Estado | Sev | Hallazgo | Evidencia |
|----|--------|-----|----------|-----------|
| **PROMO-SNAP-01** | ✅ | — | Desactivar no recalcula abiertos | `verificar-promociones-precios` A |
| **PRECIO-COBRO-01** | ✅ | — | Cobro = snapshot | Script B |
| **CONS-PROMO-ADD-01** | ✅ | Media | Add/delete/update ítems: `recalcularDescuentoTrasCambioSubtotal` reaplica % o topea monto fijo | `pedidos-items.service.ts` + `verificar-cons-promo-cfg-patch.ps1` |
| **PROMO-STACK-01** | 🟣 | Media | Combo + promo se apilan | Script C |
| **PROMO-MANUAL-01** | 🟡 | Baja | Descuento manual puede dejar `promocion_id` | AUDITORIA_PROMOCIONES |

**Duplicado intencional:** `estados_promociones` (vivo) vs columnas snapshot en `pedidos` — OK salvo CONS-PROMO-ADD y UX stories vs ticket.

---

## Ruta 4 — Inventario → Productos → Cocina

### ¿Se refleja?

| Trigger | `productos.disponible` | Menú cliente/POS | KDS |
|---------|------------------------|------------------|-----|
| Ajuste admin stock | Cascade **completa** por ingrediente (+ subrecetas) | RT + cache bust | Tickets existentes quedan |
| Venta / descuento pedido | Solo marca **el** `producto_id` de la línea si stock≤0 | RT parcial | Sin efecto en tickets ya tomados |
| Cocina N/D | No cambia catálogo | — | Ítem marcado |

### Hallazgos

| ID | Estado | Sev | Hallazgo | Evidencia |
|----|--------|-----|----------|-----------|
| **CONS-STOCK-CASCADE-01** | 🟣 **NEW** | Alta | Tras venta: `UPDATE productos SET disponible=false WHERE id=$linea` — **no** llama `CatalogoDisponibilidadService.sincronizarPorIngrediente` | `pedidos-inventario.service.ts:567-576` vs `catalogo-disponibilidad.service.ts:39-80` |
| **CONS-NODISP-STOCK-01** | 🟣 | Media | N/D cocina ≠ devolver stock / off menú | Path 1 |
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
| **PED-PREPAGO-01** | 🟣 | Alta | Alimenta el gap caja↔reportes↔cierre | Path 1 |
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
| Stock agotado por venta (hermanos) | Pedidos invent. | Cascade completa | Solo producto línea (**CONS-STOCK-CASCADE-01**) |
| Ítem N/D cocina | Cocinas | Stock/menú/pedido `listo` | Solo alerta (**CONS-NODISP-STOCK** + **COC-NODISP**) |
| Config global | Super | Alertas/dispatch | No (**CFG-GLOBAL-DEAD**) |
| Corte Realtime | RT | Refetch | No (**RT-RECON-01**) |
| Cobro prepago | Crear | Estado `pagado` o excluir de abiertos | Queda `en_cocina` (**PED-PREPAGO**) |
| Add ítems + % promo | Items | Reaplicar % | Descuento fijo (**CONS-PROMO-ADD**) |

---

## Información duplicada que puede desincronizarse

| Par / trío | ¿Desync? | Notas |
|------------|----------|-------|
| `pedidos.estado` ↔ `pedido_items.estado_cocina` | **Sí** | COC-NODISP + CONS-KDS-UI |
| `monto_pagado` + movs caja ↔ `estado` | **Sí** | PED-PREPAGO |
| `productos.disponible` ↔ stock insumos | **Sí** | CONS-STOCK-CASCADE |
| `pedidos.descuento` ↔ promo viva | Intencional | CONS-PROMO-ADD debilita |
| `pi.costo_unitario` / `margenes_venta` / costo actual | **Sí** | CONS-COSTO-SNAPSHOT |
| RT buffer ↔ UI | **Sí** | RT-RECON / DASH-RT |

---

## Tooling / scripts (meta)

| ID | Estado | Sev | Hallazgo | Evidencia |
|----|--------|-----|----------|-----------|
| **CONS-SCRIPT-01** | ✅ | Baja | `verificar-coherencia-pedidos-analitica.ps1` llamaba `GET /caja/estado` (404); ruta real `GET /caja/activa/:sucursal_id`. Línea muerta eliminada (no se usaba el resultado). | Script · `caja.controller.ts:27` |

---

## Combinaciones que rompen consistencia del sistema

1. **Para llevar efectivo al crear** → venta en caja + estado `en_cocina` → **no cierra caja** (PED-PREPAGO-01).  
2. **Último ítem `no_disponible`** → pedido nunca `listo`; KDS lo da por cerrado; stock no vuelve (COC-NODISP + CONS-*).  
3. **Agotar insumo compartido vía venta** → un producto off, hermano aún on en menú (CONS-STOCK-CASCADE-01).  
4. **Editar umbrales en Foody Control** → alertas/dispatch no cambian (CFG-GLOBAL-DEAD).  
5. **% promo + agregar ítems** → descuento relativo diluido; caja cobra total “raro” vs % (CONS-PROMO-ADD-01).  
6. **Dashboard vs Caja a la misma hora** → cifras distintas (universo + sin poll + TZ).

---

## Prioridad de remediación

| Prio | ID | Fix sugerido |
|-----:|----|--------------|
| 1 | PED-PREPAGO-01 | Tras venta al crear → `pagado` **o** excluir de `OPERACION_ABIERTA` |
| 2 | COC-NODISP-01 + CONS-KDS-UI-01 | Contar N/D como resuelto al recalc pedido; alinear UI |
| 3 | CONS-STOCK-CASCADE-01 | Tras descontar, llamar `sincronizarPorIngrediente` por cada insumo tocado |
| 4 | CFG-GLOBAL-DEAD | Leer claves en alertas/dispatch **o** ocultar UI |
| 5 | CONS-NODISP-STOCK-01 | Política: restaurar / merma / off menú |
| 6 | CONS-PROMO-ADD-01 | Reaplicar % o bloquear add si hay promo % |
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
