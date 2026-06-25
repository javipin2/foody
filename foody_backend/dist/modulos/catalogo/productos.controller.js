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
exports.ProductosController = void 0;
const common_1 = require("@nestjs/common");
const permisos_decorator_1 = require("../../compartido/decoradores/permisos.decorator");
const usuario_actual_decorator_1 = require("../../compartido/decoradores/usuario-actual.decorator");
const jwt_payload_1 = require("../../core/auth/jwt-payload");
const jwt_auth_guard_1 = require("../../core/auth/guards/jwt-auth.guard");
const rol_guard_1 = require("../../core/auth/guards/rol.guard");
const suscripcion_activa_guard_1 = require("../../core/auth/guards/suscripcion-activa.guard");
const usuario_activo_guard_1 = require("../../core/auth/guards/usuario-activo.guard");
const sucursal_scope_service_1 = require("../../core/auth/sucursal-scope.service");
const catalogo_service_1 = require("./catalogo.service");
const actualizar_producto_dto_1 = require("./dto/actualizar-producto.dto");
const crear_producto_dto_1 = require("./dto/crear-producto.dto");
const configurar_items_incluidos_dto_1 = require("./dto/configurar-items-incluidos.dto");
let ProductosController = class ProductosController {
    catalogo;
    sucursalScope;
    constructor(catalogo, sucursalScope) {
        this.catalogo = catalogo;
        this.sucursalScope = sucursalScope;
    }
    async listar(sucursalId, usuario) {
        await this.sucursalScope.validarLecturaOperativa(usuario, sucursalId);
        return this.catalogo.listarProductos(sucursalId);
    }
    async crear(dto, usuario) {
        await this.sucursalScope.validarEscritura(usuario, dto.sucursal_id);
        return this.catalogo.crearProducto(dto);
    }
    async disponibilidad(id, body, usuario) {
        const sid = await this.sucursalScope.resolverEscritura(usuario);
        return this.catalogo.cambiarDisponibilidad(id, sid, body.disponible);
    }
    async vincularTopping(productoId, body, usuario) {
        const sid = await this.sucursalScope.resolverEscritura(usuario);
        return this.catalogo.vincularToppingProducto(productoId, body.topping_id, sid);
    }
    async vincularBebida(productoId, body, usuario) {
        const sid = await this.sucursalScope.resolverEscritura(usuario);
        return this.catalogo.vincularBebidaProducto(productoId, body.bebida_id, sid);
    }
    async listarItemsIncluidos(id, usuario) {
        const sid = await this.sucursalScope.resolverEscritura(usuario);
        return this.catalogo.listarItemsIncluidos(id, sid);
    }
    async configurarItemsIncluidos(id, dto, usuario) {
        const sid = await this.sucursalScope.resolverEscritura(usuario);
        return this.catalogo.configurarItemsIncluidos(id, sid, dto);
    }
    async actualizar(id, dto, usuario) {
        const sid = await this.sucursalScope.resolverEscritura(usuario);
        return this.catalogo.actualizarProducto(id, sid, dto);
    }
};
exports.ProductosController = ProductosController;
__decorate([
    (0, common_1.Get)('sucursal/:sucursal_id'),
    (0, permisos_decorator_1.Permisos)('editar_productos'),
    __param(0, (0, common_1.Param)('sucursal_id')),
    __param(1, (0, usuario_actual_decorator_1.UsuarioActual)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, jwt_payload_1.JwtPayload]),
    __metadata("design:returntype", Promise)
], ProductosController.prototype, "listar", null);
__decorate([
    (0, common_1.Post)(),
    (0, permisos_decorator_1.Permisos)('editar_productos'),
    __param(0, (0, common_1.Body)()),
    __param(1, (0, usuario_actual_decorator_1.UsuarioActual)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [crear_producto_dto_1.CrearProductoDto, jwt_payload_1.JwtPayload]),
    __metadata("design:returntype", Promise)
], ProductosController.prototype, "crear", null);
__decorate([
    (0, common_1.Patch)(':id/disponibilidad'),
    (0, permisos_decorator_1.Permisos)('editar_productos'),
    __param(0, (0, common_1.Param)('id')),
    __param(1, (0, common_1.Body)()),
    __param(2, (0, usuario_actual_decorator_1.UsuarioActual)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, Object, jwt_payload_1.JwtPayload]),
    __metadata("design:returntype", Promise)
], ProductosController.prototype, "disponibilidad", null);
__decorate([
    (0, common_1.Post)(':id/toppings'),
    (0, permisos_decorator_1.Permisos)('editar_productos'),
    __param(0, (0, common_1.Param)('id')),
    __param(1, (0, common_1.Body)()),
    __param(2, (0, usuario_actual_decorator_1.UsuarioActual)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, Object, jwt_payload_1.JwtPayload]),
    __metadata("design:returntype", Promise)
], ProductosController.prototype, "vincularTopping", null);
__decorate([
    (0, common_1.Post)(':id/bebidas'),
    (0, permisos_decorator_1.Permisos)('editar_productos'),
    __param(0, (0, common_1.Param)('id')),
    __param(1, (0, common_1.Body)()),
    __param(2, (0, usuario_actual_decorator_1.UsuarioActual)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, Object, jwt_payload_1.JwtPayload]),
    __metadata("design:returntype", Promise)
], ProductosController.prototype, "vincularBebida", null);
__decorate([
    (0, common_1.Get)(':id/items-incluidos'),
    (0, permisos_decorator_1.Permisos)('editar_productos'),
    __param(0, (0, common_1.Param)('id')),
    __param(1, (0, usuario_actual_decorator_1.UsuarioActual)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, jwt_payload_1.JwtPayload]),
    __metadata("design:returntype", Promise)
], ProductosController.prototype, "listarItemsIncluidos", null);
__decorate([
    (0, common_1.Put)(':id/items-incluidos'),
    (0, permisos_decorator_1.Permisos)('editar_productos'),
    __param(0, (0, common_1.Param)('id')),
    __param(1, (0, common_1.Body)()),
    __param(2, (0, usuario_actual_decorator_1.UsuarioActual)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, configurar_items_incluidos_dto_1.ConfigurarItemsIncluidosDto,
        jwt_payload_1.JwtPayload]),
    __metadata("design:returntype", Promise)
], ProductosController.prototype, "configurarItemsIncluidos", null);
__decorate([
    (0, common_1.Patch)(':id'),
    (0, permisos_decorator_1.Permisos)('editar_productos'),
    __param(0, (0, common_1.Param)('id')),
    __param(1, (0, common_1.Body)()),
    __param(2, (0, usuario_actual_decorator_1.UsuarioActual)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, actualizar_producto_dto_1.ActualizarProductoDto,
        jwt_payload_1.JwtPayload]),
    __metadata("design:returntype", Promise)
], ProductosController.prototype, "actualizar", null);
exports.ProductosController = ProductosController = __decorate([
    (0, common_1.Controller)('productos'),
    (0, common_1.UseGuards)(jwt_auth_guard_1.JwtAuthGuard, usuario_activo_guard_1.UsuarioActivoGuard, suscripcion_activa_guard_1.SuscripcionActivaGuard, rol_guard_1.RolGuard),
    __metadata("design:paramtypes", [catalogo_service_1.CatalogoService,
        sucursal_scope_service_1.SucursalScopeService])
], ProductosController);
//# sourceMappingURL=productos.controller.js.map