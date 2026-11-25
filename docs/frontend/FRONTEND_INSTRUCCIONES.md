# Foody — Instrucciones de producto (frontend)

> **Documento vivo:** aquí se registran las instrucciones que el producto/negocio da para el frontend.  
> El agente o desarrollador las traduce a ítems en `FRONTEND_ROADMAP.md`, `FRONTEND_FRICTION_FIXES.md` o `FRONTEND_ACCESOS_RAPIDOS.md`.

**Última actualización:** 2026-07-22

---

## Cómo añadir una instrucción

1. Copiar la plantilla de abajo al final de este archivo.
2. Numerar: **INS-001**, **INS-002**, …
3. En «Derivado a»: enlazar FF-XX, AR-XX, NAV-ADM-XX o Fase F-X-XX cuando se priorice.
4. Actualizar `FRONTEND_ROADMAP.md` changelog.

---

## Instrucciones registradas

### INS-000 — Meta: documentación ordenada

| Campo | Detalle |
|-------|---------|
| **Fecha** | 2026-07-02 |
| **Pedido** | Documentar todo para avanzar en frontend por pasos: qué se hace, qué se hizo, qué se hará |
| **Derivado a** | `FRONTEND_ROADMAP.md` + suite UX (auditoría, friction, accesos rápidos) |
| **Estado** | ✅ Documentación base creada |

---

### INS-010 — Auditoría navegación rol Admin (Fase 1 diagnóstico)

| Campo | Detalle |
|-------|---------|
| **Fecha** | 2026-07-22 |
| **Pedido** | Auditar pantallas del rol admin (claridad, taps, atajos, conexiones, feedback, consistency, curva, responsive Móvil/Tablet/PC). Solo diagnóstico; implementar tras aprobación, Alta primero. |
| **Derivado a** | [`FRONTEND_AUDITORIA_NAV_ADMIN.md`](FRONTEND_AUDITORIA_NAV_ADMIN.md) (NAV-ADM-01…24); índice `frontend/README.md`; sync MASTER/AVANCE/ROADMAP; AR-28/29 → 🟡 |
| **Estado** | 🟡 Diagnóstico ✅ · Aprobación e implementación ⏳ |

---

### INS-001 — Pausar facturación electrónica DIAN

| Campo | Detalle |
|-------|---------|
| **Fecha** | 2026-07-02 |
| **Pedido** | No avanzar integración DIAN; mantener borrador UI si existe |
| **Derivado a** | `FACTURACION_ELECTRONICA_PAUSADA.md`, FF-03 |
| **Estado** | ✅ Pausa documentada |

---

### INS-002 — Pulido UI pre-QA

| Campo | Detalle |
|-------|---------|
| **Fecha** | 2026-07-02 |
| **Pedido** | Cancelar 2 min, banner mesa QR, scope mesa, cajero sin caja, mesero QR, GPS domi |
| **Derivado a** | UX-001…007 en `FRONTEND_ROADMAP.md` |
| **Estado** | ✅ Implementado |

---

### INS-003 — Auditoría UX completa

| Campo | Detalle |
|-------|---------|
| **Fecha** | 2026-07-02 |
| **Pedido** | Análisis por pantalla, fricciones, 40 accesos rápidos, quick wins |
| **Derivado a** | `FRONTEND_UX_AUDITORIA.md`, `FRONTEND_ACCESOS_RAPIDOS.md`, `FRONTEND_FRICTION_FIXES.md` |
| **Estado** | ✅ Documentado (implementación en fases) |

---

### INS-004 — QA manual en navegador

| Campo | Detalle |
|-------|---------|
| **Fecha** | 2026-07-02 |
| **Pedido** | Recorrer checklist por rol antes de más features |
| **Derivado a** | Fase 0 en `FRONTEND_ROADMAP.md`, [`../CHECKLIST_QA_ROLES.md`](../CHECKLIST_QA_ROLES.md) |
| **Estado** | ⏳ Pendiente ejecución usuario |

---

### INS-009 — Auditoría Head of Product (SaaS premium)

| Campo | Detalle |
|-------|---------|
| **Fecha** | 2026-07-02 |
| **Pedido** | ¿Profesional? ¿Confianza? ¿Moderna? ¿Premium? ¿Compite comercial? Dashboards, atajos, empty states, animaciones, nota SaaS |
| **Derivado a** | `FRONTEND_PRODUCT_AUDIT.md`, Fase 10 (`PR-01`…`PR-35`) |
| **Estado** | ✅ Documentado |

---

### INS-008 — Auditoría Flutter Senior Engineer

| Campo | Detalle |
|-------|---------|
| **Fecha** | 2026-07-02 |
| **Pedido** | Widgets gigantes, duplicación, estado, performance, clean architecture, estrategia mantenible |
| **Derivado a** | `FRONTEND_FLUTTER_ARCHITECTURE.md`, Fase 9 (`FL-10`…`FL-63`) |
| **Estado** | ✅ Documentado |

---

### INS-007 — Mapa de navegación UX Architect

| Campo | Detalle |
|-------|---------|
| **Fecha** | 2026-07-02 |
| **Pedido** | Recorrer rutas; mapa navegación; huérfanas, redundantes, circulares; recorrido óptimo por rol; clics/tiempo/complejidad |
| **Derivado a** | `FRONTEND_NAVIGATION_MAP.md`, Fase 8 (`NAV-01`…`NAV-14`) |
| **Estado** | ✅ Documentado |

---

### INS-006 — Auditoría responsive completa

| Campo | Detalle |
|-------|---------|
| **Fecha** | 2026-07-02 |
| **Pedido** | Analizar mobile/tablet/desktop/web; overflow, tablas, diálogos, menús; estrategia responsive |
| **Derivado a** | `FRONTEND_RESPONSIVE_STRATEGY.md`, Fase 7 (`RS-01`…`RS-42`) |
| **Estado** | ✅ Documentado |

---

### INS-005 — Auditoría visual Product Design

| Campo | Detalle |
|-------|---------|
| **Fecha** | 2026-07-02 |
| **Pedido** | Analizar jerarquía, espaciado, tipografía, colores, componentes; calificar pantallas 1–10; benchmark Uber Eats, Toast, Square, Shopify, Rappi, Notion, Linear |
| **Derivado a** | `FRONTEND_DESIGN_AUDIT.md`, Fase 6 (`DS-01`…`DS-08`) |
| **Estado** | ✅ Documentado |

---

## Plantilla — nueva instrucción

```markdown
### INS-XXX — Título breve

| Campo | Detalle |
|-------|---------|
| **Fecha** | YYYY-MM-DD |
| **Pedido** | (texto literal o resumen del usuario) |
| **Alcance** | cliente / staff / rol específico / global |
| **Derivado a** | FF-XX, AR-XX, Fase F-X-XX, o «nuevo ítem» |
| **Criterio de hecho** | cómo sabemos que está listo |
| **Estado** | ⏳ / 🔄 / ✅ / 🚫 |
| **Notas** | dependencias, decisiones |
```

---

## Próximas instrucciones

### INS-011 — Rediseño responsive de Insumos e Inventario

| Campo | Detalle |
|-------|---------|
| **Fecha** | 2026-11-22 |
| **Pedido** | Rediseño responsive conservando comportamiento y datos reales |
| **Alcance** | Admin · Insumos e Inventario |
| **Derivado a** | UI inventario · UX-INV-REDISENO-01 |
| **Criterio de hecho** | Jerarquía visible, tabs identificables, resumen sin métricas inventadas, acción principal adaptable |
| **Estado** | ✅ Implementado; QA visual en dispositivos pendiente |
| **Notas** | Sin cambios backend, base de datos, API ni flujos |

*(El usuario añadirá más peticiones de frontend en conversaciones siguientes. Pegar aquí cada una con INS-XXX.)*

### INS-012 — Continuar rediseño del panel administrativo

| Campo | Detalle |
|-------|---------|
| **Fecha** | 2026-11-22 (continuidad 2026-11-23) |
| **Pedido** | Continuar con el diseño de las vistas restantes, preservando comportamiento y cubriendo el panel de administración completo |
| **Alcance** | Admin restaurante · responsive, componentes, formularios, estados y consistencia visual |
| **Derivado a** | `FRONTEND_DESIGN_AUDIT.md` · Fase 6/Fase 10 |
| **Criterio de hecho** | Vistas pendientes abordadas por grupos; verificación focalizada y pendientes visuales registrados |
| **Estado** | 🔄 En curso |
| **Notas** | Vistas abordadas: Inicio, Usuarios, Domiciliarios, Horarios, Sedes, Zonas, Cocinas, Alertas, Finanzas, Promociones, Reportes, Menú (incluido diálogo de precios), Costos, Inventario, Caja, Facturación, Kanban/detalle/asignación de Pedidos, grilla/detalle/diálogos de Mesas y estado vacío/ticket activo KDS. Se corrigió el shell común al hallar conflicto con `LayoutBuilder`; KDS mantiene polling si Realtime no está disponible; el detalle de mesa aplica tokens del tema. Pruebas focalizadas cubren anchos compactos/tablet/escritorio y creación/renombre con teclado simulado. Un test detectó liberación prematura del controlador al cerrar el diálogo, ahora diferida tras la transición. Pendientes: acciones reales autenticadas, KDS con Realtime/datos, formularios/estados secundarios y QA por rol/tema/dispositivo; vistas cliente/repartidor no están cerradas. |
