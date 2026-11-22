# Foody — Auditoría UX por pantalla

> Análisis de experiencia de usuario (sin código).  
> Base para `FRONTEND_FRICTION_FIXES.md` y `FRONTEND_ACCESOS_RAPIDOS.md`.  
> **Última actualización:** 2026-07-02

---

## Metodología

Por cada pantalla/rol se documenta:

- **Objetivo** — qué debe lograr el usuario
- **Tarea principal** — acción más frecuente
- **Pasos actuales** — cuántos taps/clics
- **Fricción** — dolor, confusión, riesgo operativo
- **Intuitividad** — escala 1–5 (5 = obvio sin manual)
- **Mejoras sugeridas** — enlazadas a IDs en otros docs

---

## Resumen ejecutivo

| Rol | Intuitividad media | Principal fricción |
|-----|-------------------|-------------------|
| Cliente web | 4/5 | Carrito sin +; factura en checkout; errores técnicos |
| Mesa QR | 4/5 | Salida de sesión poco clara (post pulido UX-003) |
| Admin/gerente | 3/5 | Sidebar largo; pocos enlaces cruzados |
| Cajero | 3/5 | Cobro mesa complejo; tabs sin caja |
| Mesero | 4/5 | QR en tab correcto (✅ UX-005); grid mesas distinto al cajero |
| Cocina KDS | 5/5 | Referencia de simplicidad |
| Domiciliario | 4/5 | GPS chip ✅ UX-006 |
| Super admin | 3/5 | Muchos formularios; sin wizard |

**Top 8 quick wins:** ver `FRONTEND_ROADMAP.md` Fase 1 + `FRONTEND_FRICTION_FIXES.md`.

---

## Cliente (flavor `cliente`)

### Splash / Ciudades / Restaurantes / Sucursales

| Campo | Valor |
|-------|-------|
| Objetivo | Llegar al menú de la sede deseada |
| Tarea | Elegir ciudad → restaurante → sucursal |
| Pasos | 3–4 pantallas |
| Fricción | Si solo hay 1 sede, paso redundante (→ FF-06) |
| Intuitividad | 4/5 |
| Mejoras | Auto-skip sucursal única; recordar última sede |

### Menú (`menu_screen_foody`)

| Campo | Valor |
|-------|-------|
| Objetivo | Armar pedido |
| Tarea | Buscar producto → agregar al carrito |
| Pasos | 2+ por ítem |
| Fricción | Sin botón + en carrito (→ FF-02); toppings en sheet |
| Intuitividad | 4/5 |
| Mejoras | +/− en carrito; badge stock bajo solo staff |

### Carrito / Checkout

| Campo | Valor |
|-------|-------|
| Objetivo | Confirmar pedido y pago |
| Tarea | Revisar ítems → datos → pagar |
| Fricción | Bloque factura siempre visible (→ FF-03); totales vienen del API ✅ |
| Intuitividad | 3/5 |
| Mejoras | Factura colapsable; resumen sticky en móvil |

### Seguimiento pedido

| Campo | Valor |
|-------|-------|
| Objetivo | Saber estado y cancelar si aplica |
| Tarea | Ver timeline; cancelar ≤2 min |
| Fricción | Baja tras UX-001 |
| Intuitividad | 5/5 |
| Mejoras | Link «Volver al menú»; reordenar (AR-23) |

### Mesa QR (sesión confinada)

| Campo | Valor |
|-------|-------|
| Objetivo | Pedir a la mesa sin salir del contexto |
| Tarea | Menú → carrito → confirmar |
| Fricción | Banner cuenta ✅ UX-002; salida explícita (→ FF-01) |
| Intuitividad | 4/5 |
| Mejoras | «Terminé» / liberar mesa con copy claro |

### Mis pedidos / Escanear QR

| Campo | Valor |
|-------|-------|
| Objetivo | Historial o entrar por QR |
| Fricción | Oculto en sesión mesa ✅ UX-003 |
| Intuitividad | 4/5 |

---

## Staff — Admin / Gerente (`panel_foody_control`)

### Shell y navegación

| Campo | Valor |
|-------|-------|
| Objetivo | Operar el restaurante |
| Tarea | Ir al módulo del momento |
| Pasos | 1–2 (sidebar + subsección) |
| Fricción | 20+ ítems sin búsqueda ni favoritos (→ AR-28, AR-29) |
| Intuitividad | 3/5 |
| Mejoras | Búsqueda global; 3 favoritos; agrupar Inventario/Analítica |

### Dashboard

| Campo | Valor |
|-------|-------|
| Objetivo | Vista del día |
| Fricción | KPIs no navegan (→ FF-04) |
| Intuitividad | 3/5 |

### Pedidos (kanban)

| Campo | Valor |
|-------|-------|
| Objetivo | Mover pedidos por estado |
| Intuitividad | 4/5 |
| Mejoras | Tap pedido → mesa (AR-01), caja (AR-17), factura (AR-18) |

### Mesas (admin)

| Campo | Valor |
|-------|-------|
| Objetivo | Estado mesas, cobro, QR |
| Fricción | Cobro con muchas opciones (→ FF-07) |
| Intuitividad | 3/5 |
| Mejoras | Modo simple «Cobrar todo»; split en avanzado |

### Menú / Productos

| Campo | Valor |
|-------|-------|
| Objetivo | CRUD productos y precios |
| Fricción | Receta y margen en otro módulo (→ AR-10, AR-11) |
| Intuitividad | 3/5 |

### Inventario (múltiples tabs)

| Campo | Valor |
|-------|-------|
| Objetivo | Stock, movimientos, recetas |
| Fricción | Demasiadas tabs; saltos entre insumo y movimiento (→ AR-14) |
| Intuitividad | 2/5 |

### Caja / Reportes / CxC / Facturación

| Campo | Valor |
|-------|-------|
| Objetivo | Dinero y documentos |
| Fricción | Pocos enlaces pedido↔factura (→ AR-18, AR-19) |
| Intuitividad | 3/5 |
| Nota | Facturación DIAN 🚫 pausada |

### Alertas

| Campo | Valor |
|-------|-------|
| Objetivo | Resolver incidencias |
| Fricción | No lleva a entidad (→ AR-32) |
| Intuitividad | 3/5 |

---

## Staff — Cajero (`panel_cajero`)

| Campo | Valor |
|-------|-------|
| Objetivo | POS y cobro mesas |
| Tabs | POS · Mesas · (otro según build) |
| Fricción | Sin caja → snackbar ✅ UX-004; cobro mesa complejo |
| Intuitividad | 3/5 |
| Mejoras | Mismo grid que mesero; FF-07 |

---

## Staff — Mesero (`panel_mesero`)

| Campo | Valor |
|-------|-------|
| Objetivo | Mesas + pedidos + QR |
| Fricción | Baja tras banner QR ✅ UX-005 |
| Intuitividad | 4/5 |
| Mejoras | Aprobar QR rápido (AR-03) |

---

## Staff — Cocina (`panel_cocina` / KDS)

| Campo | Valor |
|-------|-------|
| Objetivo | Preparar pedidos |
| Intuitividad | **5/5** — referencia UX del producto |
| Mejoras | Mínimas; mantener simplicidad al copiar patrón |

---

## Domiciliario / Repartidor

| Campo | Valor |
|-------|-------|
| Objetivo | Asignación y entrega |
| Fricción | Baja; GPS chip ✅ UX-006 |
| Intuitividad | 4/5 |

---

## Super admin (`foody-control`)

| Campo | Valor |
|-------|-------|
| Objetivo | Restaurantes, planes, usuarios plataforma |
| Fricción | Formularios largos sin wizard (→ AR-37) |
| Intuitividad | 3/5 |

---

## Principios UX Foody (para implementar)

1. **Flutter solo muestra** — totales y reglas vienen del API.
2. **Un tap menos** — preferir enlace directo a pantalla relacionada.
3. **Modo simple / avanzado** — cobro mesa, split, factura.
4. **Mismo patrón entre roles** — grids de mesas, colores `ColoresFoody`.
5. **Errores humanos** — sin «Docker», «500», «DioException» al cliente final.
6. **KDS como estándar** — pocas decisiones por pantalla en operación.

---

## Referencias

- Backlog atajos: `FRONTEND_ACCESOS_RAPIDOS.md`
- Fixes concretos: `FRONTEND_FRICTION_FIXES.md`
- Fases: `FRONTEND_ROADMAP.md`
- Botones/API: `docs/archivo/auditorias-prompts/AUDITORIA_PANTALLAS_BOTONES.md`
