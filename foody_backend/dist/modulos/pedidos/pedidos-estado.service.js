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
exports.PedidosEstadoService = void 0;
const common_1 = require("@nestjs/common");
const database_service_1 = require("../../core/database/database.service");
const dispatch_service_1 = require("../domiciliarios/dispatch.service");
const alertas_riesgo_service_1 = require("../alertas/alertas-riesgo.service");
const costeo_service_1 = require("../costeo/costeo.service");
const pedidos_caja_auditoria_service_1 = require("./pedidos-caja-auditoria.service");
const pedidos_cuenta_mesa_service_1 = require("./pedidos-cuenta-mesa.service");
const pedidos_inventario_service_1 = require("./pedidos-inventario.service");
const pedido_estados_1 = require("./pedido-estados");
const pedidos_soporte_service_1 = require("./pedidos-soporte.service");
const ESTADOS_KANBAN = [
    'pendiente',
    'confirmado',
    'en_cocina',
    'listo',
    'pagando',
    'asignado',
    'en_camino',
    'entregado',
];
let PedidosEstadoService = class PedidosEstadoService {
    database;
    dispatch;
    alertasRiesgo;
    costeo;
    cajaAuditoria;
    cuentaMesa;
    soporte;
    inventario;
    constructor(database, dispatch, alertasRiesgo, costeo, cajaAuditoria, cuentaMesa, soporte) {
        this.database = database;
        this.dispatch = dispatch;
        this.alertasRiesgo = alertasRiesgo;
        this.costeo = costeo;
        this.cajaAuditoria = cajaAuditoria;
        this.cuentaMesa = cuentaMesa;
        this.soporte = soporte;
        this.inventario = new pedidos_inventario_service_1.PedidosInventarioService(this.costeo, this.alertasRiesgo);
    }
    async cambiarEstado(pedidoId, sucursalId, usuarioId, nuevoEstado, motivo, contexto) {
        if (!ESTADOS_KANBAN.includes(nuevoEstado) &&
            nuevoEstado !== 'pendiente_aprobacion' &&
            nuevoEstado !== 'cancelado' &&
            nuevoEstado !== 'rechazado') {
            throw new common_1.BadRequestException('Estado no válido');
        }
        let catalogoCambios = [];
        const result = await this.database.enTransaccion(async (client) => {
            const pedido = await this.soporte.consultarUnoCliente(client, `SELECT id, estado, tipo, mesa_id, stock_descontado, created_at FROM pedidos
         WHERE id = $1 AND sucursal_id = $2
         FOR UPDATE`, [pedidoId, sucursalId]);
            if (!pedido) {
                throw new common_1.NotFoundException('Pedido no encontrado');
            }
            if (nuevoEstado === 'cancelado' && contexto) {
                this.soporte.validarCancelacion(pedido, contexto.rol, contexto.permisos, motivo);
            }
            const anterior = pedido.estado;
            if (anterior === nuevoEstado) {
                return {
                    id: pedidoId,
                    estado: nuevoEstado,
                    tipo: pedido.tipo,
                    mesa_id: pedido.mesa_id,
                };
            }
            if (!(0, pedido_estados_1.transicionEstadoPermitida)(anterior, nuevoEstado, pedido.tipo, pedido.mesa_id)) {
                throw new common_1.BadRequestException({
                    error: 'TRANSICION_ESTADO_INVALIDA',
                    message: `No se puede pasar de «${anterior}» a «${nuevoEstado}»`,
                });
            }
            if (nuevoEstado === 'pagando' &&
                !(0, pedido_estados_1.puedeMarcarPagando)(pedido.tipo, pedido.mesa_id)) {
                throw new common_1.BadRequestException({
                    error: 'PAGANDO_NO_APLICA',
                    message: 'Solo pedidos de mesa o para llevar pueden marcarse como pagando',
                });
            }
            if ((0, pedido_estados_1.estadoActivaCocina)(nuevoEstado) && !pedido.stock_descontado) {
                const lineas = await this.inventario.lineasDesdePedido(client, pedidoId, sucursalId);
                const stock = await this.inventario.descontarStockPedido(client, sucursalId, pedidoId, lineas, { incluirEmpaques: pedido.tipo === 'domicilio' });
                catalogoCambios.push(...stock.catalogo);
                await client.query(`UPDATE pedidos SET stock_descontado = true WHERE id = $1`, [pedidoId]);
            }
            if (nuevoEstado === 'cancelado' && pedido.stock_descontado) {
                const restaurado = await this.inventario.restaurarStockPedido(client, sucursalId, pedidoId);
                catalogoCambios.push(...restaurado);
                await client.query(`UPDATE pedidos SET stock_descontado = false WHERE id = $1`, [pedidoId]);
            }
            await client.query(`UPDATE pedidos SET estado = $1 WHERE id = $2`, [
                nuevoEstado,
                pedidoId,
            ]);
            if (nuevoEstado === 'en_cocina' &&
                pedido.mesa_id &&
                usuarioId &&
                ['pendiente_aprobacion', 'pendiente', 'confirmado'].includes(anterior)) {
                await this.soporte.assertMeseraPuedeTomarMesa(client, sucursalId, pedido.mesa_id, usuarioId);
                await client.query(`UPDATE pedidos SET mesera_id = COALESCE(mesera_id, $1), aprobado_at = COALESCE(aprobado_at, now())
           WHERE id = $2`, [usuarioId, pedidoId]);
                await this.soporte.asignarMeseraAMesa(client, sucursalId, pedido.mesa_id, usuarioId);
            }
            if (nuevoEstado === 'pagando' && pedido.mesa_id) {
                await this.cuentaMesa.marcarEstadoOperativoMesa(client, pedido.mesa_id, sucursalId, 'pagando');
            }
            if (['pagado', 'cancelado', 'rechazado'].includes(nuevoEstado) &&
                pedido.mesa_id) {
                await this.cuentaMesa.liberarMesaSiSinPedidosActivos(client, pedido.mesa_id, sucursalId);
            }
            await client.query(`INSERT INTO estados_pedido_historial
           (pedido_id, estado_anterior, estado_nuevo, usuario_id, motivo)
         VALUES ($1, $2, $3, $4, $5)`, [pedidoId, anterior, nuevoEstado, usuarioId, motivo ?? null]);
            if (nuevoEstado === 'cancelado') {
                await client.query(`UPDATE asignaciones_domicilio SET estado = 'entregado', entregado_at = COALESCE(entregado_at, now())
           WHERE pedido_id = $1 AND estado IN ('asignado', 'en_camino')`, [pedidoId]);
                await this.alertasRiesgo.evaluarCancelacionesFrecuentes(client, sucursalId, usuarioId, pedidoId);
            }
            return {
                id: pedidoId,
                estado: nuevoEstado,
                estado_anterior: anterior,
                tipo: pedido.tipo,
                mesa_id: pedido.mesa_id,
            };
        });
        if (nuevoEstado === 'listo' && result.tipo === 'domicilio') {
            try {
                await this.dispatch.intentarDispatchAutomatico(pedidoId, sucursalId);
            }
            catch {
            }
            void this.alertasRiesgo.registrar({
                sucursalId,
                tipo: 'domicilio_listo_sin_asignar',
                nivel: 'medio',
                descripcion: `Pedido listo — asignar domiciliario (${pedidoId})`,
                referenciaId: pedidoId,
                referenciaTipo: 'pedido',
                deduplicar: true,
            });
        }
        if (nuevoEstado === 'en_cocina' && result.estado_anterior !== 'en_cocina') {
            void this.soporte.notificarCocinasPorPedido(pedidoId, sucursalId);
        }
        const { tipo: _tipo, ...respuesta } = result;
        this.soporte.notificarPedidoRealtime(sucursalId, pedidoId, nuevoEstado);
        this.soporte.notificarCatalogoDisponibilidad(sucursalId, catalogoCambios);
        return respuesta;
    }
    async aprobarMesa(pedidoId, sucursalId, usuarioId) {
        let catalogoCambios = [];
        const result = await this.database.enTransaccion(async (client) => {
            const pedido = await this.soporte.consultarUnoCliente(client, `SELECT id, estado, mesa_id, tipo, stock_descontado
         FROM pedidos WHERE id = $1 AND sucursal_id = $2 FOR UPDATE`, [pedidoId, sucursalId]);
            if (!pedido)
                throw new common_1.NotFoundException('Pedido no encontrado');
            if (pedido.estado !== 'pendiente_aprobacion') {
                throw new common_1.BadRequestException('El pedido no está pendiente de aprobación');
            }
            if (pedido.mesa_id) {
                await this.soporte.assertMeseraPuedeTomarMesa(client, sucursalId, pedido.mesa_id, usuarioId);
            }
            if (!pedido.stock_descontado) {
                const lineas = await this.inventario.lineasDesdePedido(client, pedidoId, sucursalId);
                const stock = await this.inventario.descontarStockPedido(client, sucursalId, pedidoId, lineas, { incluirEmpaques: pedido.tipo === 'domicilio' });
                catalogoCambios.push(...stock.catalogo);
                await client.query(`UPDATE pedidos SET stock_descontado = true WHERE id = $1`, [pedidoId]);
            }
            await client.query(`UPDATE pedidos
         SET estado = 'en_cocina', mesera_id = $1, aprobado_at = now()
         WHERE id = $2`, [usuarioId, pedidoId]);
            if (pedido.mesa_id) {
                await this.soporte.asignarMeseraAMesa(client, sucursalId, pedido.mesa_id, usuarioId);
            }
            await client.query(`INSERT INTO estados_pedido_historial
           (pedido_id, estado_anterior, estado_nuevo, usuario_id)
         VALUES ($1, 'pendiente_aprobacion', 'en_cocina', $2)`, [pedidoId, usuarioId]);
            return { id: pedidoId, estado: 'en_cocina' };
        });
        this.soporte.notificarPedidoRealtime(sucursalId, pedidoId, 'en_cocina');
        this.soporte.notificarCatalogoDisponibilidad(sucursalId, catalogoCambios);
        void this.soporte.notificarCocinasPorPedido(pedidoId, sucursalId);
        return result;
    }
    async rechazarMesa(pedidoId, sucursalId, usuarioId, motivo) {
        return this.cambiarEstadoDesde(pedidoId, sucursalId, usuarioId, 'pendiente_aprobacion', 'rechazado', motivo);
    }
    async cambiarEstadoDesde(pedidoId, sucursalId, usuarioId, estadoEsperado, nuevoEstado, motivo) {
        let catalogoCambios = [];
        const result = await this.database.enTransaccion(async (client) => {
            const pedido = await this.soporte.consultarUnoCliente(client, `SELECT id, estado, mesa_id, stock_descontado
         FROM pedidos WHERE id = $1 AND sucursal_id = $2 FOR UPDATE`, [pedidoId, sucursalId]);
            if (!pedido)
                throw new common_1.NotFoundException('Pedido no encontrado');
            if (pedido.estado !== estadoEsperado) {
                throw new common_1.BadRequestException('El pedido no está pendiente de aprobación');
            }
            if (nuevoEstado === 'rechazado' && pedido.stock_descontado) {
                const restaurado = await this.inventario.restaurarStockPedido(client, sucursalId, pedidoId);
                catalogoCambios.push(...restaurado);
                await client.query(`UPDATE pedidos SET stock_descontado = false WHERE id = $1`, [pedidoId]);
            }
            if (nuevoEstado === 'rechazado') {
                await this.cajaAuditoria.revertirVentasPedido(client, pedidoId, sucursalId, usuarioId, motivo ?? 'Pedido rechazado');
            }
            await client.query(`UPDATE pedidos SET estado = $1 WHERE id = $2`, [
                nuevoEstado,
                pedidoId,
            ]);
            await client.query(`INSERT INTO estados_pedido_historial
           (pedido_id, estado_anterior, estado_nuevo, usuario_id, motivo)
         VALUES ($1,$2,$3,$4,$5)`, [pedidoId, estadoEsperado, nuevoEstado, usuarioId, motivo ?? null]);
            if (nuevoEstado === 'rechazado' && pedido.mesa_id) {
                await this.cuentaMesa.liberarMesaSiSinPedidosActivos(client, pedido.mesa_id, sucursalId);
            }
            return { id: pedidoId, estado: nuevoEstado };
        });
        this.soporte.notificarPedidoRealtime(sucursalId, pedidoId, nuevoEstado);
        this.soporte.notificarCatalogoDisponibilidad(sucursalId, catalogoCambios);
        return result;
    }
};
exports.PedidosEstadoService = PedidosEstadoService;
exports.PedidosEstadoService = PedidosEstadoService = __decorate([
    (0, common_1.Injectable)(),
    __metadata("design:paramtypes", [database_service_1.DatabaseService,
        dispatch_service_1.DispatchService,
        alertas_riesgo_service_1.AlertasRiesgoService,
        costeo_service_1.CosteoService,
        pedidos_caja_auditoria_service_1.PedidosCajaAuditoriaService,
        pedidos_cuenta_mesa_service_1.PedidosCuentaMesaService,
        pedidos_soporte_service_1.PedidosSoporteService])
], PedidosEstadoService);
//# sourceMappingURL=pedidos-estado.service.js.map