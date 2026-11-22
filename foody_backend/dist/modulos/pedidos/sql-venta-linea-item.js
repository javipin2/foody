"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.SQL_VENTA_LINEA_ITEM = void 0;
exports.SQL_VENTA_LINEA_ITEM = `
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
//# sourceMappingURL=sql-venta-linea-item.js.map