"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.SQL_WHERE_PEDIDO_BLOQUEA_MESA = exports.TRANSICIONES_PEDIDO = void 0;
exports.esPedidoEnMesa = esPedidoEnMesa;
exports.transicionEstadoPermitida = transicionEstadoPermitida;
exports.estadoActivaCocina = estadoActivaCocina;
exports.puedeMarcarPagando = puedeMarcarPagando;
exports.TRANSICIONES_PEDIDO = {
    pendiente_aprobacion: ['en_cocina', 'rechazado', 'cancelado'],
    pendiente: ['en_cocina', 'cancelado'],
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
    if (estadoNuevo === 'entregado' && esPedidoEnMesa(tipoPedido, mesaId)) {
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
//# sourceMappingURL=pedido-estados.js.map