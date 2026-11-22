# Foody — Alertas automáticas (Paso 2)

> Fuente de umbrales: `INFRAESTRUCTURA/reglas_negocio_foody.md` § Alertas de riesgo.
> Implementación: `foody_backend/src/modulos/alertas/alertas-riesgo.service.ts`

## Disparadores en tiempo real (evento → INSERT)

| Tipo | Evento | Nivel | Estado |
|------|--------|-------|--------|
| `stock_minimo_alcanzado` | Venta descuenta stock ≤ mínimo | medio | ✅ |
| `intento_pedido_sin_stock` | Cliente/staff intenta pedir y falla validación inventario | alto | ✅ |
| `descuento_manual_excesivo` | Descuento > 30% del subtotal | alto | ✅ |
| `pedido_sin_domiciliario` | 3 intentos dispatch sin asignar | alto | ✅ |
| `transferencia_mesa_multiple` | > 2 transferencias mismo pedido | bajo | ✅ Paso 2 |
| `cancelaciones_frecuentes` | ≥ 3 cancelaciones mismo usuario/día | medio | ✅ Paso 2 |
| `cuadre_caja_diferencia` | \|diferencia\| > $5.000 al cerrar caja | alto | ✅ Paso 2 |
| `demora_excesiva_entrega` | Entrega > 2× tiempo estimado | medio | ✅ Paso 2 |
| `costo_ingrediente_sube` | Compra sube costo > 15% vs anterior | bajo | ✅ Paso 2 |

## Evaluación programada (batch)

Endpoint: `POST /alertas/evaluar/:sucursal_id` (permiso `ver_alertas`).  
Umbrales: `UMBRALES_ALERTA` en `alertas-riesgo.service.ts` (**hardcode**; no leen `configuracion_global_foody` — ver **CFG-GLOBAL-DEAD** en `AUDITORIA_CONFIGURACION.md`).  
Auditoría cifras/umbrales: `docs/archivo/auditorias-prompts/AUDITORIA_REPORTES.md` (Prompt 20) · `scripts/verificar-reportes-analitica.ps1`.

| Tipo | Regla | Nivel |
|------|-------|-------|
| `margen_bajo_prolongado` | Margen < 20% promedio 7 días (≥ 3 ventas) | bajo |
| `caida_ventas_producto` | Caída > 40% vs semana anterior (≥ 5 uds previas) | bajo |
| `producto_sin_venta` | Producto disponible sin ventas en 14 días | bajo |
| `mesero_cancelacion_alta` | % cancelación mesero > 1.5× promedio sede (7d) | medio |
| (prep cocina) | Tiempo prep +30% vs semana anterior (≥ 3 muestras) | bajo |

> Stock bajo y cuadre de caja **no** van en este batch: se disparan por **evento** (descuento inventario / cierre caja).

## Pendiente / manual

| Tipo | Motivo |
|------|--------|
| Eliminación ítem post-cocina | Sin endpoint de eliminar ítem aún |
| Modificación precio fuera panel | Auditoría catálogo pendiente |
| Retiro sin autorización | Bloqueado por guard JWT (403); sin hook de intento |

## UI Flutter

`AlertasAdminScreen` — iconos por tipo, botón **Evaluar reglas** (llama POST evaluar).

## Push FCM (P1-15)

Alertas **nivel alto o crítico** → FCM a `admin` y `gerente` de la sucursal (`tipo: alerta_riesgo_*`, deep link `/admin/panel?seccion=alertas`). Se envía tras commit de la transacción que insertó la alerta (`TransactionHooksService`). Email: ⏳ pendiente.

## API existente

- `GET /alertas/:sucursal_id?solo_pendientes=true`
- `PATCH /alertas/:id/revisar?sucursal_id=...`
