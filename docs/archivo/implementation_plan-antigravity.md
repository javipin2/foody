# Evolución del Plan Gratis y Corrección de Bugs Críticos (E2E)

Este plan aborda la solicitud de transformar el "Plan Gratis" de un estado bloqueado (donde no se pueden usar módulos esenciales) a un modelo de "Uso Limitado", permitiendo a pequeños negocios experimentar el valor real de Foody. Además, incluye la corrección de las vulnerabilidades operativas encontradas en la auditoría anterior.

## ⚠️ User Review Required

> [!IMPORTANT]
> **Límites propuestos para el Plan Gratis** (actualizados 2026-06-24 — más restrictivos):
> - **Mesas máximas**: 2
> - **Productos en Menú**: 5
> - **Insumos/Ingredientes**: 5
> - **Usuarios/Staff**: 2
> 
> Si el usuario intenta crear la mesa número 6 o el producto 21, la aplicación mostrará el modal de `MejorarPlanScreen`. ¿Estás de acuerdo con estos límites numéricos o prefieres otros?

> [!WARNING]
> **Liberación de Mesas (Bug de Caja)**:
> Para solucionar el problema de que una mesa se libere sin pagar, implementaremos un bloqueo estricto en el backend: **No se podrá marcar un pedido de mesa como "Entregado/Finalizado" si el saldo pendiente es mayor a $0**. Esto obligará al mesero o cajero a registrar el pago antes de liberar la mesa.

## Proposed Changes

---

### Módulo de Planes y Seguridad (Backend & Frontend)

Para habilitar el acceso a los módulos en el plan gratis y aplicar los límites numéricos.

#### [MODIFY] `foody_backend/src/core/auth/plan-features.config.ts`
- Cambiar `MODULO_PLAN_MINIMO` para que `inventario`, `cocina` y `costeo` requieran plan `gratis` en lugar de `pro`.
- Ampliar `LIMITES_POR_PLAN` para incluir `max_mesas`, `max_productos` y `max_ingredientes`.

#### [MODIFY] `foody_backend/src/modulos/mesas/mesas.service.ts`
- Agregar validación en la creación de mesas: consultar cantidad actual y bloquear con error `LIMITE_PLAN_ALCANZADO` si supera el límite del plan.

#### [MODIFY] `foody_backend/src/modulos/catalogo/productos.service.ts`
- Agregar validación en la creación de productos para respetar `max_productos` del plan actual.

#### [MODIFY] `foody_backend/src/modulos/inventario/inventario.service.ts`
- Agregar validación en la creación de ingredientes para respetar `max_ingredientes`.

#### [MODIFY] `lib/features/admin/domain/plan_modulos.dart`
- Actualizar `planMinimoPorModulo` para permitir la navegación a inventario y cocinas en el plan gratis.
- Integrar la visualización del diálogo de Upgrade (`PlanSelectionDialog`) cuando el backend retorne error de límite alcanzado.

---

### Corrección de Riesgos E2E (Backend)

Correcciones de vulnerabilidades transaccionales reportadas en la auditoría.

#### [MODIFY] `foody_backend/src/modulos/pedidos/pedidos-estado.service.ts`
- **Bug de Caja (R1)**: Añadir validación estricta al intentar pasar un pedido de mesa al estado `entregado` (final). Si `(total_calculado - monto_pagado) > 0`, lanzar excepción `PAGO_REQUERIDO_PARA_LIBERAR_MESA`.

#### [MODIFY] `foody_backend/src/modulos/catalogo/catalogo-disponibilidad.service.ts`
- **Bug de Menú (R4)**: Reparar la cascada de apagado. Asegurar que cuando el stock de un ingrediente llega a 0 (por ajuste manual), los productos que dependen de él cambien `disponible = false` y emitan el socket inmediatamente.

#### [MODIFY] `foody_backend/src/modulos/mesas/mesas.service.ts`
- **Bug Transferencia (R7)**: Añadir `SELECT ... FOR UPDATE` al hacer la transferencia de mesa para evitar colisiones.
- **Auditoría (R6)**: Insertar registro en `auditoria_logs` detallando de qué mesa a qué mesa se movió la cuenta.

#### [MODIFY] `foody_backend/src/modulos/pedidos/pedidos-crear.service.ts`
- **Race Condition QR (R10)**: Mejorar el bloqueo transaccional (`FOR UPDATE`) sobre el inventario y la mesa durante la creación y aprobación de un pedido QR para evitar sobreventa.

## Verification Plan

### Automated Tests
No aplican pruebas unitarias existentes a ejecutar, la verificación será de integración.

### Manual Verification
1. **Flujo Plan Gratis**: Iniciar sesión con un restaurante nuevo (Plan Gratis). Verificar que se puede entrar al Inventario. Crear 20 productos y verificar que al crear el #21 aparece el paywall de suscripción.
2. **Flujo Liberación Mesa**: Crear pedido en mesa. Intentar marcar como "Entregado" desde el KDS o Panel sin registrar pago. El sistema debe lanzar error rojo en la app.
3. **Flujo Ajuste Manual**: Bajar el stock a 0 manualmente desde el Admin de Inventario y corroborar en la app cliente que el producto ya no aparece.
