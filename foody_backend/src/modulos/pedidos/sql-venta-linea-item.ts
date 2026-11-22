/**
 * Venta de una línea de pedido_items (alias `pi`), alineada con cobro / DELETE.
 * precio_unitario = base o precio fijo combo; extras en tablas hijas.
 */
export const SQL_VENTA_LINEA_ITEM = `
  (
    pi.cantidad * pi.precio_unitario
    + COALESCE((
        SELECT SUM(pit.precio_topping)
        FROM pedido_item_toppings pit
        WHERE pit.pedido_item_id = pi.id
      ), 0) * pi.cantidad
    + COALESCE((
        SELECT SUM(pib.precio_bebida * pib.cantidad)
        FROM pedido_item_bebidas pib
        WHERE pib.pedido_item_id = pi.id
      ), 0)
  )`;
