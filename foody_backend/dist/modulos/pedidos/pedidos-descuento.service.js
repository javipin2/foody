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
const roles_food_1 = require("../../core/auth/roles-food");
const alertas_riesgo_service_1 = require("../alertas/alertas-riesgo.service");
const auditoria_service_1 = require("../auditoria/auditoria.service");
const caja_movimientos_service_1 = require("../../core/caja/caja-movimientos.service");
const pedidos_soporte_service_1 = require("./pedidos-soporte.service");
const pedidos_estado_command_service_1 = require("./pedidos-estado-command.service");
const pedidos_cuenta_mesa_service_1 = require("./pedidos-cuenta-mesa.service");
let PedidosDescuentoService = class PedidosDescuentoService {
    database;
    facturacion;
    alertasRiesgo;
    soporte;
    auditoria;
    cajaMovimientos;
    estadoCommand;
    cuentaMesa;
    constructor(database, facturacion, alertasRiesgo, soporte, auditoria, cajaMovimientos, estadoCommand, cuentaMesa) {
        this.database = database;
        this.facturacion = facturacion;
        this.alertasRiesgo = alertasRiesgo;
        this.soporte = soporte;
        this.auditoria = auditoria;
        this.cajaMovimientos = cajaMovimientos;
        this.estadoCommand = estadoCommand;
        this.cuentaMesa = cuentaMesa;
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
            const pedido = await this.soporte.consultarUnoCliente(client, `SELECT id, estado, tipo, mesa_id, subtotal, costo_domicilio, descuento, total,
                COALESCE(monto_pagado, 0) AS monto_pagado, numero_pedido
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
            const esElevado = (0, roles_food_1.esAdminRestaurante)(contexto.rol) || contexto.rol === 'gerente';
            if (pctBase > 20 && !esElevado) {
                throw new common_1.BadRequestException('Descuentos mayores al 20% requieren admin o gerente');
            }
            const total = base - descuento;
            const pagadoAntes = Number(pedido.monto_pagado);
            const nuevoPagado = Math.min(pagadoAntes, total);
            const excesoCaja = pagadoAntes - nuevoPagado;
            const iva = await this.facturacion.calcularIvaParaPedidoEnTransaccion(client, sucursalId, total);
            if (excesoCaja > 0.01) {
                const cajaId = await this.cajaMovimientos.obtenerCajaAbiertaId(client, sucursalId);
                if (!cajaId) {
                    throw new common_1.BadRequestException({
                        error: 'CAJA_NO_ABIERTA',
                        message: 'Abre la caja para aplicar el descuento y registrar la devolución del exceso cobrado',
                    });
                }
                await this.cajaMovimientos.insertar(client, {
                    cajaId,
                    sucursalId,
                    pedidoId,
                    tipo: 'devolucion',
                    monto: excesoCaja,
                    metodoPago: null,
                    descripcion: `Ajuste descuento ${pedido.numero_pedido}`,
                    usuarioId,
                });
            }
            await client.query(`UPDATE pedidos SET
           descuento = $1, motivo_descuento = $2, total = $3,
           monto_pagado = $4,
           iva_porcentaje = $5, iva_valor = $6,
           promocion_id = NULL
         WHERE id = $7`, [
                descuento,
                dto.motivo.trim(),
                total,
                nuevoPagado,
                iva.iva_porcentaje,
                iva.iva_valor,
                pedidoId,
            ]);
            await this.facturacion.sincronizarBorradorDesdePedidoEnTransaccion(client, sucursalId, pedidoId);
            let estadoFinal = pedido.estado;
            const pagoCompletoTrasDescuento = nuevoPagado >= total - 0.01;
            const requiereCierreCaja = pedido.tipo !== 'domicilio' &&
                ['listo', 'pagando'].includes(pedido.estado) &&
                pagoCompletoTrasDescuento;
            if (requiereCierreCaja) {
                const cambio = await this.estadoCommand.aplicarEstadoEnTransaccion(client, {
                    pedidoId,
                    sucursalId,
                    nuevoEstado: 'pagado',
                    origen: 'cobro',
                    usuarioId,
                    motivo: `Cierre por saldo cubierto tras descuento: ${dto.motivo.trim()}`,
                    estadoAnterior: pedido.estado,
                    tipo: pedido.tipo,
                });
                estadoFinal = cambio.nuevo;
                if (cambio.nuevo === 'pagado' && pedido.mesa_id) {
                    await this.cuentaMesa.liberarMesaSiSinPedidosActivos(client, pedido.mesa_id, sucursalId);
                }
            }
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
            await this.auditoria.registrarEnTransaccion(client, {
                sucursalId,
                accion: 'APLICAR_DESCUENTO',
                tablaAfectada: 'pedidos',
                registroId: pedidoId,
                usuarioId,
                datosAntes: {
                    descuento_anterior: Number(pedido.descuento),
                    total_anterior: Number(pedido.total),
                },
                datosDespues: {
                    descuento,
                    porcentaje: Math.round(pctBase * 100) / 100,
                    motivo: dto.motivo.trim(),
                    total,
                    iva_valor: iva.iva_valor,
                },
            });
            return {
                id: pedidoId,
                estado: estadoFinal,
                mesa_id: pedido.mesa_id,
                descuento,
                porcentaje: Math.round(pctBase * 100) / 100,
                total,
                iva_valor: iva.iva_valor,
            };
        });
        this.soporte.notificarPedidoRealtime(sucursalId, pedidoId, result.estado, undefined, {
            mesaId: result.mesa_id,
        });
        return result;
    }
};
exports.PedidosDescuentoService = PedidosDescuentoService;
exports.PedidosDescuentoService = PedidosDescuentoService = __decorate([
    (0, common_1.Injectable)(),
    __metadata("design:paramtypes", [database_service_1.DatabaseService,
        facturacion_service_1.FacturacionService,
        alertas_riesgo_service_1.AlertasRiesgoService,
        pedidos_soporte_service_1.PedidosSoporteService,
        auditoria_service_1.AuditoriaService,
        caja_movimientos_service_1.CajaMovimientosService,
        pedidos_estado_command_service_1.PedidosEstadoCommandService,
        pedidos_cuenta_mesa_service_1.PedidosCuentaMesaService])
], PedidosDescuentoService);
//# sourceMappingURL=pedidos-descuento.service.js.map