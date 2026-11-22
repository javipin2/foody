# Foody — Accesos rápidos (backlog cross-módulo)

> Última actualización: 2026-07-22  
> Enlaces y atajos entre pantallas. IDs **AR-XX**.  
> Prioridad: **P0** operación diaria · **P1** catálogo/finanzas · **P2** admin/super · **P3** nice-to-have  
> **Seguimiento nav admin:** [`FRONTEND_AUDITORIA_NAV_ADMIN.md`](FRONTEND_AUDITORIA_NAV_ADMIN.md) (NAV-ADM-01…24)

### Leyenda estado

| Estado | Significado |
|--------|-------------|
| ⏳ | Pendiente |
| 🔄 | En implementación |
| ✅ | Hecho |
| 🟡 | Parcial (existe; falta pulir — ver NAV-ADM) |
| 🚫 | Bloqueado / no aplica |

---

## P0 — Operación (Fase 2)

| ID | Desde | Hacia | Descripción | Estado |
|----|-------|-------|-------------|--------|
| AR-01 | Kanban pedido | Mesa (grid/detalle) | «Ver mesa» si `mesa_id` | ✅ |
| AR-02 | Mesa ocupada | Pedidos filtrados mesa | Ver todos los pedidos de esa mesa | ⏳ |
| AR-03 | Tile QR pendiente (mesero) | Aprobar/rechazar inline | Banner Revisar abre mesa (NAV-ADM-04); aprobar inline sigue ⏳ | 🟡 |
| AR-04 | Pedido cocina (KDS) | Detalle ítems / notas | Expandir o sheet ligero | ⏳ |
| AR-05 | Caja movimiento | Pedido origen | Tap movimiento con `pedido_id` → pedidos (NAV-ADM-13) | ✅ |
| AR-06 | Mesa → Cobrar | Caja / método pago | Modo caja + Cobrar todo · $ (NAV-ADM-06); FF-07 | ✅ |
| AR-07 | Alerta stock bajo | Insumo + compra sugerida | Desde alertas inventario → **NAV-ADM-14** | ⏳ |
| AR-08 | Domicilio kanban | Mapa / repartidor | Ver asignación activa | ⏳ |

---

## P0 — Cliente

| ID | Desde | Hacia | Descripción | Estado |
|----|-------|-------|-------------|--------|
| AR-20 | Seguimiento | Menú misma sede | «Pedir algo más» | ⏳ |
| AR-21 | Seguimiento | Soporte / teléfono sede | Si API expone contacto | ⏳ |
| AR-22 | Menú | Carrito flotante | Badge + tap siempre visible | 🟡 revisar |
| AR-23 | Mis pedidos | Reordenar | Último pedido → carrito (API preview) | ⏳ |
| AR-24 | QR escaneado | Menú mesa directo | Ya existe; validar en QA F0 | 🟡 |

---

## P1 — Catálogo e inventario (Fase 3)

| ID | Desde | Hacia | Descripción | Estado |
|----|-------|-------|-------------|--------|
| AR-10 | Producto menú | Receta | 1 tap «Ver receta» | ⏳ |
| AR-11 | Producto menú | Margen / costeo | KPI si módulo costeo activo | ⏳ |
| AR-12 | Producto no disponible | Insumo faltante | «Por qué no disponible» | ⏳ |
| AR-13 | Receta | Productos que la usan | Lista inversa | ⏳ |
| AR-14 | Insumo | Movimientos filtrados | Historial solo ese insumo | ⏳ |
| AR-15 | Producción lote | Insumos consumidos | Drill-down movimiento | ⏳ |
| AR-16 | Traslado entre sedes | Detalle + estado | Seguimiento traslado | ⏳ |

---

## P1 — Finanzas

| ID | Desde | Hacia | Descripción | Estado |
|----|-------|-------|-------------|--------|
| AR-17 | Pedido | Movimiento caja | «Ir a caja» desde sheet kanban (NAV-ADM-02); link movimiento↔pedido sigue pendiente | 🟡 |
| AR-18 | Pedido | Factura borrador | Sheet → facturación + banner Emitir (NAV-ADM-02) | ✅ |
| AR-19 | Factura lista | Pedido origen | Icono Ver pedido (NAV-ADM-17) | ✅ |
| AR-25 | CxC cliente | Pedidos deuda | Lista pedidos fiado | ⏳ |
| AR-26 | Cierre caja | Reporte del día | PDF o pantalla reporte | ⏳ |
| AR-27 | Cuadre | Movimientos discrepancia | Filtrar diferencias | ⏳ |

---

## P1 — Admin shell

| ID | Desde | Hacia | Descripción | Estado |
|----|-------|-------|-------------|--------|
| AR-28 | Cualquier pantalla admin | Búsqueda global | Pedido #, mesa, módulo + deep-link pedido (NAV-ADM-08) | ✅ |
| AR-29 | Sidebar | Favoritos (3 pins) | ★ visible + rail tablet (NAV-ADM-01) | ✅ |
| AR-30 | Usuario staff | Auditoría filtrada | Ver acciones de ese usuario | ⏳ |
| AR-31 | Horario sede | «Cerrado ahora» en cliente | Coherencia menú público → **NAV-ADM-21** | ⏳ |
| AR-32 | Alerta genérica | Entidad (`pedido`, `mesa`, `insumo`) | Deep link si hay ref; SnackBar si no (NAV-ADM-18) | ✅ |

---

## P2 — Multi-sucursal y super

| ID | Desde | Hacia | Descripción | Estado |
|----|-------|-------|-------------|--------|
| AR-33 | Selector sucursal | Inventario otra sede (solo lectura) | Ya parcial en backend | ⏳ |
| AR-34 | Comparativa sedes | Drill-down sede | Desde analítica multi | ⏳ |
| AR-35 | Super: restaurante | Sucursales lista | Acceso rápido sedes | ⏳ |
| AR-36 | Super: suscripción | Restaurante afectado | Link bidireccional | ⏳ |
| AR-37 | Super: nuevo restaurante | Wizard pasos | Onboarding guiado | ⏳ |
| AR-38 | Super: impersonar | Panel admin restaurante | Solo super, auditado | ⏳ |

---

## P2 — Staff cruzado

| ID | Desde | Hacia | Descripción | Estado |
|----|-------|-------|-------------|--------|
| AR-39 | Mesero mesa | Compartir QR | Copiar link / mostrar QR grande | ⏳ |
| AR-40 | Admin pedido | Notificar cocina | Si quedó atascado (manual) | ⏳ |

---

## Plantilla para nuevos ítems

```markdown
### AR-XX — Título corto

| Campo | Detalle |
|-------|---------|
| Prioridad | P0 / P1 / P2 |
| Desde | pantalla / widget |
| Hacia | ruta destino |
| Criterio | qué ve el usuario al completar |
| API | endpoint si hace falta dato nuevo |
| Archivos | `lib/features/...` (rellenar al implementar) |
| Estado | ⏳ |
```

---

## Implementación (notas técnicas)

- Usar `go_router` con query params para filtros (`?mesa_id=`, `?pedido_id=`).
- No duplicar lógica: reutilizar repositories existentes.
- Si falta dato en API, ticket backend separado — Flutter no inventa IDs.
- Cada AR cerrado: marcar ✅ aquí + fase en `FRONTEND_ROADMAP.md`.

---

## Resumen por prioridad

| Prioridad | Total | Hechos |
|-----------|------:|-------:|
| P0 | 12 | 0 |
| P1 | 18 | 0 |
| P2 | 10 | 0 |
| **Total** | **40** | **0** |
