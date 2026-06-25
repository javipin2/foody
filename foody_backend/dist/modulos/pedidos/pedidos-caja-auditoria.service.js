"use strict";
var __decorate = (this && this.__decorate) || function (decorators, target, key, desc) {
    var c = arguments.length, r = c < 3 ? target : desc === null ? desc = Object.getOwnPropertyDescriptor(target, key) : desc, d;
    if (typeof Reflect === "object" && typeof Reflect.decorate === "function") r = Reflect.decorate(decorators, target, key, desc);
    else for (var i = decorators.length - 1; i >= 0; i--) if (d = decorators[i]) r = (c < 3 ? d(r) : c > 3 ? d(target, key, r) : d(target, key)) || r;
    return c > 3 && r && Object.defineProperty(target, key, r), r;
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.PedidosCajaAuditoriaService = exports.METODOS_CON_CAJA = void 0;
exports.esPagoDiferidoMesa = esPagoDiferidoMesa;
const common_1 = require("@nestjs/common");
exports.METODOS_CON_CAJA = [
    'efectivo',
    'tarjeta',
    'transferencia',
    'nequi',
];
function esPagoDiferidoMesa(tipo, mesaId) {
    return tipo === 'mesa' || mesaId != null;
}
let PedidosCajaAuditoriaService = class PedidosCajaAuditoriaService {
    debeRegistrarVentaAlCrear(estadoInicial, tipo, mesaId, metodoPago) {
        if (!exports.METODOS_CON_CAJA.includes(metodoPago)) {
            return false;
        }
        if (estadoInicial === 'pendiente_aprobacion')
            return false;
        if (esPagoDiferidoMesa(tipo, mesaId))
            return false;
        return true;
    }
    async obtenerCajaAbiertaId(client, sucursalId) {
        const caja = await client.query(`SELECT id FROM cajas
       WHERE sucursal_id = $1 AND estado = 'abierta'
       ORDER BY apertura_at DESC
       LIMIT 1`, [sucursalId]);
        return caja.rows[0]?.id ?? null;
    }
    async registrarVentaEnCaja(client, sucursalId, pedidoId, total, metodoPago, opciones) {
        if (!exports.METODOS_CON_CAJA.includes(metodoPago)) {
            return;
        }
        const cajaId = await this.obtenerCajaAbiertaId(client, sucursalId);
        if (!cajaId) {
            if (opciones?.exigirCaja) {
                throw new common_1.BadRequestException({
                    error: 'CAJA_NO_ABIERTA',
                    message: 'No hay caja abierta en la sucursal. Abre caja antes de registrar la venta.',
                });
            }
            return;
        }
        await client.query(`INSERT INTO movimientos_caja (
         caja_id, sucursal_id, pedido_id, tipo, monto, metodo_pago, descripcion
       ) VALUES ($1,$2,$3,'venta',$4,$5,$6)`, [
            cajaId,
            sucursalId,
            pedidoId,
            total,
            metodoPago,
            opciones?.descripcion ?? 'Venta automática por pedido',
        ]);
    }
    async revertirVentasPedido(client, pedidoId, sucursalId, usuarioId, motivo) {
        const ventas = await client.query(`SELECT id, monto, metodo_pago, caja_id FROM movimientos_caja
       WHERE pedido_id = $1 AND tipo = 'venta'`, [pedidoId]);
        let n = 0;
        for (const v of ventas.rows) {
            await client.query(`INSERT INTO movimientos_caja (
           caja_id, sucursal_id, pedido_id, tipo, monto, metodo_pago, descripcion, usuario_id
         ) VALUES ($1,$2,$3,'devolucion',$4,$5,$6,$7)`, [
                v.caja_id,
                sucursalId,
                pedidoId,
                Number(v.monto),
                v.metodo_pago,
                motivo?.trim() || 'Reversa venta pedido',
                usuarioId ?? null,
            ]);
            await client.query(`DELETE FROM movimientos_caja WHERE id = $1`, [v.id]);
            n++;
        }
        return n;
    }
    async registrarAuditoria(client, sucursalId, pedidoId, datos) {
        await client.query(`INSERT INTO auditoria_logs (
         sucursal_id, accion, tabla_afectada, registro_id, datos_despues
       ) VALUES ($1,'CREAR_PEDIDO','pedidos',$2,$3::jsonb)`, [sucursalId, pedidoId, JSON.stringify(datos)]);
    }
    async registrarAuditoriaCobroMesa(client, sucursalId, mesaId, usuarioId, datos) {
        await client.query(`INSERT INTO auditoria_logs (
         sucursal_id, accion, tabla_afectada, registro_id, usuario_id, datos_despues
       ) VALUES ($1,'COBRAR_CUENTA_MESA','mesas',$2,$3,$4::jsonb)`, [sucursalId, mesaId, usuarioId, JSON.stringify(datos)]);
    }
};
exports.PedidosCajaAuditoriaService = PedidosCajaAuditoriaService;
exports.PedidosCajaAuditoriaService = PedidosCajaAuditoriaService = __decorate([
    (0, common_1.Injectable)()
], PedidosCajaAuditoriaService);
//# sourceMappingURL=pedidos-caja-auditoria.service.js.map