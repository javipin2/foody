"use strict";
var __decorate = (this && this.__decorate) || function (decorators, target, key, desc) {
    var c = arguments.length, r = c < 3 ? target : desc === null ? desc = Object.getOwnPropertyDescriptor(target, key) : desc, d;
    if (typeof Reflect === "object" && typeof Reflect.decorate === "function") r = Reflect.decorate(decorators, target, key, desc);
    else for (var i = decorators.length - 1; i >= 0; i--) if (d = decorators[i]) r = (c < 3 ? d(r) : c > 3 ? d(target, key, r) : d(target, key)) || r;
    return c > 3 && r && Object.defineProperty(target, key, r), r;
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.PedidosEstadoCommandService = void 0;
const common_1 = require("@nestjs/common");
const pedido_estados_1 = require("./pedido-estados");
let PedidosEstadoCommandService = class PedidosEstadoCommandService {
    async aplicarEstadoEnTransaccion(client, params) {
        let anterior = params.estadoAnterior;
        let tipo = params.tipo;
        if (!anterior || !tipo) {
            const fila = await client.query(`SELECT estado, tipo FROM pedidos
         WHERE id = $1 AND sucursal_id = $2
         FOR UPDATE`, [params.pedidoId, params.sucursalId]);
            if (!fila.rows[0]) {
                throw new common_1.NotFoundException('Pedido no encontrado');
            }
            anterior = fila.rows[0].estado;
            tipo = fila.rows[0].tipo;
        }
        const nuevo = params.nuevoEstado;
        if (anterior === nuevo) {
            return { aplicado: false, anterior, nuevo, tipo };
        }
        if (!this.transicionPermitidaParaOrigen(params.origen, anterior, nuevo, tipo)) {
            throw new common_1.BadRequestException({
                error: 'TRANSICION_ESTADO_NO_PERMITIDA',
                message: `No se puede pasar de ${anterior} a ${nuevo} (origen: ${params.origen})`,
            });
        }
        if (params.origen === 'cobro' && nuevo === 'pagado') {
            const completa = await (0, pedido_estados_1.pedidoCocinaCompleta)(client, params.pedidoId);
            if (!completa &&
                !(0, pedido_estados_1.puedeForzarPagadoSinCocinaCompleta)(params.rol, params.motivo)) {
                throw new common_1.BadRequestException({
                    error: 'COCINA_INCOMPLETA_PARA_PAGADO',
                    message: 'Hay ítems aún en cocina. Registra un abono o espera cocina completa. Admin/gerente puede cerrar con motivo.',
                });
            }
        }
        await client.query(`UPDATE pedidos SET estado = $1 WHERE id = $2`, [
            nuevo,
            params.pedidoId,
        ]);
        await client.query(`INSERT INTO estados_pedido_historial
         (pedido_id, estado_anterior, estado_nuevo, usuario_id, motivo, duracion_estado_anterior_seg)
       VALUES (
         $1, $2, $3, $4, $5,
         GREATEST(0, EXTRACT(EPOCH FROM (
           now() - COALESCE(
             (SELECT MAX(fecha) FROM estados_pedido_historial WHERE pedido_id = $1),
             (SELECT created_at FROM pedidos WHERE id = $1)
           )
         ))::int)
       )`, [
            params.pedidoId,
            anterior,
            nuevo,
            params.usuarioId ?? null,
            params.motivo?.trim() || this.motivoPorOrigen(params.origen),
        ]);
        return { aplicado: true, anterior, nuevo, tipo };
    }
    transicionPermitidaParaOrigen(origen, anterior, nuevo, tipo) {
        if (origen === 'cobro' && nuevo === 'pagado') {
            return !['cancelado', 'rechazado', 'pagado'].includes(anterior);
        }
        if (origen === 'cobro' && nuevo === 'pagando') {
            return !['cancelado', 'rechazado', 'pagado'].includes(anterior);
        }
        if (origen === 'dispatch' || origen === 'domiciliario') {
            if (anterior === 'listo' && nuevo === 'asignado' && tipo === 'domicilio') {
                return true;
            }
            if (anterior === 'asignado' && nuevo === 'en_camino')
                return true;
            if (anterior === 'en_camino' &&
                nuevo === 'entregado' &&
                tipo === 'domicilio') {
                return true;
            }
            return false;
        }
        if (origen === 'cocina') {
            if (pedido_estados_1.ESTADOS_PEDIDO_INMUTABLES_DESDE_COCINA.has(anterior)) {
                return false;
            }
            return nuevo === 'en_cocina' || nuevo === 'listo';
        }
        if (origen === 'aprobacion_qr') {
            return anterior === 'pendiente_aprobacion' && nuevo === 'en_cocina';
        }
        if (origen === 'sistema') {
            return ((anterior === 'pendiente_aprobacion' && nuevo === 'rechazado') ||
                (0, pedido_estados_1.transicionEstadoPermitida)(anterior, nuevo, tipo));
        }
        return (0, pedido_estados_1.transicionEstadoPermitida)(anterior, nuevo, tipo);
    }
    motivoPorOrigen(origen) {
        switch (origen) {
            case 'cocina':
                return 'Cambio automático desde cocina';
            case 'dispatch':
                return 'Asignación automática — planta libre';
            case 'domiciliario':
                return 'Actualización desde app domiciliario';
            case 'cobro':
                return 'Cobro en caja';
            case 'aprobacion_qr':
                return 'Aprobación pedido mesa QR';
            case 'sistema':
                return 'Cambio automático del sistema';
            default:
                return 'Cambio de estado';
        }
    }
};
exports.PedidosEstadoCommandService = PedidosEstadoCommandService;
exports.PedidosEstadoCommandService = PedidosEstadoCommandService = __decorate([
    (0, common_1.Injectable)()
], PedidosEstadoCommandService);
//# sourceMappingURL=pedidos-estado-command.service.js.map