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
exports.PedidosService = void 0;
const common_1 = require("@nestjs/common");
const database_service_1 = require("../../core/database/database.service");
const pedidos_cuenta_mesa_service_1 = require("./pedidos-cuenta-mesa.service");
const pedidos_crear_service_1 = require("./pedidos-crear.service");
const pedidos_descuento_service_1 = require("./pedidos-descuento.service");
const pedidos_estado_service_1 = require("./pedidos-estado.service");
const pedidos_items_service_1 = require("./pedidos-items.service");
const pedidos_pagos_service_1 = require("./pedidos-pagos.service");
let PedidosService = class PedidosService {
    database;
    cuentaMesa;
    estado;
    crearPedido;
    items;
    descuento;
    pagos;
    constructor(database, cuentaMesa, estado, crearPedido, items, descuento, pagos) {
        this.database = database;
        this.cuentaMesa = cuentaMesa;
        this.estado = estado;
        this.crearPedido = crearPedido;
        this.items = items;
        this.descuento = descuento;
        this.pagos = pagos;
    }
    async listarPorSucursal(sucursalId, opciones = {}) {
        const limite = opciones.limite ?? 100;
        const filtroActivos = opciones.soloActivos
            ? `AND p.estado IN ('pendiente', 'pendiente_aprobacion', 'confirmado', 'en_cocina', 'listo', 'pagando', 'asignado', 'en_camino')`
            : '';
        return this.database.consultar(`SELECT p.id, p.numero_pedido, p.tipo, p.estado, p.cliente_nombre,
              p.cliente_telefono, p.direccion_entrega, p.total, p.created_at, p.mesa_id,
              m.nombre AS mesa_nombre,
              u_dom.nombre AS domiciliario_nombre,
              COALESCE(h.fecha, p.created_at) AS estado_desde
       FROM pedidos p
       LEFT JOIN mesas m ON m.id = p.mesa_id
       LEFT JOIN LATERAL (
         SELECT ad.domiciliario_planta_id
         FROM asignaciones_domicilio ad
         WHERE ad.pedido_id = p.id
           AND ad.estado IN ('asignado', 'en_camino', 'entregado')
         ORDER BY ad.asignado_at DESC
         LIMIT 1
       ) ad ON true
       LEFT JOIN domiciliarios_planta dp ON dp.id = ad.domiciliario_planta_id
       LEFT JOIN usuarios u_dom ON u_dom.id = dp.usuario_id
       LEFT JOIN LATERAL (
         SELECT fecha FROM estados_pedido_historial
         WHERE pedido_id = p.id AND estado_nuevo = p.estado
         ORDER BY fecha DESC
         LIMIT 1
       ) h ON true
       WHERE p.sucursal_id = $1 ${filtroActivos}
       ORDER BY p.created_at DESC
       LIMIT $2`, [sucursalId, limite]);
    }
    async listarActivosPorMesa(sucursalId, mesaId) {
        return this.cuentaMesa.listarActivosPorMesa(sucursalId, mesaId);
    }
    async cambiarEstado(pedidoId, sucursalId, usuarioId, nuevoEstado, motivo, contexto) {
        return this.estado.cambiarEstado(pedidoId, sucursalId, usuarioId, nuevoEstado, motivo, contexto);
    }
    async crear(dto, opciones = {}) {
        return this.crearPedido.crear(dto, opciones);
    }
    async agregarItems(pedidoId, sucursalId, dto, opciones = {}) {
        return this.items.agregarItems(pedidoId, sucursalId, dto, opciones);
    }
    async cobrarCuentaMesa(sucursalId, mesaId, usuarioId, dto = {}) {
        return this.pagos.cobrarCuentaMesa(sucursalId, mesaId, usuarioId, dto);
    }
    async cobrarPedidoCaja(pedidoId, sucursalId, usuarioId, dto = {}) {
        return this.pagos.cobrarPedidoCaja(sucursalId, pedidoId, usuarioId, dto);
    }
    async actualizarComensalItem(pedidoId, itemId, sucursalId, comensalEtiqueta) {
        return this.items.actualizarComensalEtiqueta(pedidoId, itemId, sucursalId, comensalEtiqueta);
    }
    async listarPorDevice(deviceId) {
        return this.database.consultar(`SELECT p.id, p.numero_pedido, p.estado, p.tipo, p.total,
              p.created_at, s.nombre AS sucursal_nombre
       FROM pedidos p
       INNER JOIN sucursales s ON s.id = p.sucursal_id
       WHERE p.device_id = $1
       ORDER BY p.created_at DESC
       LIMIT 50`, [deviceId]);
    }
    async obtenerEstadoPublico(pedidoId) {
        const pedido = await this.database.consultarUno(`SELECT id, numero_pedido, estado, total, tipo, lat, lng, direccion_entrega,
              tiempo_estimado_minutos, created_at
       FROM pedidos WHERE id = $1`, [pedidoId]);
        if (!pedido)
            throw new common_1.NotFoundException('Pedido no encontrado');
        const historial = await this.database.consultar(`SELECT estado_nuevo, fecha FROM estados_pedido_historial
       WHERE pedido_id = $1 ORDER BY fecha ASC`, [pedidoId]);
        return {
            pedido_id: pedido.id,
            numero_pedido: pedido.numero_pedido,
            estado_actual: pedido.estado,
            tipo: pedido.tipo,
            total: Number(pedido.total),
            lat: pedido.lat != null ? Number(pedido.lat) : null,
            lng: pedido.lng != null ? Number(pedido.lng) : null,
            direccion_entrega: pedido.direccion_entrega,
            tiempo_estimado_minutos: pedido.tiempo_estimado_minutos,
            historial: historial.map((h) => ({
                estado: h.estado_nuevo,
                fecha: h.fecha,
            })),
        };
    }
    async aprobarMesa(pedidoId, sucursalId, usuarioId) {
        return this.estado.aprobarMesa(pedidoId, sucursalId, usuarioId);
    }
    async rechazarMesa(pedidoId, sucursalId, usuarioId, motivo) {
        return this.estado.rechazarMesa(pedidoId, sucursalId, usuarioId, motivo);
    }
    async aplicarDescuento(pedidoId, sucursalId, usuarioId, dto, contexto) {
        return this.descuento.aplicarDescuento(pedidoId, sucursalId, usuarioId, dto, contexto);
    }
    async eliminarItemPedido(pedidoId, itemId, sucursalId, usuarioId, motivo) {
        return this.items.eliminarItemPedido(pedidoId, itemId, sucursalId, usuarioId, motivo);
    }
};
exports.PedidosService = PedidosService;
exports.PedidosService = PedidosService = __decorate([
    (0, common_1.Injectable)(),
    __metadata("design:paramtypes", [database_service_1.DatabaseService,
        pedidos_cuenta_mesa_service_1.PedidosCuentaMesaService,
        pedidos_estado_service_1.PedidosEstadoService,
        pedidos_crear_service_1.PedidosCrearService,
        pedidos_items_service_1.PedidosItemsService,
        pedidos_descuento_service_1.PedidosDescuentoService,
        pedidos_pagos_service_1.PedidosPagosService])
], PedidosService);
//# sourceMappingURL=pedidos.service.js.map