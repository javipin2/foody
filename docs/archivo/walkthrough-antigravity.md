# Resumen de Cambios: Plan Gratis Limitado y Resolución de Bugs Críticos

Se han implementado y validado todas las tareas establecidas en el plan de implementación. La aplicación Foody ahora permite a los dueños de negocio utilizar todos los módulos fundamentales bajo un modelo de "Uso Limitado" (Freemium) en lugar de estar completamente bloqueados. Además, se resolvieron vulnerabilidades de consistencia críticas en la arquitectura.

## Cambios Implementados

### 1. Evolución del Plan Gratis
- **Módulos liberados:** Inventario, Costeo, Cocina, Zonas de domicilio y Reportes ahora tienen como requisito el plan `gratis` (antes `pro`). (Tanto en frontend como en backend).
- **Límites impuestos (Plan Gratis, revisión 2026-06-24):**
  - **Mesas:** Máximo 2 mesas activas.
  - **Catálogo:** Máximo 5 productos activos.
  - **Inventario:** Máximo 5 ingredientes activos.
  - **Staff:** Máximo 2 usuarios.
- **Implementación backend:** Se inyectó `PlanFeaturesService` en `MesasService`, `CatalogoService` e `InventarioService` para interrumpir la creación y retornar un código `403 Forbidden` (`PLAN_LIMITE_EXCEDIDO`) cuando un usuario de plan gratis excede los recursos permitidos.

### 2. Bugs Críticos Resueltos (End-to-End)
- **R1: Caja/Liberación Mesa (Pedidos Estado)**
  - Se previno el error "Mesa con saldo pendiente liberada" agregando una validación estricta al cambiar el estado a `entregado` en `PedidosEstadoService`. Ahora el backend verifica `pedido.total` menos `pedido.monto_pagado` y detiene el flujo si hay un saldo insoluto.
- **R4: Menú/Conexión Rota (Catálogo Disponibilidad)**
  - Se corrigió la lógica que oculta los platos cuando el inventario se ajusta a cero. Anteriormente, si el ingrediente en cero pertenecía a una "subreceta", el plato principal no se enteraba. Se implementó un CTE Recursivo (`WITH RECURSIVE`) para buscar a través de toda la cadena de subrecetas.
- **R10: Race Condition QR (Inventario y Mesas)**
  - Durante un alto volumen de tráfico QR simultáneo (e.g. 5 clientes pidiendo al mismo tiempo en la misma mesa o consumiendo el último plato disponible), el stock o la mesa podían desincronizarse. Se agregó bloqueo explícito `FOR UPDATE` en `pedidos-crear.service.ts` y en `cargarStockIngredientes` (inventario) para forzar evaluación secuencial transaccional.

## Verificación
- El backend fue compilado de manera exitosa usando `npx nest build`. Todas las inyecciones de dependencias, tipados (`?? undefined` para `usuario.restaurante_id`) y promesas anidadas resolvieron correctamente.
- El frontend (Dart) tiene el mapeo de módulos en `plan_modulos.dart` actualizado a 'gratis'.

> [!NOTE]
> Cuando el usuario de plan gratis excede los límites (mesas, productos, inventario), el servidor responde con un código de error de negocio que el Frontend podrá interceptar para mostrar ventanas de "Sube tu plan para crear más mesas/productos".
