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
var __param = (this && this.__param) || function (paramIndex, decorator) {
    return function (target, key) { decorator(target, key, paramIndex); }
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.PedidosController = void 0;
const common_1 = require("@nestjs/common");
const permisos_decorator_1 = require("../../compartido/decoradores/permisos.decorator");
const usuario_actual_decorator_1 = require("../../compartido/decoradores/usuario-actual.decorator");
const jwt_payload_1 = require("../../core/auth/jwt-payload");
const jwt_auth_guard_1 = require("../../core/auth/guards/jwt-auth.guard");
const rol_guard_1 = require("../../core/auth/guards/rol.guard");
const suscripcion_activa_guard_1 = require("../../core/auth/guards/suscripcion-activa.guard");
const usuario_activo_guard_1 = require("../../core/auth/guards/usuario-activo.guard");
const sucursal_scope_service_1 = require("../../core/auth/sucursal-scope.service");
const cambiar_estado_pedido_dto_1 = require("./dto/cambiar-estado-pedido.dto");
const aplicar_descuento_dto_1 = require("./dto/aplicar-descuento.dto");
const crear_pedido_dto_1 = require("./dto/crear-pedido.dto");
const agregar_items_pedido_dto_1 = require("./dto/agregar-items-pedido.dto");
const reemplazar_item_pedido_dto_1 = require("./dto/reemplazar-item-pedido.dto");
const motivo_pedido_dto_1 = require("./dto/motivo-pedido.dto");
const actualizar_item_pedido_dto_1 = require("./dto/actualizar-item-pedido.dto");
const cobrar_mesa_dto_1 = require("./dto/cobrar-mesa.dto");
const actualizar_comensal_dto_1 = require("./dto/actualizar-comensal.dto");
const aprobar_pedido_mesa_dto_1 = require("./dto/aprobar-pedido-mesa.dto");
const listar_pedidos_query_dto_1 = require("./dto/listar-pedidos-query.dto");
const pedidos_service_1 = require("./pedidos.service");
let PedidosController = class PedidosController {
    pedidosService;
    sucursalScope;
    constructor(pedidosService, sucursalScope) {
        this.pedidosService = pedidosService;
        this.sucursalScope = sucursalScope;
    }
    async listar(usuario, query) {
        const id = await this.sucursalScope.resolverLecturaOperativa(usuario, query.sucursal_id);
        const paginar = query.page != null;
        return this.pedidosService.listarPorSucursal(id, {
            soloActivos: query.solo_activos !== false,
            paginar,
            page: paginar ? query.page : undefined,
            limite: query.limit,
            meseraId: query.mesera_id,
            busqueda: query.q,
        });
    }
    async listarCerradosHoy(usuario, query) {
        const id = await this.sucursalScope.resolverLecturaOperativa(usuario, query.sucursal_id);
        const paginar = query.page != null;
        return this.pedidosService.listarCerradosHoy(id, {
            meseraId: query.mesera_id,
            paginar,
            page: paginar ? query.page : undefined,
            limite: query.limit,
        });
    }
    async detalle(pedidoId, usuario, sucursalId) {
        const id = await this.sucursalScope.resolverLecturaOperativa(usuario, sucursalId);
        return this.pedidosService.obtenerDetalleAdmin(pedidoId, id);
    }
    async listarPorMesa(mesaId, usuario, sucursalId) {
        const id = await this.sucursalScope.resolverLecturaOperativa(usuario, sucursalId);
        return this.pedidosService.listarActivosPorMesa(id, mesaId);
    }
    async cobrarMesa(mesaId, usuario, dto, sucursalId) {
        const id = await this.sucursalScope.resolverEscritura(usuario, sucursalId);
        return this.pedidosService.cobrarCuentaMesa(id, mesaId, usuario.sub, dto, usuario.rol);
    }
    async crearStaff(dto, usuario) {
        return this.pedidosService.crearStaff(usuario, dto);
    }
    async agregarItems(pedidoId, dto, usuario, sucursalId) {
        const id = await this.sucursalScope.resolverEscritura(usuario, sucursalId);
        return this.pedidosService.agregarItems(pedidoId, id, dto, {
            creadoPorStaff: true,
            usuarioId: usuario.sub,
            rol: usuario.rol,
        });
    }
    async reemplazarItem(pedidoId, itemId, dto, usuario, sucursalId) {
        const id = await this.sucursalScope.resolverEscritura(usuario, sucursalId);
        return this.pedidosService.reemplazarItemPedido(pedidoId, itemId, id, usuario.sub, dto, { creadoPorStaff: true, usuarioId: usuario.sub, rol: usuario.rol });
    }
    async actualizarItem(pedidoId, itemId, dto, usuario, sucursalId) {
        const id = await this.sucursalScope.resolverEscritura(usuario, sucursalId);
        return this.pedidosService.actualizarItemPedido(pedidoId, itemId, id, usuario.sub, dto);
    }
    async eliminarItem(pedidoId, itemId, usuario, body, sucursalId) {
        const id = await this.sucursalScope.resolverEscritura(usuario, sucursalId);
        return this.pedidosService.eliminarItemPedido(pedidoId, itemId, id, usuario.sub, body.motivo);
    }
    async cambiarEstado(pedidoId, usuario, dto, sucursalId) {
        const id = await this.sucursalScope.resolverEscritura(usuario, sucursalId);
        return this.pedidosService.cambiarEstado(pedidoId, id, usuario.sub, dto.estado, dto.motivo, { rol: usuario.rol, permisos: usuario.permisos ?? [] });
    }
    async aplicarDescuento(pedidoId, usuario, dto, sucursalId) {
        const id = await this.sucursalScope.resolverEscritura(usuario, sucursalId);
        return this.pedidosService.aplicarDescuento(pedidoId, id, usuario.sub, dto, { rol: usuario.rol, permisos: usuario.permisos ?? [] });
    }
    async cobrarPedido(pedidoId, usuario, dto, sucursalId) {
        const id = await this.sucursalScope.resolverEscritura(usuario, sucursalId);
        return this.pedidosService.cobrarPedidoCaja(pedidoId, id, usuario.sub, dto, usuario.rol);
    }
    async actualizarComensal(pedidoId, itemId, usuario, dto, sucursalId) {
        const id = await this.sucursalScope.resolverEscritura(usuario, sucursalId);
        return this.pedidosService.actualizarComensalItem(pedidoId, itemId, id, dto.comensal_etiqueta ?? null);
    }
    async aprobar(pedidoId, usuario, body, sucursalId) {
        const id = await this.sucursalScope.resolverEscritura(usuario, sucursalId);
        return this.pedidosService.aprobarMesa(pedidoId, id, usuario.sub, {
            meseraId: body?.mesera_id,
            rolLlamador: usuario.rol,
        });
    }
    async rechazar(pedidoId, usuario, body, sucursalId) {
        const id = await this.sucursalScope.resolverEscritura(usuario, sucursalId);
        return this.pedidosService.rechazarMesa(pedidoId, id, usuario.sub, body.motivo ?? 'Rechazado por mesero');
    }
};
exports.PedidosController = PedidosController;
__decorate([
    (0, common_1.Get)(),
    (0, permisos_decorator_1.Permisos)('ver_pedidos'),
    __param(0, (0, usuario_actual_decorator_1.UsuarioActual)()),
    __param(1, (0, common_1.Query)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [jwt_payload_1.JwtPayload,
        listar_pedidos_query_dto_1.ListarPedidosQueryDto]),
    __metadata("design:returntype", Promise)
], PedidosController.prototype, "listar", null);
__decorate([
    (0, common_1.Get)('cerrados-hoy'),
    (0, permisos_decorator_1.Permisos)('ver_pedidos'),
    __param(0, (0, usuario_actual_decorator_1.UsuarioActual)()),
    __param(1, (0, common_1.Query)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [jwt_payload_1.JwtPayload,
        listar_pedidos_query_dto_1.ListarCerradosHoyQueryDto]),
    __metadata("design:returntype", Promise)
], PedidosController.prototype, "listarCerradosHoy", null);
__decorate([
    (0, common_1.Get)(':id/detalle'),
    (0, permisos_decorator_1.Permisos)('ver_pedidos'),
    __param(0, (0, common_1.Param)('id', common_1.ParseUUIDPipe)),
    __param(1, (0, usuario_actual_decorator_1.UsuarioActual)()),
    __param(2, (0, common_1.Query)('sucursal_id')),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, jwt_payload_1.JwtPayload, String]),
    __metadata("design:returntype", Promise)
], PedidosController.prototype, "detalle", null);
__decorate([
    (0, common_1.Get)('mesa/:mesaId'),
    (0, permisos_decorator_1.Permisos)('ver_pedidos'),
    __param(0, (0, common_1.Param)('mesaId', common_1.ParseUUIDPipe)),
    __param(1, (0, usuario_actual_decorator_1.UsuarioActual)()),
    __param(2, (0, common_1.Query)('sucursal_id')),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, jwt_payload_1.JwtPayload, String]),
    __metadata("design:returntype", Promise)
], PedidosController.prototype, "listarPorMesa", null);
__decorate([
    (0, common_1.Post)('mesa/:mesaId/cobrar'),
    (0, permisos_decorator_1.Permisos)('cobrar_pedido'),
    __param(0, (0, common_1.Param)('mesaId', common_1.ParseUUIDPipe)),
    __param(1, (0, usuario_actual_decorator_1.UsuarioActual)()),
    __param(2, (0, common_1.Body)()),
    __param(3, (0, common_1.Query)('sucursal_id')),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, jwt_payload_1.JwtPayload,
        cobrar_mesa_dto_1.CobrarMesaDto, String]),
    __metadata("design:returntype", Promise)
], PedidosController.prototype, "cobrarMesa", null);
__decorate([
    (0, common_1.Post)('staff'),
    (0, common_1.HttpCode)(common_1.HttpStatus.CREATED),
    (0, permisos_decorator_1.Permisos)('crear_pedido'),
    __param(0, (0, common_1.Body)()),
    __param(1, (0, usuario_actual_decorator_1.UsuarioActual)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [crear_pedido_dto_1.CrearPedidoDto,
        jwt_payload_1.JwtPayload]),
    __metadata("design:returntype", Promise)
], PedidosController.prototype, "crearStaff", null);
__decorate([
    (0, common_1.Post)(':id/items'),
    (0, permisos_decorator_1.Permisos)('crear_pedido'),
    __param(0, (0, common_1.Param)('id', common_1.ParseUUIDPipe)),
    __param(1, (0, common_1.Body)()),
    __param(2, (0, usuario_actual_decorator_1.UsuarioActual)()),
    __param(3, (0, common_1.Query)('sucursal_id')),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, agregar_items_pedido_dto_1.AgregarItemsPedidoDto,
        jwt_payload_1.JwtPayload, String]),
    __metadata("design:returntype", Promise)
], PedidosController.prototype, "agregarItems", null);
__decorate([
    (0, common_1.Post)(':id/items/:itemId/reemplazar'),
    (0, permisos_decorator_1.Permisos)('crear_pedido'),
    __param(0, (0, common_1.Param)('id', common_1.ParseUUIDPipe)),
    __param(1, (0, common_1.Param)('itemId', common_1.ParseUUIDPipe)),
    __param(2, (0, common_1.Body)()),
    __param(3, (0, usuario_actual_decorator_1.UsuarioActual)()),
    __param(4, (0, common_1.Query)('sucursal_id')),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, String, reemplazar_item_pedido_dto_1.ReemplazarItemPedidoDto,
        jwt_payload_1.JwtPayload, String]),
    __metadata("design:returntype", Promise)
], PedidosController.prototype, "reemplazarItem", null);
__decorate([
    (0, common_1.Patch)(':id/items/:itemId'),
    (0, permisos_decorator_1.Permisos)('crear_pedido'),
    __param(0, (0, common_1.Param)('id', common_1.ParseUUIDPipe)),
    __param(1, (0, common_1.Param)('itemId', common_1.ParseUUIDPipe)),
    __param(2, (0, common_1.Body)()),
    __param(3, (0, usuario_actual_decorator_1.UsuarioActual)()),
    __param(4, (0, common_1.Query)('sucursal_id')),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, String, actualizar_item_pedido_dto_1.ActualizarItemPedidoDto,
        jwt_payload_1.JwtPayload, String]),
    __metadata("design:returntype", Promise)
], PedidosController.prototype, "actualizarItem", null);
__decorate([
    (0, common_1.Delete)(':id/items/:itemId'),
    (0, permisos_decorator_1.Permisos)('crear_pedido'),
    __param(0, (0, common_1.Param)('id', common_1.ParseUUIDPipe)),
    __param(1, (0, common_1.Param)('itemId', common_1.ParseUUIDPipe)),
    __param(2, (0, usuario_actual_decorator_1.UsuarioActual)()),
    __param(3, (0, common_1.Body)()),
    __param(4, (0, common_1.Query)('sucursal_id')),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, String, jwt_payload_1.JwtPayload,
        motivo_pedido_dto_1.EliminarItemPedidoDto, String]),
    __metadata("design:returntype", Promise)
], PedidosController.prototype, "eliminarItem", null);
__decorate([
    (0, common_1.Patch)(':id/estado'),
    (0, permisos_decorator_1.Permisos)('crear_pedido'),
    __param(0, (0, common_1.Param)('id', common_1.ParseUUIDPipe)),
    __param(1, (0, usuario_actual_decorator_1.UsuarioActual)()),
    __param(2, (0, common_1.Body)()),
    __param(3, (0, common_1.Query)('sucursal_id')),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, jwt_payload_1.JwtPayload,
        cambiar_estado_pedido_dto_1.CambiarEstadoPedidoDto, String]),
    __metadata("design:returntype", Promise)
], PedidosController.prototype, "cambiarEstado", null);
__decorate([
    (0, common_1.Post)(':id/descuento'),
    (0, permisos_decorator_1.Permisos)('aplicar_descuento'),
    __param(0, (0, common_1.Param)('id', common_1.ParseUUIDPipe)),
    __param(1, (0, usuario_actual_decorator_1.UsuarioActual)()),
    __param(2, (0, common_1.Body)()),
    __param(3, (0, common_1.Query)('sucursal_id')),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, jwt_payload_1.JwtPayload,
        aplicar_descuento_dto_1.AplicarDescuentoDto, String]),
    __metadata("design:returntype", Promise)
], PedidosController.prototype, "aplicarDescuento", null);
__decorate([
    (0, common_1.Post)(':id/cobrar'),
    (0, permisos_decorator_1.Permisos)('cobrar_pedido'),
    __param(0, (0, common_1.Param)('id', common_1.ParseUUIDPipe)),
    __param(1, (0, usuario_actual_decorator_1.UsuarioActual)()),
    __param(2, (0, common_1.Body)()),
    __param(3, (0, common_1.Query)('sucursal_id')),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, jwt_payload_1.JwtPayload,
        cobrar_mesa_dto_1.CobrarMesaDto, String]),
    __metadata("design:returntype", Promise)
], PedidosController.prototype, "cobrarPedido", null);
__decorate([
    (0, common_1.Patch)(':id/items/:itemId/comensal'),
    (0, permisos_decorator_1.Permisos)('crear_pedido', 'ver_pedidos'),
    __param(0, (0, common_1.Param)('id', common_1.ParseUUIDPipe)),
    __param(1, (0, common_1.Param)('itemId', common_1.ParseUUIDPipe)),
    __param(2, (0, usuario_actual_decorator_1.UsuarioActual)()),
    __param(3, (0, common_1.Body)()),
    __param(4, (0, common_1.Query)('sucursal_id')),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, String, jwt_payload_1.JwtPayload,
        actualizar_comensal_dto_1.ActualizarComensalDto, String]),
    __metadata("design:returntype", Promise)
], PedidosController.prototype, "actualizarComensal", null);
__decorate([
    (0, common_1.Patch)(':id/aprobar'),
    (0, permisos_decorator_1.Permisos)('aprobar_pedido_mesa'),
    __param(0, (0, common_1.Param)('id', common_1.ParseUUIDPipe)),
    __param(1, (0, usuario_actual_decorator_1.UsuarioActual)()),
    __param(2, (0, common_1.Body)()),
    __param(3, (0, common_1.Query)('sucursal_id')),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, jwt_payload_1.JwtPayload,
        aprobar_pedido_mesa_dto_1.AprobarPedidoMesaDto, String]),
    __metadata("design:returntype", Promise)
], PedidosController.prototype, "aprobar", null);
__decorate([
    (0, common_1.Patch)(':id/rechazar'),
    (0, permisos_decorator_1.Permisos)('aprobar_pedido_mesa'),
    __param(0, (0, common_1.Param)('id', common_1.ParseUUIDPipe)),
    __param(1, (0, usuario_actual_decorator_1.UsuarioActual)()),
    __param(2, (0, common_1.Body)()),
    __param(3, (0, common_1.Query)('sucursal_id')),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, jwt_payload_1.JwtPayload,
        motivo_pedido_dto_1.RechazarPedidoMesaDto, String]),
    __metadata("design:returntype", Promise)
], PedidosController.prototype, "rechazar", null);
exports.PedidosController = PedidosController = __decorate([
    (0, common_1.Controller)('pedidos'),
    (0, common_1.UseGuards)(jwt_auth_guard_1.JwtAuthGuard, usuario_activo_guard_1.UsuarioActivoGuard, suscripcion_activa_guard_1.SuscripcionActivaGuard, rol_guard_1.RolGuard),
    __metadata("design:paramtypes", [pedidos_service_1.PedidosService,
        sucursal_scope_service_1.SucursalScopeService])
], PedidosController);
//# sourceMappingURL=pedidos.controller.js.map