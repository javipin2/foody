# Reglas de negocio — Foody
## Decisiones que definen cómo funciona el sistema

---

## Pedidos generales

| Regla | Valor | Razón |
|---|---|---|
| Tiempo mínimo para cancelar un pedido | 2 minutos desde confirmación | Después puede estar en cocina |
| Quién puede cancelar después de 2 min | Solo admin o gerente | Requiere permiso elevado |
| Precio mínimo de pedido para domicilio | Configurable por sucursal | Cada restaurante decide |
| Tiempo máximo sin actividad para cerrar sesión admin | 4 horas | Seguridad |
| Productos sin stock | Se ocultan automáticamente del menú | No se muestran como "agotados" |
| Máximo de ítems en un carrito | 50 ítems | Límite operativo razonable |

---

## Pedidos de mesa (QR)

| Regla | Valor |
|---|---|
| Tiempo para que la mesera apruebe el pedido | 3 minutos |
| Qué pasa si no aprueba en ese tiempo | Notificación de recordatorio. A los 5 min se notifica al admin |
| ¿Puede el cliente modificar el pedido después de enviarlo? | No. Debe contactar a la mesera |
| ¿Puede una mesa tener varios pedidos abiertos? | Sí, pedidos adicionales a lo largo de la visita |
| ¿Qué pasa si escanean QR de mesa ocupada? | Ven el menú igual, el pedido se agrega a la mesa activa |
| ¿Puede la mesera rechazar sin motivo? | No. Debe seleccionar un motivo de una lista |
| Motivos de rechazo disponibles | "Mesa ya fue atendida", "Mesa no disponible", "Producto no disponible", "Otro" |

---

## Domicilios — búsqueda de domiciliario

| Regla | Valor |
|---|---|
| Primero buscar | Domiciliarios de planta de la sucursal |
| Si no hay de planta | Buscar independientes en radio inicial |
| Radio inicial de búsqueda | 3 km desde la sucursal |
| Domiciliarios notificados simultáneamente | 5 más cercanos |
| Tiempo de expiración de la oferta | 60 segundos |
| Si nadie acepta | Ampliar radio 2 km y reintentar |
| Ampliaciones máximas | 3 intentos (radio final máximo: 9 km) |
| Si después de 3 intentos no hay domiciliario | Alerta crítica al admin para asignación manual |
| ¿Un domiciliario puede tener 2 pedidos activos? | No. Solo uno a la vez |

---

## Domicilios — financiero

| Regla | Valor |
|---|---|
| Comisión de Foody por entrega independiente | 15% del valor del domicilio |
| Ejemplo | Domicilio $5.000 → domiciliario recibe $4.250, Foody recibe $750 |
| Período de pago a domiciliarios | Semanal (cada lunes) |
| Calificación mínima para seguir activo | 3.5 estrellas promedio |
| Con cuántas entregas se calcula el promedio | Mínimo 10 entregas para que aplique la regla |

---

## Inventario

| Regla | Valor |
|---|---|
| ¿Cuándo se descuenta el stock? | Al confirmar el pedido, no al entregarlo |
| ¿Qué pasa si el stock llega a 0? | Producto se marca como no disponible automáticamente |
| ¿Quién puede ajustar stock manualmente? | Roles: admin, gerente, inventario |
| Todo ajuste manual requiere | Motivo obligatorio (campo de texto) |
| Alerta de stock mínimo | Cuando stock_actual <= stock_minimo configurado |
| ¿Se puede vender si el stock es 0? | No. El backend rechaza el pedido |

---

## Caja

| Regla | Valor |
|---|---|
| ¿Puede haber dos cajas abiertas al mismo tiempo en la misma sucursal? | No |
| ¿Quién puede abrir caja? | Cajero, admin, gerente |
| ¿Quién puede hacer retiro parcial? | Solo admin o gerente con permiso `hacer_retiro_parcial` |
| Umbral de diferencia en cuadre que genera alerta | Más de $5.000 de diferencia |
| ¿Se pueden registrar gastos sin caja abierta? | No |
| Método de pago por defecto | Efectivo |

---

## Descuentos

| Regla | Valor |
|---|---|
| ¿Quién puede aplicar descuentos? | Solo cajero, admin, gerente con permiso `aplicar_descuento` |
| Descuento máximo sin aprobación adicional | 20% del total del pedido |
| Descuento mayor al 20% | Requiere aprobación de admin o gerente en el momento |
| Todo descuento genera | Registro en auditoria_logs + motivo obligatorio |
| Descuento mayor al 30% | Genera alerta de riesgo nivel alto automáticamente |

---

## IVA y facturación

| Regla | Valor |
|---|---|
| ¿Cómo ve el cliente los precios? | IVA incluido siempre. Precio final sin desglose |
| ¿Cuándo aparece el IVA desglosado? | Solo en la factura electrónica cuando el cliente la solicita |
| ¿Cuándo se pide la factura? | En el checkout, campo opcional "Necesito factura" |
| Si pide factura, qué datos se le piden | NIT o cédula, nombre o razón social, email, dirección |
| ¿El restaurante simplificado cobra IVA? | No. Sistema lo configura por sucursal |
| Consecutivo de facturas | Por sucursal, no por restaurante |

---

## Alertas de riesgo — umbrales exactos

| Tipo de alerta | Umbral | Nivel |
|---|---|---|
| Eliminación de ítem post-cocina | Cualquier eliminación después de `en_cocina` | Alto |
| Descuento manual | Mayor al 30% del total | Alto |
| Cancelaciones frecuentes | 3 o más cancelaciones del mismo usuario en el mismo día | Medio |
| Transferencia múltiple de mesa | Más de 2 transferencias del mismo pedido | Bajo |
| Modificación de precio | Cualquier cambio directo de precio fuera del panel de productos | Alto |
| Cuadre de caja | Diferencia mayor a $5.000 | Alto |
| Retiro sin autorización | Cualquier intento | Crítico |
| Costo ingrediente sube | Más del 15% vs compra anterior | Bajo |
| Margen bajo prolongado | Margen menor a 20% por más de 7 días | Bajo |
| Caída de ventas | Más del 40% vs semana anterior del mismo producto | Bajo |
| Sin domiciliario disponible | Después de 3 intentos de búsqueda | Alto |
| Demora excesiva en entrega | Entrega tarda más del doble del tiempo estimado | Medio |

---

## Calculadora de precio sugerido

Fórmula: `precio_sugerido = costo_produccion / (1 - margen_deseado / 100)`

| Costo producción | Margen deseado | Precio sugerido |
|---|---|---|
| $7.500 | 50% | $15.000 |
| $7.500 | 60% | $18.750 |
| $12.000 | 55% | $26.667 |

El admin ve el precio sugerido, puede aceptarlo con un botón o ignorarlo.
Si acepta, el backend actualiza el precio del producto y registra el cambio en auditoria_logs.

---

## Horarios

| Regla | Valor |
|---|---|
| ¿Qué pasa si alguien pide fuera del horario? | Backend rechaza con mensaje: "Este restaurante está cerrado. Horario: [horario]" |
| ¿Con cuánto tiempo de anticipación se cierra el menú? | 0 minutos. Se cierra exacto a la hora configurada |
| ¿Puede el admin recibir pedidos fuera del horario manualmente? | Sí, con permiso especial desde el panel |

---

## Encargos

| Regla | Valor |
|---|---|
| ¿Los encargos tienen tiempo mínimo de anticipación? | Configurable por producto (el admin lo define en días) |
| ¿Los encargos descuentan stock inmediatamente? | No. Al momento de la entrega/preparación |
| ¿Los encargos pasan por cocina? | Solo cuando el admin los activa manualmente |
| ¿Los encargos requieren pago anticipado? | Configurable por el restaurante |

---

## Multi-sucursal

> **Spec completa:** `docs/MULTI_SUCURSAL.md` · Regla Cursor: `.cursor/rules/foody-multi-sucursal.mdc`
>
> **Modelo acordado (2026-06-09):** cada sucursal opera como un restaurante independiente bajo la misma marca (ej. Alitas House Norte vs Sur). Staff, caja, menú, stock, pedidos y contabilidad operativa **no se mezclan** entre sucursales.

### Aislamiento operativo (por sucursal)

| Regla | Valor |
|---|---|
| ¿Qué es un restaurante vs una sucursal? | **Restaurante** = marca + suscripción. **Sucursal** = unidad operativa real (`sucursal_id`) |
| ¿El admin de Norte es el mismo que el de Sur? | **No.** Cada sede tiene su propio administrador y staff (`usuarios.sucursal_id`) |
| ¿Los productos se comparten entre sucursales? | **No.** Cada sucursal tiene catálogo, precios y recetas propios |
| ¿El stock se comparte entre sucursales? | **No.** Cantidades independientes; no hay un solo inventario global |
| ¿Pedidos, caja, cocina, mesas? | **Solo de la sucursal** donde se crearon |
| ¿Domiciliarios de planta en otra sucursal? | **No.** Asignados a una sola `sucursal_id` |
| ¿Domiciliarios independientes? | Sí, en su ciudad; pueden recibir ofertas de distintas sucursales de la ciudad |
| ¿Consecutivo de facturas? | Por sucursal (no por restaurante) |
| ¿Reportes y alertas? | Por sucursal; consolidado solo rol corporativo (futuro) |

### Visibilidad cruzada (excepción acordada)

| Regla | Valor |
|---|---|
| ¿Puede Norte **ver** el inventario de Sur? | **Sí, solo lectura**, mismo `restaurante_id`, con permiso `ver_inventario_otras_sucursales` |
| ¿Puede Norte **editar** stock de Sur? | **No** |
| ¿Se mezcla contabilidad al ver otra sede? | **No.** Solo consulta de inventario; caja y reportes siguen aislados |
| ¿Traslado de insumos entre sedes? | Futuro: movimiento auditado explícito (no UPDATE cruzado directo) |

### Roles y alcance

| Regla | Valor |
|---|---|
| Staff operativo (cajero, mesero, cocina, domi planta) | Solo su `sucursal_id`; sin selector de sucursal |
| Admin / gerente **de sucursal** | Operación completa **solo en su sede**; puede ver inventario hermano si tiene permiso |
| Gerente cadena / dueño (corporativo) | Todas las sucursales del restaurante; selector y reportes consolidados (futuro) |
| ¿Un admin de sede cambia sucursal en el panel? | **No** (objetivo; hoy el dropdown existe — ver brecha en `docs/MULTI_SUCURSAL.md`) |

### Implementación (estado)

| Regla | Valor |
|---|---|
| Columna `sucursal_id` en tablas operativas | ✅ Obligatorio (ver `MEMORIA.md`) |
| `SucursalScopeService` (lectura/escritura) | ✅ Fase 1 — inventario, pedidos, caja, dashboard |
| Permiso `ver_inventario_otras_sucursales` | ✅ Migración `043` |
| `GET /inventario/hermanas/resumen` + UI Flutter | ✅ Fase 1 — solo lectura |
| Selector sucursal panel admin | ✅ Solo `gestionar_sucursales` |
| Scope en catálogo, mesas, zonas | ⏳ Fase 2 |
| Traslados entre sucursales | ⏳ Fase 2 |

---

## Suscripción (modelo de negocio Foody)

| Regla | Valor |
|---|---|
| Unidad de cobro | Por restaurante (no por sucursal) |
| ¿Las sucursales adicionales tienen costo extra? | A definir en plan de precios (recomendado: sí, a partir de la 3ra sucursal) |
| ¿Hay período de prueba? | A definir (recomendado: 14 días gratis) |
| ¿Qué pasa si el restaurante no paga? | Sistema se bloquea. Los datos se conservan 30 días |

---

## Super admin y suscripciones

| Regla | Valor |
|---|---|
| ¿Quién puede acceder al panel Foody? | Solo rol super_admin. Cualquier otro rol que intente acceder a /super/* recibe 403 |
| ¿Se puede registrar un super_admin desde la app? | No. Solo se puede crear desde la BD directamente o desde otro super_admin |
| ¿Qué pasa cuando un restaurante se bloquea? | Todos sus requests devuelven RESTAURANTE_BLOQUEADO. Los datos se conservan 30 días |
| ¿Las sucursales del restaurante bloqueado también se bloquean? | Sí. El guard verifica por restaurante_id, no por sucursal |
| ¿Puede el admin del restaurante crear ciudades? | No. Solo el super_admin crea ciudades |
| ¿Puede el admin crear sucursales de su restaurante? | Sí. Tiene la pestaña Sucursales en su panel |
| ¿Puede el admin crear usuarios de su restaurante? | Sí. Solo dentro de su restaurante y sus sucursales |
| ¿Puede el super_admin cambiar contraseña sin saber la actual? | Sí. Es un reemplazo directo, no requiere verificar la actual |
| Período de prueba para restaurantes nuevos | 14 días con **estado** `prueba` (no es un nombre de plan). Después debe activar suscripción |

### Planes comerciales (`basico`, `pro`, `enterprise`) — estado de implementación

> Detalle completo: `docs/PLANES_SUSCRIPCION.md`

| Regla | Valor |
|---|---|
| ¿El plan limita módulos hoy? | **No.** La columna `plan` es metadata en BD y UI de Foody Control |
| ¿Qué sí bloquea al restaurante? | Solo el **estado** de suscripción (`vencida` / `bloqueada` → 403 vía `SuscripcionActivaGuard`) |
| ¿Vence solo por fecha? | **No.** `fecha_vencimiento` se guarda pero no hay job automático a `vencida` |
| Objetivo comercial (pendiente) | Básico: menú+pedidos+caja · Pro: +inventario+cocina+domiciliarios · Enterprise: +facturación+multi-sucursal+reportes |
| Cuándo implementar restricciones por plan | Sprint 8+ — `PlanFeaturesGuard`, matriz plan→módulos, menú admin condicionado |

---

## Login y redirección

| Regla | Valor |
|---|---|
| ¿Hay registro público de usuarios? | No. Todos los usuarios los crea el super_admin o el admin del restaurante |
| ¿El domiciliario independiente usa este login? | No. Tiene su propio login en la app foody_domiciliario |
| ¿El cliente usa este login? | No. El cliente no tiene login |
| ¿Puede un usuario tener dos roles? | No. Cada usuario tiene exactamente un rol |
| ¿Qué pasa si un usuario inactivo intenta hacer login? | Backend devuelve USUARIO_INACTIVO antes de verificar contraseña |
| ¿El token JWT incluye los permisos? | Sí. El payload incluye rol y lista de permisos para que Flutter construya el menú |
