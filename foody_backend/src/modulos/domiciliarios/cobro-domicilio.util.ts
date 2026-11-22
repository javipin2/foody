/**
 * Reparte el saldo pendiente de un pedido entre producto y domicilio.
 * Los pagos previos se imputan primero al producto, así el domicilio queda
 * como el remanente. Sirve para decidir cuánto entra a caja (producto) y cuánto
 * es domicilio (fuera de caja, salvo que la sucursal configure lo contrario).
 */
export function repartirCobroDomicilio(
  total: number,
  costoDomicilio: number,
  montoPagado: number,
): { saldo: number; productoPendiente: number; domicilioPendiente: number } {
  const domicilio = Math.max(0, costoDomicilio);
  const saldo = Math.max(0, total - montoPagado);
  const productoTotal = Math.max(0, total - domicilio);
  const productoPendiente = Math.max(
    0,
    Math.min(saldo, productoTotal - montoPagado),
  );
  const domicilioPendiente = Math.max(0, saldo - productoPendiente);
  return { saldo, productoPendiente, domicilioPendiente };
}

/** Monto que debe registrarse en caja al marcar domicilio entregado (Kanban o app). */
export function montoVentaCajaEntregaDomicilio(
  total: number,
  costoDomicilio: number,
  montoPagado: number,
  domicilioIngresaACaja: boolean,
): number {
  const { saldo, productoPendiente } = repartirCobroDomicilio(
    total,
    costoDomicilio,
    montoPagado,
  );
  return domicilioIngresaACaja ? saldo : productoPendiente;
}
