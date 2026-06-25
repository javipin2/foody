"use strict";
var __decorate = (this && this.__decorate) || function (decorators, target, key, desc) {
    var c = arguments.length, r = c < 3 ? target : desc === null ? desc = Object.getOwnPropertyDescriptor(target, key) : desc, d;
    if (typeof Reflect === "object" && typeof Reflect.decorate === "function") r = Reflect.decorate(decorators, target, key, desc);
    else for (var i = decorators.length - 1; i >= 0; i--) if (d = decorators[i]) r = (c < 3 ? d(r) : c > 3 ? d(target, key, r) : d(target, key)) || r;
    return c > 3 && r && Object.defineProperty(target, key, r), r;
};
var __metadata = (this && this.__metadata) || function (k, v) {
    if (typeof Reflect === "object" && typeof Reflect.metadata === "function") return Reflect.metadata(k, v);
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.PedidosDescuentoService = void 0;
const common_1 = require("@nestjs/common");
const database_service_1 = require("../../core/database/database.service");
const facturacion_service_1 = require("../facturacion/facturacion.service");
const alertas_riesgo_service_1 = require("../alertas/alertas-riesgo.service");
const pedidos_soporte_service_1 = require("./pedidos-soporte.service");
let PedidosDescuentoService = class PedidosDescuentoService {
    database;
    facturacion;
    alertasRiesgo;
    soporte;
    constructor(database, facturacion, alertasRiesgo, soporte) {
        this.database = database;
        this.facturacion = facturacion;
        this.alertasRiesgo = alertasRiesgo;
        this.soporte = soporte;
    }
    async aplicarDescuento(pedidoId, sucursalId, usuarioId, dto, contexto) {
        if (!contexto.permisos.includes('aplicar_descuento')) {
            throw new common_1.ForbiddenException('No tienes permiso para aplicar descuentos');
        }
        if (dto.monto == null && dto.porcentaje == null) {
            throw new common_1.BadRequestException('Indica monto o porcentaje de descuento');
        }
        if (dto.monto != null && dto.porcentaje != null) {
            throw new common_1.BadRequestException('Usa solo monto o porcentaje, no ambos');
        }
        if (!dto.motivo?.trim()) {
            throw new common_1.BadRequestException('El motivo del descuento es obligatorio');
        }
        const result = await this.database.enTransaccion(async (client) => {
            const pedido = await this.soporte.consultarUnoCliente(client, `SELECT id, estado, subtotal, costo_domicilio, descuento, total
         FROM pedidos WHERE id = $1 AND sucursal_id = $2 FOR UPDATE`, [pedidoId, sucursalId]);
            if (!pedido)
                throw new common_1.NotFoundException('Pedido no encontrado');
            if (['cancelado', 'entregado', 'pagado', 'rechazado'].includes(pedido.estado)) {
                throw new common_1.BadRequestException('No se puede descontar un pedido en este estado');
            }
            const base = Number(pedido.subtotal) + Number(pedido.costo_domicilio);
            let descuento = dto.monto ?? Math.round((base * dto.porcentaje) / 100);
            descuento = Math.min(Math.max(descuento, 0), base);
            const pctBase = base > 0 ? (descuento / base) * 100 : 0;
            const esElevado = contexto.rol === 'admin' || contexto.rol === 'gerente';
            if (pctBase > 20 && !esElevado) {
                throw new common_1.BadRequestException('Descuentos mayores al 20% requieren admin o gerente');
            }
            const total = base - descuento;
            const iva = await this.facturacion.calcularIvaParaPedidoEnTransaccion(client, sucursalId, total);
            await client.query(`UPDATE pedidos SET
           descuento = $1, motivo_descuento = $2, total = $3,
           iva_porcentaje = $4, iva_valor = $5
         WHERE id = $6`, [descuento, dto.motivo.trim(), total, iva.iva_porcentaje, iva.iva_valor, pedidoId]);
            if (pctBase > alertas_riesgo_service_1.UMBRALES_ALERTA.descuentoPorcentajeAlto) {
                await this.alertasRiesgo.registrarEnTransaccion(client, {
                    sucursalId,
                    tipo: 'descuento_manual_excesivo',
                    nivel: 'alto',
                    descripcion: `Descuento del ${Math.round(pctBase)}% (${descuento} COP) — ${dto.motivo.trim()}`,
                    referenciaId: pedidoId,
                    referenciaTipo: 'pedido',
                    deduplicar: true,
                });
            }
            await client.query(`INSERT INTO auditoria_logs (
           sucursal_id, usuario_id, accion, tabla_afectada, registro_id,
           datos_antes, datos_despues
         ) VALUES ($1,$2,'APLICAR_DESCUENTO','pedidos',$3,$4::jsonb,$5::jsonb)`, [
                sucursalId,
                usuarioId,
                pedidoId,
                JSON.stringify({
                    descuento_anterior: Number(pedido.descuento),
                    total_anterior: Number(pedido.total),
                }),
                JSON.stringify({
                    descuento,
                    porcentaje: Math.round(pctBase * 100) / 100,
                    motivo: dto.motivo.trim(),
                    total,
                    iva_valor: iva.iva_valor,
                }),
            ]);
            return {
                id: pedidoId,
                estado: pedido.estado,
                descuento,
                porcentaje: Math.round(pctBase * 100) / 100,
                total,
                iva_valor: iva.iva_valor,
            };
        });
        this.soporte.notificarPedidoRealtime(sucursalId, pedidoId, result.estado);
        return result;
    }
};
exports.PedidosDescuentoService = PedidosDescuentoService;
exports.PedidosDescuentoService = PedidosDescuentoService = __decorate([
    (0, common_1.Injectable)(),
    __metadata("design:paramtypes", [database_service_1.DatabaseService,
        facturacion_service_1.FacturacionService,
        alertas_riesgo_service_1.AlertasRiesgoService,
        pedidos_soporte_service_1.PedidosSoporteService])
], PedidosDescuentoService);
//# sourceMappingURL=pedidos-descuento.service.js.map