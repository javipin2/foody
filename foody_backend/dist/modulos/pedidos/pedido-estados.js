"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.ESTADOS_COCINA_RESUELTOS = exports.SQL_WHERE_PEDIDO_COMPLETADO = exports.SQL_WHERE_DOMICILIO_ENTREGADO_IMPAGO = exports.SQL_WHERE_PEDIDO_OPERACION_ABIERTA = exports.SQL_WHERE_PEDIDO_BLOQUEA_MESA = exports.ESTADOS_PEDIDO_INMUTABLES_DESDE_COCINA = exports.TRANSICIONES_PEDIDO = void 0;
exports.esPedidoEnMesa = esPedidoEnMesa;
exports.transicionEstadoPermitida = transicionEstadoPermitida;
exports.estadoActivaCocina = estadoActivaCocina;
exports.puedeMarcarPagando = puedeMarcarPagando;
exports.saldoPendientePedido = saldoPendientePedido;
exports.pedidoCobradoCompletamente = pedidoCobradoCompletamente;
exports.pedidoTerminalOperativo = pedidoTerminalOperativo;
exports.sqlWherePedidoAbiertoOperativo = sqlWherePedidoAbiertoOperativo;
exports.esEstadoCocinaResuelto = esEstadoCocinaResuelto;
exports.puedeForzarPagadoSinCocinaCompleta = puedeForzarPagadoSinCocinaCompleta;
exports.pedidoCocinaCompleta = pedidoCocinaCompleta;
exports.puedeAvanzarCocinaPedidoPagado = puedeAvanzarCocinaPedidoPagado;
exports.TRANSICIONES_PEDIDO = {
    pendiente_aprobacion: ['en_cocina', 'rechazado', 'cancelado'],
    pendiente: ['en_cocina', 'cancelado'],
    confirmado: ['en_cocina', 'listo', 'pagando', 'cancelado'],
    en_cocina: ['listo', 'pagando', 'cancelado'],
    listo: ['pagando', 'entregado', 'cancelado', 'en_cocina', 'pagado'],
    pagando: ['entregado', 'cancelado', 'en_cocina'],
    asignado: ['en_camino', 'cancelado'],
    en_camino: ['entregado', 'cancelado'],
    entregado: [],
    pagado: [],
    cancelado: [],
    rechazado: [],
};
exports.ESTADOS_PEDIDO_INMUTABLES_DESDE_COCINA = new Set([
    'pagando',
    'pagado',
    'asignado',
    'en_camino',
    'entregado',
    'cancelado',
    'rechazado',
]);
function esPedidoEnMesa(tipo, mesaId) {
    return tipo === 'mesa' || (mesaId != null && mesaId !== '');
}
function transicionEstadoPermitida(estadoActual, estadoNuevo, tipo, mesaId) {
    if (estadoActual === estadoNuevo)
        return true;
    const permitidos = exports.TRANSICIONES_PEDIDO[estadoActual];
    if (!permitidos?.includes(estadoNuevo))
        return false;
    const tipoPedido = tipo ?? '';
    if (estadoNuevo === 'pagando' && tipoPedido === 'domicilio') {
        return false;
    }
    if (estadoNuevo === 'entregado' &&
        estadoActual === 'pagando' &&
        tipoPedido === 'domicilio') {
        return false;
    }
    if (estadoNuevo === 'pagando' &&
        estadoActual === 'listo' &&
        tipoPedido === 'domicilio') {
        return false;
    }
    if (estadoNuevo === 'entregado' && tipoPedido !== 'domicilio') {
        return false;
    }
    if (estadoNuevo === 'entregado' &&
        tipoPedido === 'domicilio' &&
        estadoActual !== 'en_camino') {
        return false;
    }
    return true;
}
function estadoActivaCocina(estado) {
    return estado === 'en_cocina' || estado === 'confirmado';
}
function puedeMarcarPagando(tipo, mesaId) {
    return tipo === 'mesa' || tipo === 'para_llevar' || mesaId != null;
}
exports.SQL_WHERE_PEDIDO_BLOQUEA_MESA = `
  estado NOT IN ('cancelado', 'rechazado', 'pagado')
  AND (
    estado <> 'entregado'
    OR COALESCE(monto_pagado, 0) < total - 0.01
  )
`;
function saldoPendientePedido(total, montoPagado) {
    return Math.max(0, Number(total) - Number(montoPagado ?? 0));
}
function pedidoCobradoCompletamente(total, montoPagado) {
    return saldoPendientePedido(total, montoPagado) <= 0.01;
}
function pedidoTerminalOperativo(pedido) {
    if (pedido.estado === 'pagado')
        return true;
    const total = Number(pedido.total);
    return (pedido.tipo === 'domicilio' &&
        pedido.estado === 'entregado' &&
        pedidoCobradoCompletamente(total, pedido.monto_pagado));
}
exports.SQL_WHERE_PEDIDO_OPERACION_ABIERTA = `
  estado IN (
    'pendiente_aprobacion', 'pendiente', 'confirmado',
    'en_cocina', 'listo', 'pagando', 'asignado', 'en_camino'
  )
  AND COALESCE(monto_pagado, 0) < total - 0.01
`;
function sqlWherePedidoAbiertoOperativo(alias = '') {
    const p = alias ? `${alias}.` : '';
    return `(
    ${p}estado IN (
      'pendiente_aprobacion', 'pendiente', 'confirmado',
      'en_cocina', 'listo', 'pagando', 'asignado', 'en_camino'
    )
    OR (
      ${p}tipo = 'domicilio'
      AND ${p}estado = 'entregado'
      AND COALESCE(${p}monto_pagado, 0) < ${p}total - 0.01
    )
  )`;
}
exports.SQL_WHERE_DOMICILIO_ENTREGADO_IMPAGO = `
  estado = 'entregado'
  AND COALESCE(monto_pagado, 0) < total - 0.01
`;
exports.SQL_WHERE_PEDIDO_COMPLETADO = `
  (
    estado = 'pagado'
    OR (
      tipo = 'domicilio'
      AND estado = 'entregado'
      AND COALESCE(monto_pagado, 0) >= total - 0.01
    )
  )
`;
exports.ESTADOS_COCINA_RESUELTOS = ['listo', 'no_disponible'];
function esEstadoCocinaResuelto(estado) {
    return exports.ESTADOS_COCINA_RESUELTOS.includes(estado);
}
function puedeForzarPagadoSinCocinaCompleta(rol, motivo) {
    const r = (rol ?? '').trim();
    const okRol = r === 'admin' || r === 'gerente' || r === 'gerente_cadena';
    return okRol && !!motivo?.trim();
}
async function pedidoCocinaCompleta(client, pedidoId) {
    const r = await client.query(`SELECT
       COUNT(*)::text AS n,
       COUNT(*) FILTER (
         WHERE estado_cocina IS NULL
            OR estado_cocina NOT IN ('listo', 'no_disponible')
       )::text AS incompletos
     FROM pedido_items WHERE pedido_id = $1`, [pedidoId]);
    const n = Number(r.rows[0]?.n ?? 0);
    const incompletos = Number(r.rows[0]?.incompletos ?? 0);
    return n > 0 && incompletos === 0;
}
function puedeAvanzarCocinaPedidoPagado(params) {
    const total = Number(params.total);
    const montoPagado = Number(params.montoPagado);
    if (params.estadoPedido !== 'pagado' ||
        !Number.isFinite(total) ||
        !Number.isFinite(montoPagado) ||
        montoPagado < total - 0.01 ||
        ![null, undefined, 'pendiente', 'preparando'].includes(params.estadoItem)) {
        return false;
    }
    return ['preparando', 'listo', 'no_disponible'].includes(params.nuevoEstadoItem);
}
//# sourceMappingURL=pedido-estados.js.map