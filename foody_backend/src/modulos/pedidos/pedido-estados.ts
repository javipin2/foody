/**
 * Máquina de estados del pedido — mesa / domicilio / para llevar.
 *
 * Reglas de producto (2026-06-19):
 * - «Confirmar» o «Aprobar QR» = pasa directo a `en_cocina` (sin columna confirmado).
 * - `confirmado` queda solo por pedidos legacy en BD; se trata como `en_cocina` en UI.
 * - `pagando`: cuenta presentada (mesa / para llevar).
 * - `pagado`: cobro en caja (`POST .../cobrar`); terminal, no vía PATCH estado.
 * - `pendiente`: pedidos cliente (domicilio/llevar) o domicilio staff — revisión antes de cocina.
 * - `pendiente_aprobacion`: solo mesa QR (cliente sin staff).
 *
 * 2026-06-19 (auditoría E2E P0):
 * - Pedido en mesa: `entregado` solo vía cobro (`pagado`), no PATCH Kanban.
 * - Domicilio: `entregado` solo desde `en_camino` (app domiciliario).
 */
export const TRANSICIONES_PEDIDO: Readonly<Record<string, readonly string[]>> = {
  pendiente_aprobacion: ['en_cocina', 'rechazado', 'cancelado'],
  pendiente: ['en_cocina', 'cancelado'],
  /** Legacy — pedidos antigos; en UI se agrupan con en_cocina */
  confirmado: ['en_cocina', 'listo', 'pagando', 'cancelado'],
  en_cocina: ['listo', 'pagando', 'cancelado'],
  listo: ['pagando', 'entregado', 'cancelado'],
  pagando: ['entregado', 'cancelado'],
  asignado: ['en_camino', 'cancelado'],
  en_camino: ['entregado', 'cancelado'],
  entregado: [],
  pagado: [],
  cancelado: [],
  rechazado: [],
};

/** Pedido atado a mesa física (tipo mesa o mesa_id presente). */
export function esPedidoEnMesa(
  tipo: string,
  mesaId?: string | null,
): boolean {
  return tipo === 'mesa' || (mesaId != null && mesaId !== '');
}

export function transicionEstadoPermitida(
  estadoActual: string,
  estadoNuevo: string,
  tipo?: string,
  mesaId?: string | null,
): boolean {
  if (estadoActual === estadoNuevo) return true;
  const permitidos = TRANSICIONES_PEDIDO[estadoActual];
  if (!permitidos?.includes(estadoNuevo)) return false;

  const tipoPedido = tipo ?? '';

  if (estadoNuevo === 'pagando' && tipoPedido === 'domicilio') {
    return false;
  }
  if (
    estadoNuevo === 'entregado' &&
    estadoActual === 'pagando' &&
    tipoPedido === 'domicilio'
  ) {
    return false;
  }
  if (
    estadoNuevo === 'pagando' &&
    estadoActual === 'listo' &&
    tipoPedido === 'domicilio'
  ) {
    return false;
  }

  /** Mesa: cierre operativo vía cobro en caja, no botón «Entregado» del Kanban. */
  if (estadoNuevo === 'entregado' && esPedidoEnMesa(tipoPedido, mesaId)) {
    return false;
  }

  /** Domicilio: entregar solo desde ruta (en_camino). */
  if (
    estadoNuevo === 'entregado' &&
    tipoPedido === 'domicilio' &&
    estadoActual !== 'en_camino'
  ) {
    return false;
  }

  return true;
}

/** Estados en los que el pedido entra a cocina (descuenta stock si aplica). */
export function estadoActivaCocina(estado: string): boolean {
  return estado === 'en_cocina' || estado === 'confirmado';
}

/** Solo mesa / para llevar en salón pueden pasar a pagando manualmente. */
export function puedeMarcarPagando(tipo: string, mesaId: string | null): boolean {
  return tipo === 'mesa' || tipo === 'para_llevar' || mesaId != null;
}

/** SQL fragment: pedido que mantiene la mesa ocupada (saldo o estado operativo). */
export const SQL_WHERE_PEDIDO_BLOQUEA_MESA = `
  estado NOT IN ('cancelado', 'rechazado', 'pagado')
  AND (
    estado <> 'entregado'
    OR COALESCE(monto_pagado, 0) < total - 0.01
  )
`;
