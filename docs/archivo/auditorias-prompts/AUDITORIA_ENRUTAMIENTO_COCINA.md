# Auditoría de asignación de productos a Cocina — 2026-11-25

## Hallazgo COC-PRODUCT-KITCHEN-ROUTE-01

`productos.cocina_id` y `CrearProductoDto.cocina_id` admiten NULL. `CatalogoService.crearProducto()` elegía la primera cocina activa, pero si no existía permitía insertar un producto disponible sin cocina. Tampoco comprobaba que `categoria_id` ni una `cocina_id` explícita pertenecieran a la sede destino. La edición dinámica aceptaba referencias de otra sede. El panel avisaba “Sin cocinas” pero aun así permitía guardar.

Efecto de extremo a extremo: el pedido copia `productos.cocina_id` a `pedido_items.cocina_id`; `CocinasService.listarTickets()` usa `JOIN pedido_items ... pi.cocina_id = $1`, por lo que la línea sin asignación no aparece en ningún KDS. La operación de cocina rechaza actuar sobre el ítem sin cocina y los guards de cocina completa/despacho lo conservan como no resuelto. El pedido puede quedar atascado, aunque el resto de líneas esté listo.

## Corrección en fuente

- Categoría y cocina asignada deben ser activas y pertenecer a la misma sede.
- Un producto disponible debe tener cocina activa; se puede guardar un producto deshabilitado sin cocina como borrador, pero no activarlo hasta asignar una cocina.
- La edición y el endpoint de disponibilidad aplican el mismo guard; no se puede quitar la cocina a un producto disponible.
- Las bebidas que se publican como productos y la copia de menú a otra sede no generan productos disponibles sin cocina activa.
- El panel no abre el formulario de producto si la sede no tiene cocina; informa que debe crearla primero.
- Desactivar o eliminar una cocina queda bloqueado si tiene productos disponibles o ítems operativos pendientes de resolver.

## Verificación

- Servicio Nest cubre categoría ajena, falta de cocina, cocina ajena, valor predeterminado, activación de legado sin cocina, referencias ajenas al editar y espejo de bebida sin cocina; la protección de desactivación de cocina cubre productos disponibles, pedidos pendientes y desactivación segura sin uso. Revalidación focalizada: **2 suites/11 pruebas aprobadas**.
- Se agregó `foody_backend/test/flujos/catalogo-cocina.e2e-spec.ts`. En clon desechable de QA, la E2E creó un producto con cocina predeterminada, confirmó su `cocina_id`, creó un pedido staff, encontró su línea por nombre en el ticket de esa cocina y la llevó a `listo`; estado de pedido resultante `listo`. Resultado: **1/1 aprobada**.
- Suite completa Nest en la verificación inicial: **57 suites/156 pruebas**. En la revalidación actual, suites focalizadas de Catálogo/Cocina: **2 suites/11 pruebas aprobadas**.
- Menú Flutter: **15/15**, incluyendo 320, 390, 820 y 1440 px. Analyzer focalizado limpio.
- Consultas `READ ONLY` en la base Supabase local y en `foody_diseno_qa`: 0 pedidos activos con líneas no resueltas sin `cocina_id`. Esto no comprueba una base externa ni sustituye la revisión del runtime.
- La E2E escribió únicamente en el clon `foody_diseno_qa_codex_catalogokds_20261125`; después se detuvo la API `:3001` de prueba y se eliminó el clon tras comprobar cero conexiones. Verificación posterior: solo existe `foody_diseno_qa` como fuente, con sus tres restaurantes; `:3001` no tiene listener y API principal `:3000` PID 7584 sigue activo. No se modificó pedido/producto de la base fuente ni se tocó Tunnel/OAuth.

## Riesgo legado

Si existieran pedidos abiertos antiguos con `pedido_items.cocina_id IS NULL`, reasignar la cocina del producto solo afecta pedidos futuros porque cada pedido conserva su propia cocina. Esas líneas requerirían una reparación operativa explícita y transaccional después de clasificar la base; no se deben mutar junto con estos guards.
