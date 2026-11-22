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
 * - Mesa / para llevar / mostrador: `entregado` no vía Kanban; cierre = `pagado` (`POST .../cobrar`).
 * - Domicilio: `entregado` solo desde `en_camino` (app domiciliario).
 */
export const TRANSICIONES_PEDIDO: Readonly<Record<string, readonly string[]>> = {
  pendiente_aprobacion: ['en_cocina', 'rechazado', 'cancelado'],
  pendiente: ['en_cocina', 'cancelado'],
  /** Legacy — pedidos antigos; en UI se agrupan con en_cocina */
  confirmado: ['en_cocina', 'listo', 'pagando', 'cancelado'],
  en_cocina: ['listo', 'pagando', 'cancelado'],
  /** VIE-01: agregar ítems demota a cocina; PED-PREPAGO: listo cobrado → pagado */
  listo: ['pagando', 'entregado', 'cancelado', 'en_cocina', 'pagado'],
  pagando: ['entregado', 'cancelado', 'en_cocina'],
  asignado: ['en_camino', 'cancelado'],
  en_camino: ['entregado', 'cancelado'],
  entregado: [],
  pagado: [],
  cancelado: [],
  rechazado: [],
};

/** F-06 / F-11: cocina no muta pedidos en cobro, ruta o terminal. */
export const ESTADOS_PEDIDO_INMUTABLES_DESDE_COCINA = new Set([
  'pagando',
  'pagado',
  'asignado',
  'en_camino',
  'entregado',
  'cancelado',
  'rechazado',
]);

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

  /** Salón / mostrador: cierre vía cobro en caja (`pagado`), no Kanban «Entregado». */
  if (estadoNuevo === 'entregado' && tipoPedido !== 'domicilio') {
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

/** A-04: semántica terminal — salón `pagado`, domicilio `entregado` + cobrado. */

export function saldoPendientePedido(
  total: number,
  montoPagado: number | string | null | undefined,
): number {
  return Math.max(0, Number(total) - Number(montoPagado ?? 0));
}

export function pedidoCobradoCompletamente(
  total: number,
  montoPagado: number | string | null | undefined,
): boolean {
  return saldoPendientePedido(total, montoPagado) <= 0.01;
}

export function pedidoTerminalOperativo(pedido: {
  estado: string;
  tipo: string;
  total: number | string;
  monto_pagado?: number | string | null;
}): boolean {
  if (pedido.estado === 'pagado') return true;
  const total = Number(pedido.total);
  return (
    pedido.tipo === 'domicilio' &&
    pedido.estado === 'entregado' &&
    pedidoCobradoCompletamente(total, pedido.monto_pagado)
  );
}

/** Pedidos en curso que bloquean cierre de caja (PED-PREPAGO-01: excluye cobrado completo). */
export const SQL_WHERE_PEDIDO_OPERACION_ABIERTA = `
  estado IN (
    'pendiente_aprobacion', 'pendiente', 'confirmado',
    'en_cocina', 'listo', 'pagando', 'asignado', 'en_camino'
  )
  AND COALESCE(monto_pagado, 0) < total - 0.01
`;

/** Domicilio entregado sin cobro completo (F-10 / A-04). */
export const SQL_WHERE_DOMICILIO_ENTREGADO_IMPAGO = `
  estado = 'entregado'
  AND COALESCE(monto_pagado, 0) < total - 0.01
`;

/** Venta cerrada para métricas (salón pagado + domi entregado cobrado). */
export const SQL_WHERE_PEDIDO_COMPLETADO = `
  (
    estado = 'pagado'
    OR (
      tipo = 'domicilio'
      AND estado = 'entregado'
      AND COALESCE(monto_pagado, 0) >= total - 0.01
    )
  )
`;

/** VIE-05/13 opción C: ítem resuelto en cocina (alineado COC-NODISP-01). */
export const ESTADOS_COCINA_RESUELTOS = ['listo', 'no_disponible'] as const;

export function esEstadoCocinaResuelto(estado: string): boolean {
  return (ESTADOS_COCINA_RESUELTOS as readonly string[]).includes(estado);
}

/** Roles que pueden forzar `pagado` con cocina incompleta (motivo obligatorio). */
export function puedeForzarPagadoSinCocinaCompleta(
  rol: string | null | undefined,
  motivo?: string | null,
): boolean {
  const r = (rol ?? '').trim();
  const okRol =
    r === 'admin' || r === 'gerente' || r === 'gerente_cadena';
  return okRol && !!motivo?.trim();
}

/**
 * VIE-05/13 C: cocina completa = todos los ítems en listo | no_disponible.
 * Pedido sin ítems → false (no cerrar vacío).
 */
export async function pedidoCocinaCompleta(
  client: { query: (sql: string, params?: unknown[]) => Promise<{ rows: Array<{ n: string; incompletos: string }> }> },
  pedidoId: string,
): Promise<boolean> {
  const r = await client.query(
    `SELECT
       COUNT(*)::text AS n,
       COUNT(*) FILTER (
         WHERE estado_cocina NOT IN ('listo', 'no_disponible')
       )::text AS incompletos
     FROM pedido_items WHERE pedido_id = $1`,
    [pedidoId],
  );
  const n = Number(r.rows[0]?.n ?? 0);
  const incompletos = Number(r.rows[0]?.incompletos ?? 0);
  return n > 0 && incompletos === 0;
}
