# Foody — Multi-sucursal (modelo operativo)

> **Fuente de verdad** para agentes y desarrollo. Acordado con el producto: cada sucursal opera como un restaurante independiente bajo la misma marca.
> Reglas resumidas: `INFRAESTRUCTURA/reglas_negocio_foody.md` § Multi-sucursal · Regla Cursor: `.cursor/rules/foody-multi-sucursal.mdc`

**Última actualización:** 2026-06-24 — P1-02 rol `gerente_cadena` + corporativo en API/UI.

---

## Resumen en 30 segundos

| Concepto | Qué es | Ejemplo |
|----------|--------|---------|
| **Restaurante** | Marca + contrato Foody (`restaurante_id`) | Alitas House |
| **Sucursal** | Unidad operativa aislada (`sucursal_id`) | Alitas House **Norte**, Alitas House **Sur** |
| **Regla de oro** | Toda operación diaria va con `sucursal_id` | Sin excepción en SELECT/INSERT/UPDATE críticos |
| **Excepción acordada** | Ver inventario de **otras** sucursales del mismo restaurante | Solo **lectura**; no mezclar stock ni contabilidad |

Norte y Sur **no comparten** staff, caja, pedidos, menú, stock ni domiciliarios de planta. Comparten solo la **marca** y la **suscripción** del restaurante.

---

## Jerarquía de datos

```
ciudades
  └── restaurantes          ← marca, suscripción, bloqueo por pago
        └── sucursales      ← TODO lo operativo vive aquí
              ├── usuarios (staff con sucursal_id fija)
              ├── menú, inventario, pedidos, caja, cocinas, mesas
              ├── domiciliarios_planta, zonas, facturación fiscal
              └── alertas, reportes, auditoría (por sucursal)
```

**Suscripción:** se cobra por **restaurante**, no por sucursal. Si el restaurante se bloquea, **todas** sus sucursales quedan inactivas (`SuscripcionActivaGuard` por `restaurante_id`).

---

## Qué es independiente por sucursal (no se mezcla)

| Dominio | Aislamiento | Notas |
|---------|-------------|-------|
| Usuarios staff | Cada usuario tiene **una** `sucursal_id` | Admin Norte ≠ admin Sur |
| Menú y precios | Catálogo propio | Mismo plato puede tener distinto precio/costo |
| Inventario / stock | Cantidades propias | Misma receta, distinto stock físico |
| Pedidos y estados | Solo de esa sucursal | Kanban, mesas, QR mesa |
| Caja y movimientos | Una caja abierta por sucursal | Cierres y cuadre por sede |
| Cocinas e impresoras | Por sucursal | KDS solo tickets de su cocina |
| Domiciliarios de planta | Una sucursal | No atienden pedidos de otra sede |
| Zonas de domicilio | Por sucursal | Radio y tarifas locales |
| Facturación / consecutivo | Por sucursal | Spec: consecutivo fiscal por sucursal |
| Reportes operativos | Por sucursal | Consolidado solo rol corporativo |
| Alertas de riesgo | Por sucursal | Ej. `intento_pedido_sin_stock` en Norte |

**Prohibido sin flujo explícito:** escribir pedidos, caja, compras o ajustes de stock en una sucursal distinta a la del usuario (salvo rol corporativo documentado).

---

## Excepción: visibilidad cruzada de inventario

### Qué sí está permitido

- Admin o gerente de **Norte** puede **consultar** (solo lectura) el inventario de **Sur** del **mismo** `restaurante_id`.
- Uso típico en cadenas:
  - Ver si la otra sede tiene insumo agotado.
  - Coordinar compras o **traslados** (futuro).
  - Comparar niveles de stock entre sedes.

### Qué no está permitido en esta excepción

- Editar stock, compras, recetas o conteos en otra sucursal.
- Descontar inventario de otra sede al vender en la propia.
- Mezclar contabilidad o caja entre sedes.

### Permiso objetivo (a implementar)

| Permiso | Efecto |
|---------|--------|
| `ver_inventario_otras_sucursales` | GET inventario de sucursales hermanas del mismo restaurante; UI comparativa; sin POST/PATCH |

Sin este permiso, el staff solo ve inventario de su `sucursal_id` del JWT.

---

## Roles (modelo objetivo)

| Rol | Alcance escritura | Cambiar sucursal en panel | Ver inventario otras sedes |
|-----|-------------------|---------------------------|----------------------------|
| `super_admin` | Todo el sistema | N/A (Foody Control) | Sí |
| `gerente_cadena` / dueño *(nuevo o evolución de admin corporativo)* | Todas las sucursales del restaurante | Sí (selector) | Sí |
| `admin` / `gerente` **de sucursal** | Solo su `sucursal_id` | **No** | Sí, si tiene permiso |
| `cajero`, `mesero`, `cocina_*` | Solo su sucursal | No | No (por defecto) |
| `domiciliario_planta` | Solo pedidos de su sucursal | No | No |
| `domiciliario_independiente` | Ofertas en su ciudad | No | No |

> **Nota de transición:** hoy `MEMORIA.md` decía «admin → todo su restaurante y sus sucursales». Eso queda **reemplazado** por este documento: el admin **de sede** no opera otras sucursales; el rol corporativo (o permisos explícitos) sí.

---

## Flujos futuros (no implementados aún)

| Flujo | Descripción | Prioridad sugerida |
|-------|-------------|-------------------|
| **Guard `SucursalScope`** | Validar en API que mutaciones usan `sucursal_id` del JWT (o rol corporativo) | Alta — Fase 1 código |
| **UI sin selector** para admin de sede | Ocultar dropdown de sucursal en `PanelRestauranteScreen` | Alta — Fase 1 |
| **Pantalla inventario hermanas** | Lista comparativa read-only Norte vs Sur | Media — Fase 1 |
| **Traslado entre sucursales** | Movimiento auditado: sale sede A, entra sede B | Media — Fase 2 |
| **Dashboard consolidado** | Ventas/alertas agregadas para `gerente_cadena` | ✅ Fase 3 — `GET /dashboard/consolidado` |
| **Menú maestro** | Plantilla de marca que cada sucursal copia | Baja — Fase 3 |

---

## Estado actual del código (brecha vs spec)

| Ítem | Estado | Riesgo |
|------|--------|--------|
| Tablas con `sucursal_id` | ✅ Diseño BD alineado | Bajo si se respeta en queries |
| JWT con `sucursal_id` + `restaurante_id` | ✅ Login staff | — |
| `SucursalScopeService` | ✅ Fase 1 | `foody_backend/src/core/auth/sucursal-scope.service.ts` |
| Guard en inventario, pedidos, dashboard, caja | ✅ Fase 1 | Otros módulos (catálogo, mesas…) en Fase 2 |
| Dropdown cambio sucursal en panel admin | ✅ Fase 1 | Solo con `gestionar_sucursales`; sede fija con chip |
| `GET /inventario/hermanas/resumen` | ✅ Fase 1 | UI `InventarioHermanasPanel` (solo lectura) |
| Permiso `ver_inventario_otras_sucursales` | ✅ Migración `043` | Aplicar SQL en BD dev |
| Traslados entre sucursales | ⏳ Fase 2 | — |
| Rol `gerente_cadena` explícito | ✅ Migración `060` + `roles-food.ts` | `gestionar_sucursales` sigue siendo alias corporativo (admin dueño) |

---

## Reglas para agentes (no negociables)

1. **Nunca** omitir `sucursal_id` en queries de datos operativos.
2. **Nunca** asumir que menú, stock o precios se comparten entre sucursales.
3. **Nunca** permitir que staff de sucursal A modifique datos de sucursal B sin guard y permiso corporativo.
4. **Sí** permitir lectura de inventario cruzado solo con `ver_inventario_otras_sucursales` y mismo `restaurante_id`.
5. **Traslados** de stock entre sedes siempre con movimiento auditado (cuando exista el módulo); nunca UPDATE directo cruzado.
6. Al implementar UI admin, mostrar siempre **qué sucursal** está activa; si es solo lectura de otra sede, etiqueta visible «Solo consulta — Sucursal Sur».

---

## Referencias

- `MEMORIA.md` — columna vertebral `sucursal_id`
- `INFRAESTRUCTURA/reglas_negocio_foody.md` — tabla de reglas multi-sucursal
- `docs/AVANCE_PROYECTO.md` — sprint y estado de implementación
- `foody_backend/src/core/auth/jwt-payload.ts` — claims del token
- `lib/features/admin/presentation/panel_restaurante_screen.dart` — selector sucursal actual
