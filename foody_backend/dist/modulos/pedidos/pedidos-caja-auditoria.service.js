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
exports.PedidosCajaAuditoriaService = exports.METODOS_CON_CAJA = void 0;
exports.esPagoDiferidoMesa = esPagoDiferidoMesa;
const common_1 = require("@nestjs/common");
const caja_movimientos_service_1 = require("../../core/caja/caja-movimientos.service");
const auditoria_service_1 = require("../auditoria/auditoria.service");
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
    cajaMovimientos;
    auditoria;
    constructor(cajaMovimientos, auditoria) {
        this.cajaMovimientos = cajaMovimientos;
        this.auditoria = auditoria;
    }
    debeRegistrarVentaAlCrear(estadoInicial, tipo, mesaId, metodoPago) {
        if (!exports.METODOS_CON_CAJA.includes(metodoPago)) {
            return false;
        }
        if (estadoInicial === 'pendiente_aprobacion')
            return false;
        if (esPagoDiferidoMesa(tipo, mesaId))
            return false;
        if (tipo === 'domicilio')
            return false;
        return true;
    }
    obtenerCajaAbiertaId(client, sucursalId) {
        return this.cajaMovimientos.obtenerCajaAbiertaId(client, sucursalId);
    }
    async registrarVentaEnCaja(client, sucursalId, pedidoId, total, metodoPago, opciones) {
        if (!exports.METODOS_CON_CAJA.includes(metodoPago)) {
            return;
        }
        await this.cajaMovimientos.registrarVentaPedido(client, {
            sucursalId,
            pedidoId,
            monto: total,
            metodoPago,
            descripcion: opciones?.descripcion ?? 'Venta automática por pedido',
            usuarioId: opciones?.usuarioId ?? null,
        }, { exigirCaja: opciones?.exigirCaja ?? true });
    }
    revertirVentasPedido(client, pedidoId, sucursalId, usuarioId, motivo) {
        return this.cajaMovimientos.revertirVentasPedido(client, pedidoId, sucursalId, usuarioId, motivo);
    }
    async registrarAuditoria(client, sucursalId, pedidoId, datos) {
        await this.auditoria.registrarEnTransaccion(client, {
            sucursalId,
            accion: 'CREAR_PEDIDO',
            tablaAfectada: 'pedidos',
            registroId: pedidoId,
            datosDespues: datos,
        });
    }
    async registrarAuditoriaCobroMesa(client, sucursalId, mesaId, usuarioId, datos) {
        await this.auditoria.registrarEnTransaccion(client, {
            sucursalId,
            accion: 'COBRAR_CUENTA_MESA',
            tablaAfectada: 'mesas',
            registroId: mesaId,
            usuarioId,
            datosDespues: datos,
        });
    }
};
exports.PedidosCajaAuditoriaService = PedidosCajaAuditoriaService;
exports.PedidosCajaAuditoriaService = PedidosCajaAuditoriaService = __decorate([
    (0, common_1.Injectable)(),
    __metadata("design:paramtypes", [caja_movimientos_service_1.CajaMovimientosService,
        auditoria_service_1.AuditoriaService])
], PedidosCajaAuditoriaService);
//# sourceMappingURL=pedidos-caja-auditoria.service.js.map