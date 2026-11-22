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
exports.InventarioController = void 0;
const common_1 = require("@nestjs/common");
const permisos_decorator_1 = require("../../compartido/decoradores/permisos.decorator");
const usuario_actual_decorator_1 = require("../../compartido/decoradores/usuario-actual.decorator");
const jwt_payload_1 = require("../../core/auth/jwt-payload");
const jwt_auth_guard_1 = require("../../core/auth/guards/jwt-auth.guard");
const rol_guard_1 = require("../../core/auth/guards/rol.guard");
const suscripcion_activa_guard_1 = require("../../core/auth/guards/suscripcion-activa.guard");
const plan_features_guard_1 = require("../../core/auth/guards/plan-features.guard");
const requiere_modulo_decorator_1 = require("../../compartido/decoradores/requiere-modulo.decorator");
const usuario_activo_guard_1 = require("../../core/auth/guards/usuario-activo.guard");
const sucursal_scope_service_1 = require("../../core/auth/sucursal-scope.service");
const actualizar_ingrediente_dto_1 = require("./dto/actualizar-ingrediente.dto");
const configurar_receta_producto_dto_1 = require("./dto/configurar-receta-producto.dto");
const crear_ingrediente_dto_1 = require("./dto/crear-ingrediente.dto");
const cerrar_conteo_dto_1 = require("./dto/cerrar-conteo.dto");
const registrar_compra_dto_1 = require("./dto/registrar-compra.dto");
const crear_traslado_dto_1 = require("./dto/crear-traslado.dto");
const inventario_service_1 = require("./inventario.service");
const paginacion_dto_1 = require("../../compartido/dto/paginacion.dto");
let InventarioController = class InventarioController {
    inventario;
    sucursalScope;
    constructor(inventario, sucursalScope) {
        this.inventario = inventario;
        this.sucursalScope = sucursalScope;
    }
    async traslados(usuario, sucursalId) {
        const sid = await this.sucursalScope.resolverLecturaInventario(usuario, sucursalId);
        return this.inventario.listarTraslados(usuario.restaurante_id, sid);
    }
    async crearTraslado(dto, usuario) {
        await this.sucursalScope.resolverEscritura(usuario, dto.sucursal_origen_id);
        return this.inventario.crearTraslado(usuario, dto);
    }
    async recibirTraslado(id, usuario) {
        const sucursalId = await this.sucursalScope.resolverEscritura(usuario, usuario.sucursal_id);
        return this.inventario.recibirTraslado(id, usuario.restaurante_id, sucursalId, usuario.sub);
    }
    async cancelarTraslado(id, usuario) {
        const sucursalId = await this.sucursalScope.resolverEscritura(usuario, usuario.sucursal_id);
        return this.inventario.cancelarTraslado(id, usuario, sucursalId);
    }
    async resumenHermanas(usuario) {
        return this.inventario.resumenInventarioHermanas(usuario);
    }
    async iniciarConteo(sucursalId, usuario) {
        const id = await this.sucursalScope.resolverEscritura(usuario, sucursalId);
        return this.inventario.iniciarConteo(id, usuario.sub);
    }
    async cerrarConteo(conteoId, dto, usuario) {
        const id = await this.sucursalScope.resolverEscritura(usuario, usuario.sucursal_id);
        return this.inventario.cerrarConteo(conteoId, id, usuario.sub, dto);
    }
    async movimientos(sucursalId, usuario, page, limit) {
        const id = await this.sucursalScope.resolverLecturaInventario(usuario, sucursalId);
        const paginar = page != null && page !== '';
        return this.inventario.listarMovimientos(id, {
            paginar,
            page: paginar ? Number(page) : undefined,
            limite: limit != null ? Number(limit) : undefined,
        });
    }
    async costos(sucursalId, usuario) {
        const id = await this.sucursalScope.resolverLecturaInventario(usuario, sucursalId);
        return this.inventario.listarCostosProductos(id);
    }
    async recetaProducto(productoId, tipoEntidad, usuario) {
        const id = await this.sucursalScope.resolverLecturaInventario(usuario, usuario.sucursal_id);
        const tipo = tipoEntidad === 'bebida' || tipoEntidad === 'topping'
            ? tipoEntidad
            : 'producto';
        return this.inventario.recetaDeProducto(productoId, id, tipo);
    }
    async configurarReceta(dto, usuario) {
        const id = await this.sucursalScope.resolverEscritura(usuario, usuario.sucursal_id);
        return this.inventario.configurarRecetaProducto(dto, id);
    }
    async compras(dto, usuario) {
        const id = await this.sucursalScope.resolverEscritura(usuario, dto.sucursal_id);
        return this.inventario.registrarCompra({ ...dto, sucursal_id: id }, usuario.sub);
    }
    async listar(sucursalId, usuario, pag) {
        const id = await this.sucursalScope.resolverLecturaInventario(usuario, sucursalId);
        return this.inventario.listarIngredientes(id, pag);
    }
    async crear(dto, usuario) {
        const id = await this.sucursalScope.resolverEscritura(usuario, dto.sucursal_id);
        return this.inventario.crearIngrediente({ ...dto, sucursal_id: id }, usuario.restaurante_id ?? undefined);
    }
    async actualizar(id, dto, usuario) {
        const sucursalId = await this.sucursalScope.resolverEscritura(usuario, usuario.sucursal_id);
        return this.inventario.actualizarIngrediente(id, sucursalId, usuario.sub, dto);
    }
};
exports.InventarioController = InventarioController;
__decorate([
    (0, common_1.Get)('traslados'),
    (0, permisos_decorator_1.Permisos)('ver_inventario'),
    __param(0, (0, usuario_actual_decorator_1.UsuarioActual)()),
    __param(1, (0, common_1.Query)('sucursal_id')),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [jwt_payload_1.JwtPayload, String]),
    __metadata("design:returntype", Promise)
], InventarioController.prototype, "traslados", null);
__decorate([
    (0, common_1.Post)('traslados'),
    (0, permisos_decorator_1.Permisos)('editar_inventario'),
    __param(0, (0, common_1.Body)()),
    __param(1, (0, usuario_actual_decorator_1.UsuarioActual)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [crear_traslado_dto_1.CrearTrasladoDto,
        jwt_payload_1.JwtPayload]),
    __metadata("design:returntype", Promise)
], InventarioController.prototype, "crearTraslado", null);
__decorate([
    (0, common_1.Post)('traslados/:id/recibir'),
    (0, permisos_decorator_1.Permisos)('editar_inventario'),
    __param(0, (0, common_1.Param)('id', common_1.ParseUUIDPipe)),
    __param(1, (0, usuario_actual_decorator_1.UsuarioActual)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, jwt_payload_1.JwtPayload]),
    __metadata("design:returntype", Promise)
], InventarioController.prototype, "recibirTraslado", null);
__decorate([
    (0, common_1.Post)('traslados/:id/cancelar'),
    (0, permisos_decorator_1.Permisos)('editar_inventario'),
    __param(0, (0, common_1.Param)('id', common_1.ParseUUIDPipe)),
    __param(1, (0, usuario_actual_decorator_1.UsuarioActual)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, jwt_payload_1.JwtPayload]),
    __metadata("design:returntype", Promise)
], InventarioController.prototype, "cancelarTraslado", null);
__decorate([
    (0, common_1.Get)('hermanas/resumen'),
    (0, permisos_decorator_1.Permisos)('ver_inventario'),
    __param(0, (0, usuario_actual_decorator_1.UsuarioActual)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [jwt_payload_1.JwtPayload]),
    __metadata("design:returntype", Promise)
], InventarioController.prototype, "resumenHermanas", null);
__decorate([
    (0, common_1.Post)('conteos/iniciar/:sucursal_id'),
    (0, permisos_decorator_1.Permisos)('editar_inventario'),
    __param(0, (0, common_1.Param)('sucursal_id', common_1.ParseUUIDPipe)),
    __param(1, (0, usuario_actual_decorator_1.UsuarioActual)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, jwt_payload_1.JwtPayload]),
    __metadata("design:returntype", Promise)
], InventarioController.prototype, "iniciarConteo", null);
__decorate([
    (0, common_1.Post)('conteos/:conteo_id/cerrar'),
    (0, permisos_decorator_1.Permisos)('editar_inventario'),
    __param(0, (0, common_1.Param)('conteo_id', common_1.ParseUUIDPipe)),
    __param(1, (0, common_1.Body)()),
    __param(2, (0, usuario_actual_decorator_1.UsuarioActual)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, cerrar_conteo_dto_1.CerrarConteoDto,
        jwt_payload_1.JwtPayload]),
    __metadata("design:returntype", Promise)
], InventarioController.prototype, "cerrarConteo", null);
__decorate([
    (0, common_1.Get)('movimientos/:sucursal_id'),
    (0, permisos_decorator_1.Permisos)('ver_inventario'),
    __param(0, (0, common_1.Param)('sucursal_id')),
    __param(1, (0, usuario_actual_decorator_1.UsuarioActual)()),
    __param(2, (0, common_1.Query)('page')),
    __param(3, (0, common_1.Query)('limit')),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, jwt_payload_1.JwtPayload, String, String]),
    __metadata("design:returntype", Promise)
], InventarioController.prototype, "movimientos", null);
__decorate([
    (0, common_1.Get)('costos/:sucursal_id'),
    (0, permisos_decorator_1.Permisos)('ver_inventario'),
    __param(0, (0, common_1.Param)('sucursal_id')),
    __param(1, (0, usuario_actual_decorator_1.UsuarioActual)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, jwt_payload_1.JwtPayload]),
    __metadata("design:returntype", Promise)
], InventarioController.prototype, "costos", null);
__decorate([
    (0, common_1.Get)('producto-ingredientes/:producto_id'),
    (0, permisos_decorator_1.Permisos)('ver_inventario', 'editar_inventario'),
    __param(0, (0, common_1.Param)('producto_id')),
    __param(1, (0, common_1.Query)('tipo_entidad')),
    __param(2, (0, usuario_actual_decorator_1.UsuarioActual)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, Object, jwt_payload_1.JwtPayload]),
    __metadata("design:returntype", Promise)
], InventarioController.prototype, "recetaProducto", null);
__decorate([
    (0, common_1.Post)('producto-ingredientes'),
    (0, permisos_decorator_1.Permisos)('editar_inventario'),
    __param(0, (0, common_1.Body)()),
    __param(1, (0, usuario_actual_decorator_1.UsuarioActual)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [configurar_receta_producto_dto_1.ConfigurarRecetaProductoDto,
        jwt_payload_1.JwtPayload]),
    __metadata("design:returntype", Promise)
], InventarioController.prototype, "configurarReceta", null);
__decorate([
    (0, common_1.Post)('compras'),
    (0, permisos_decorator_1.Permisos)('editar_inventario'),
    __param(0, (0, common_1.Body)()),
    __param(1, (0, usuario_actual_decorator_1.UsuarioActual)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [registrar_compra_dto_1.RegistrarCompraDto,
        jwt_payload_1.JwtPayload]),
    __metadata("design:returntype", Promise)
], InventarioController.prototype, "compras", null);
__decorate([
    (0, common_1.Get)(':sucursal_id'),
    (0, permisos_decorator_1.Permisos)('ver_inventario'),
    __param(0, (0, common_1.Param)('sucursal_id')),
    __param(1, (0, usuario_actual_decorator_1.UsuarioActual)()),
    __param(2, (0, common_1.Query)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, jwt_payload_1.JwtPayload,
        paginacion_dto_1.PaginacionQueryDto]),
    __metadata("design:returntype", Promise)
], InventarioController.prototype, "listar", null);
__decorate([
    (0, common_1.Post)(),
    (0, permisos_decorator_1.Permisos)('editar_inventario'),
    __param(0, (0, common_1.Body)()),
    __param(1, (0, usuario_actual_decorator_1.UsuarioActual)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [crear_ingrediente_dto_1.CrearIngredienteDto,
        jwt_payload_1.JwtPayload]),
    __metadata("design:returntype", Promise)
], InventarioController.prototype, "crear", null);
__decorate([
    (0, common_1.Patch)(':id'),
    (0, permisos_decorator_1.Permisos)('editar_inventario'),
    __param(0, (0, common_1.Param)('id', common_1.ParseUUIDPipe)),
    __param(1, (0, common_1.Body)()),
    __param(2, (0, usuario_actual_decorator_1.UsuarioActual)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, actualizar_ingrediente_dto_1.ActualizarIngredienteDto,
        jwt_payload_1.JwtPayload]),
    __metadata("design:returntype", Promise)
], InventarioController.prototype, "actualizar", null);
exports.InventarioController = InventarioController = __decorate([
    (0, common_1.Controller)('inventario'),
    (0, common_1.UseGuards)(jwt_auth_guard_1.JwtAuthGuard, usuario_activo_guard_1.UsuarioActivoGuard, suscripcion_activa_guard_1.SuscripcionActivaGuard, plan_features_guard_1.PlanFeaturesGuard, rol_guard_1.RolGuard),
    (0, requiere_modulo_decorator_1.RequiereModulo)('inventario'),
    __metadata("design:paramtypes", [inventario_service_1.InventarioService,
        sucursal_scope_service_1.SucursalScopeService])
], InventarioController);
//# sourceMappingURL=inventario.controller.js.map