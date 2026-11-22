"use strict";
var __decorate = (this && this.__decorate) || function (decorators, target, key, desc) {
    var c = arguments.length, r = c < 3 ? target : desc === null ? desc = Object.getOwnPropertyDescriptor(target, key) : desc, d;
    if (typeof Reflect === "object" && typeof Reflect.decorate === "function") r = Reflect.decorate(decorators, target, key, desc);
    else for (var i = decorators.length - 1; i >= 0; i--) if (d = decorators[i]) r = (c < 3 ? d(r) : c > 3 ? d(target, key, r) : d(target, key)) || r;
    return c > 3 && r && Object.defineProperty(target, key, r), r;
};
var CajaMovimientosService_1;
Object.defineProperty(exports, "__esModule", { value: true });
exports.CajaMovimientosService = void 0;
const common_1 = require("@nestjs/common");
let CajaMovimientosService = CajaMovimientosService_1 = class CajaMovimientosService {
    logger = new common_1.Logger(CajaMovimientosService_1.name);
    async obtenerCajaAbiertaId(client, sucursalId) {
        const caja = await client.query(`SELECT id FROM cajas
       WHERE sucursal_id = $1 AND estado = 'abierta'
       ORDER BY apertura_at DESC
       LIMIT 1`, [sucursalId]);
        return caja.rows[0]?.id ?? null;
    }
    async insertar(client, params) {
        await client.query(`INSERT INTO movimientos_caja (
         caja_id, sucursal_id, pedido_id, tipo, monto, metodo_pago, descripcion, usuario_id
       ) VALUES ($1,$2,$3,$4,$5,$6,$7,$8)`, [
            params.cajaId,
            params.sucursalId,
            params.pedidoId ?? null,
            params.tipo,
            params.monto,
            params.metodoPago ?? null,
            params.descripcion ?? null,
            params.usuarioId ?? null,
        ]);
    }
    async registrarVentaPedido(client, params, opciones = {}) {
        const exigirCaja = opciones.exigirCaja ?? true;
        const tope = await client.query(`SELECT COALESCE(SUM(mc.monto), 0) AS registrado, p.total
       FROM pedidos p
       LEFT JOIN movimientos_caja mc
         ON mc.pedido_id = p.id AND mc.tipo = 'venta'
       WHERE p.id = $1
       GROUP BY p.total`, [params.pedidoId]);
        const registrado = Number(tope.rows[0]?.registrado ?? 0);
        const totalPedido = Number(tope.rows[0]?.total ?? 0);
        const pendienteCaja = Math.max(0, totalPedido - registrado);
        const montoEfectivo = Math.min(params.monto, pendienteCaja);
        if (montoEfectivo <= 0.01) {
            return false;
        }
        const cajaId = await this.obtenerCajaAbiertaId(client, params.sucursalId);
        if (!cajaId) {
            if (exigirCaja) {
                throw new common_1.BadRequestException({
                    error: 'CAJA_NO_ABIERTA',
                    mensaje: 'No hay caja abierta en la sucursal. Abre caja antes de registrar la venta.',
                });
            }
            this.logger.warn(`Venta pedido ${params.pedidoId} no registrada en caja: sin turno abierto (sucursal ${params.sucursalId})`);
            return false;
        }
        await this.insertar(client, {
            cajaId,
            sucursalId: params.sucursalId,
            pedidoId: params.pedidoId,
            tipo: 'venta',
            monto: montoEfectivo,
            metodoPago: params.metodoPago,
            descripcion: params.descripcion ?? 'Venta por pedido',
            usuarioId: params.usuarioId ?? null,
        });
        return true;
    }
    async netoCobradoPedidoEnCaja(client, pedidoId, cajaId) {
        const fila = await client.query(`SELECT COALESCE(SUM(
         CASE
           WHEN tipo = 'venta' THEN monto
           WHEN tipo = 'devolucion' THEN -monto
           ELSE 0
         END
       ), 0)::text AS neto
       FROM movimientos_caja
       WHERE pedido_id = $1
         ${cajaId ? 'AND caja_id = $2' : ''}`, cajaId ? [pedidoId, cajaId] : [pedidoId]);
        return Number(fila.rows[0]?.neto ?? 0);
    }
    async netoVentasDisponiblesTurno(client, cajaId) {
        const fila = await client.query(`SELECT COALESCE(SUM(
         CASE
           WHEN tipo = 'venta' THEN monto
           WHEN tipo = 'devolucion' THEN -monto
           ELSE 0
         END
       ), 0)::text AS neto
       FROM movimientos_caja
       WHERE caja_id = $1`, [cajaId]);
        return Number(fila.rows[0]?.neto ?? 0);
    }
    async revertirVentasPedido(client, pedidoId, sucursalId, usuarioId, motivo) {
        const ventas = await client.query(`SELECT id, monto, metodo_pago, caja_id FROM movimientos_caja
       WHERE pedido_id = $1 AND tipo = 'venta'`, [pedidoId]);
        const neto = await this.netoCobradoPedidoEnCaja(client, pedidoId);
        if (neto < 0.01) {
            return { movimientos: 0, monto_total: 0 };
        }
        const referencia = ventas.rows[0];
        await this.insertar(client, {
            cajaId: referencia.caja_id,
            sucursalId,
            pedidoId,
            tipo: 'devolucion',
            monto: neto,
            metodoPago: referencia.metodo_pago,
            descripcion: motivo?.trim() || 'Reversa venta pedido',
            usuarioId: usuarioId ?? null,
        });
        return { movimientos: 1, monto_total: neto };
    }
};
exports.CajaMovimientosService = CajaMovimientosService;
exports.CajaMovimientosService = CajaMovimientosService = CajaMovimientosService_1 = __decorate([
    (0, common_1.Injectable)()
], CajaMovimientosService);
//# sourceMappingURL=caja-movimientos.service.js.map