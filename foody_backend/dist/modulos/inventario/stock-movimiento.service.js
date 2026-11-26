"use strict";
var __decorate = (this && this.__decorate) || function (decorators, target, key, desc) {
    var c = arguments.length, r = c < 3 ? target : desc === null ? desc = Object.getOwnPropertyDescriptor(target, key) : desc, d;
    if (typeof Reflect === "object" && typeof Reflect.decorate === "function") r = Reflect.decorate(decorators, target, key, desc);
    else for (var i = decorators.length - 1; i >= 0; i--) if (d = decorators[i]) r = (c < 3 ? d(r) : c > 3 ? d(target, key, r) : d(target, key)) || r;
    return c > 3 && r && Object.defineProperty(target, key, r), r;
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.StockMovimientoService = void 0;
const common_1 = require("@nestjs/common");
let StockMovimientoService = class StockMovimientoService {
    async aplicarMovimiento(p) {
        const { client, sucursalId, ingredienteId, tipo, cantidad, motivo, stockPosterior, pedidoId = null, pedidoItemId = null, usuarioId = null, produccionId = null, costoUnitarioActual, } = p;
        let stockAnterior = p.stockAnterior;
        let stockMinimo = 0;
        if (stockAnterior === undefined) {
            const fila = await client.query(`SELECT stock_actual, stock_minimo FROM ingredientes
         WHERE id = $1 AND sucursal_id = $2 FOR UPDATE`, [ingredienteId, sucursalId]);
            const row = fila.rows[0];
            if (!row) {
                throw new common_1.NotFoundException({
                    error: 'INGREDIENTE_NO_ENCONTRADO',
                    mensaje: 'Ingrediente no encontrado para movimiento de stock',
                });
            }
            stockAnterior = Number(row.stock_actual);
            stockMinimo = Number(row.stock_minimo);
        }
        if (stockPosterior !== stockAnterior) {
            if (costoUnitarioActual !== undefined) {
                await client.query(`UPDATE ingredientes
           SET stock_actual = $1, costo_unitario_actual = $2
           WHERE id = $3 AND sucursal_id = $4`, [stockPosterior, costoUnitarioActual, ingredienteId, sucursalId]);
            }
            else {
                await client.query(`UPDATE ingredientes
           SET stock_actual = $1
           WHERE id = $2 AND sucursal_id = $3`, [stockPosterior, ingredienteId, sucursalId]);
            }
        }
        else if (costoUnitarioActual !== undefined) {
            await client.query(`UPDATE ingredientes
         SET costo_unitario_actual = $1
         WHERE id = $2 AND sucursal_id = $3`, [costoUnitarioActual, ingredienteId, sucursalId]);
        }
        await client.query(`INSERT INTO movimientos_ingrediente (
         sucursal_id, ingrediente_id, pedido_id, pedido_item_id, tipo,
         cantidad, stock_anterior, stock_posterior, motivo,
         usuario_id, produccion_id
       ) VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11)`, [
            sucursalId,
            ingredienteId,
            pedidoId,
            pedidoItemId,
            tipo,
            cantidad,
            stockAnterior,
            stockPosterior,
            motivo,
            usuarioId,
            produccionId,
        ]);
        return {
            stockAnterior,
            stockPosterior,
            stockMinimo,
        };
    }
};
exports.StockMovimientoService = StockMovimientoService;
exports.StockMovimientoService = StockMovimientoService = __decorate([
    (0, common_1.Injectable)()
], StockMovimientoService);
//# sourceMappingURL=stock-movimiento.service.js.map