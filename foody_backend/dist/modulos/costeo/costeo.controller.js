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
exports.CosteoController = void 0;
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
const costeo_service_1 = require("./costeo.service");
const actualizar_subreceta_dto_1 = require("./dto/actualizar-subreceta.dto");
const crear_subreceta_dto_1 = require("./dto/crear-subreceta.dto");
const registrar_produccion_dto_1 = require("./dto/registrar-produccion.dto");
const filtro_popularidad_dto_1 = require("./dto/filtro-popularidad.dto");
const impacto_stock_query_dto_1 = require("./dto/impacto-stock-query.dto");
let CosteoController = class CosteoController {
    costeo;
    sucursalScope;
    constructor(costeo, sucursalScope) {
        this.costeo = costeo;
        this.sucursalScope = sucursalScope;
    }
    async resumen(usuario, sucursalId) {
        const id = await this.sucursalScope.resolverLecturaInventario(usuario, sucursalId);
        return this.costeo.resumenSucursal(id);
    }
    async subrecetaDetalle(usuario, recetaId, sucursalId) {
        const id = await this.sucursalScope.resolverLecturaInventario(usuario, sucursalId);
        return this.costeo.obtenerSubrecetaDetalle(recetaId, id);
    }
    async subrecetas(usuario, sucursalId) {
        const id = await this.sucursalScope.resolverLecturaInventario(usuario, sucursalId);
        return this.costeo.listarSubrecetas(id);
    }
    async combos(usuario, sucursalId) {
        const id = await this.sucursalScope.resolverLecturaInventario(usuario, sucursalId);
        return this.costeo.listarCombos(id);
    }
    async recalcular(usuario, sucursalId) {
        const id = await this.sucursalScope.resolverEscritura(usuario, sucursalId);
        return this.costeo.recalcularSucursal(id);
    }
    async impactoStock(usuario, productoId, query) {
        const id = await this.sucursalScope.resolverLecturaInventario(usuario, query.sucursal_id);
        const cant = query.cantidad ?? 1;
        const tipo = query.tipo_entidad ?? 'producto';
        return this.costeo.impactoStockProducto(productoId, id, cant, tipo);
    }
    async recalcularProducto(usuario, productoId, sucursalId, tipoEntidad) {
        const id = await this.sucursalScope.resolverEscritura(usuario, sucursalId);
        if (tipoEntidad === 'bebida' || tipoEntidad === 'topping') {
            return this.costeo.recalcularExtraPorId(tipoEntidad, productoId, id);
        }
        return this.costeo.recalcularProductoPorId(productoId, id);
    }
    async recalcularCombo(usuario, comboId, sucursalId) {
        const id = await this.sucursalScope.resolverEscritura(usuario, sucursalId);
        return this.costeo.recalcularComboPorId(comboId, id);
    }
    async crearSubreceta(usuario, dto) {
        await this.sucursalScope.validarEscritura(usuario, dto.sucursal_id);
        return this.costeo.crearSubreceta(dto);
    }
    async actualizarSubreceta(usuario, recetaId, dto) {
        await this.sucursalScope.validarEscritura(usuario, dto.sucursal_id);
        return this.costeo.actualizarSubreceta(recetaId, dto);
    }
    async recalcularSubreceta(usuario, recetaId, sucursalId) {
        const id = await this.sucursalScope.resolverEscritura(usuario, sucursalId);
        return this.costeo.recalcularSubrecetaPorId(recetaId, id);
    }
    async simuladorPopularidad(usuario, sucursalId, query) {
        const id = await this.sucursalScope.resolverLecturaInventario(usuario, sucursalId);
        return this.costeo.simuladorPopularidad(id, query.preset, query.desde, query.hasta);
    }
    async listarProducciones(usuario, sucursalId, recetaId) {
        const id = await this.sucursalScope.resolverLecturaInventario(usuario, sucursalId);
        return this.costeo.listarProducciones(id, recetaId);
    }
    async registrarProduccion(usuario, dto) {
        await this.sucursalScope.validarEscritura(usuario, dto.sucursal_id);
        return this.costeo.registrarProduccion(dto, usuario.sub);
    }
};
exports.CosteoController = CosteoController;
__decorate([
    (0, common_1.Get)('resumen/:sucursal_id'),
    (0, permisos_decorator_1.Permisos)('ver_inventario'),
    __param(0, (0, usuario_actual_decorator_1.UsuarioActual)()),
    __param(1, (0, common_1.Param)('sucursal_id')),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [jwt_payload_1.JwtPayload, String]),
    __metadata("design:returntype", Promise)
], CosteoController.prototype, "resumen", null);
__decorate([
    (0, common_1.Get)('subrecetas/detalle/:id'),
    (0, permisos_decorator_1.Permisos)('ver_inventario'),
    __param(0, (0, usuario_actual_decorator_1.UsuarioActual)()),
    __param(1, (0, common_1.Param)('id', common_1.ParseUUIDPipe)),
    __param(2, (0, common_1.Query)('sucursal_id')),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [jwt_payload_1.JwtPayload, String, String]),
    __metadata("design:returntype", Promise)
], CosteoController.prototype, "subrecetaDetalle", null);
__decorate([
    (0, common_1.Get)('subrecetas/:sucursal_id'),
    (0, permisos_decorator_1.Permisos)('ver_inventario'),
    __param(0, (0, usuario_actual_decorator_1.UsuarioActual)()),
    __param(1, (0, common_1.Param)('sucursal_id')),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [jwt_payload_1.JwtPayload, String]),
    __metadata("design:returntype", Promise)
], CosteoController.prototype, "subrecetas", null);
__decorate([
    (0, common_1.Get)('combos/:sucursal_id'),
    (0, permisos_decorator_1.Permisos)('ver_inventario'),
    __param(0, (0, usuario_actual_decorator_1.UsuarioActual)()),
    __param(1, (0, common_1.Param)('sucursal_id')),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [jwt_payload_1.JwtPayload, String]),
    __metadata("design:returntype", Promise)
], CosteoController.prototype, "combos", null);
__decorate([
    (0, common_1.Post)('recalcular/:sucursal_id'),
    (0, permisos_decorator_1.Permisos)('editar_inventario'),
    __param(0, (0, usuario_actual_decorator_1.UsuarioActual)()),
    __param(1, (0, common_1.Param)('sucursal_id')),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [jwt_payload_1.JwtPayload, String]),
    __metadata("design:returntype", Promise)
], CosteoController.prototype, "recalcular", null);
__decorate([
    (0, common_1.Get)('productos/:id/impacto-stock'),
    (0, permisos_decorator_1.Permisos)('ver_inventario'),
    __param(0, (0, usuario_actual_decorator_1.UsuarioActual)()),
    __param(1, (0, common_1.Param)('id', common_1.ParseUUIDPipe)),
    __param(2, (0, common_1.Query)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [jwt_payload_1.JwtPayload, String, impacto_stock_query_dto_1.ImpactoStockQueryDto]),
    __metadata("design:returntype", Promise)
], CosteoController.prototype, "impactoStock", null);
__decorate([
    (0, common_1.Post)('productos/:id/recalcular'),
    (0, permisos_decorator_1.Permisos)('editar_inventario'),
    __param(0, (0, usuario_actual_decorator_1.UsuarioActual)()),
    __param(1, (0, common_1.Param)('id', common_1.ParseUUIDPipe)),
    __param(2, (0, common_1.Query)('sucursal_id')),
    __param(3, (0, common_1.Query)('tipo_entidad')),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [jwt_payload_1.JwtPayload, String, String, String]),
    __metadata("design:returntype", Promise)
], CosteoController.prototype, "recalcularProducto", null);
__decorate([
    (0, common_1.Post)('combos/:id/recalcular'),
    (0, permisos_decorator_1.Permisos)('editar_inventario'),
    __param(0, (0, usuario_actual_decorator_1.UsuarioActual)()),
    __param(1, (0, common_1.Param)('id', common_1.ParseUUIDPipe)),
    __param(2, (0, common_1.Query)('sucursal_id')),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [jwt_payload_1.JwtPayload, String, String]),
    __metadata("design:returntype", Promise)
], CosteoController.prototype, "recalcularCombo", null);
__decorate([
    (0, common_1.Post)('subrecetas'),
    (0, permisos_decorator_1.Permisos)('editar_inventario'),
    __param(0, (0, usuario_actual_decorator_1.UsuarioActual)()),
    __param(1, (0, common_1.Body)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [jwt_payload_1.JwtPayload,
        crear_subreceta_dto_1.CrearSubrecetaDto]),
    __metadata("design:returntype", Promise)
], CosteoController.prototype, "crearSubreceta", null);
__decorate([
    (0, common_1.Patch)('subrecetas/:id'),
    (0, permisos_decorator_1.Permisos)('editar_inventario'),
    __param(0, (0, usuario_actual_decorator_1.UsuarioActual)()),
    __param(1, (0, common_1.Param)('id', common_1.ParseUUIDPipe)),
    __param(2, (0, common_1.Body)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [jwt_payload_1.JwtPayload, String, actualizar_subreceta_dto_1.ActualizarSubrecetaDto]),
    __metadata("design:returntype", Promise)
], CosteoController.prototype, "actualizarSubreceta", null);
__decorate([
    (0, common_1.Post)('subrecetas/:id/recalcular'),
    (0, permisos_decorator_1.Permisos)('editar_inventario'),
    __param(0, (0, usuario_actual_decorator_1.UsuarioActual)()),
    __param(1, (0, common_1.Param)('id', common_1.ParseUUIDPipe)),
    __param(2, (0, common_1.Query)('sucursal_id')),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [jwt_payload_1.JwtPayload, String, String]),
    __metadata("design:returntype", Promise)
], CosteoController.prototype, "recalcularSubreceta", null);
__decorate([
    (0, common_1.Get)('popularidad/:sucursal_id'),
    (0, permisos_decorator_1.Permisos)('ver_inventario'),
    __param(0, (0, usuario_actual_decorator_1.UsuarioActual)()),
    __param(1, (0, common_1.Param)('sucursal_id')),
    __param(2, (0, common_1.Query)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [jwt_payload_1.JwtPayload, String, filtro_popularidad_dto_1.FiltroPopularidadQueryDto]),
    __metadata("design:returntype", Promise)
], CosteoController.prototype, "simuladorPopularidad", null);
__decorate([
    (0, common_1.Get)('producciones/:sucursal_id'),
    (0, permisos_decorator_1.Permisos)('ver_inventario'),
    __param(0, (0, usuario_actual_decorator_1.UsuarioActual)()),
    __param(1, (0, common_1.Param)('sucursal_id')),
    __param(2, (0, common_1.Query)('receta_id')),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [jwt_payload_1.JwtPayload, String, String]),
    __metadata("design:returntype", Promise)
], CosteoController.prototype, "listarProducciones", null);
__decorate([
    (0, common_1.Post)('producciones'),
    (0, permisos_decorator_1.Permisos)('editar_inventario'),
    __param(0, (0, usuario_actual_decorator_1.UsuarioActual)()),
    __param(1, (0, common_1.Body)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [jwt_payload_1.JwtPayload,
        registrar_produccion_dto_1.RegistrarProduccionDto]),
    __metadata("design:returntype", Promise)
], CosteoController.prototype, "registrarProduccion", null);
exports.CosteoController = CosteoController = __decorate([
    (0, common_1.Controller)('costeo'),
    (0, common_1.UseGuards)(jwt_auth_guard_1.JwtAuthGuard, usuario_activo_guard_1.UsuarioActivoGuard, suscripcion_activa_guard_1.SuscripcionActivaGuard, plan_features_guard_1.PlanFeaturesGuard, rol_guard_1.RolGuard),
    (0, requiere_modulo_decorator_1.RequiereModulo)('costeo'),
    __metadata("design:paramtypes", [costeo_service_1.CosteoService,
        sucursal_scope_service_1.SucursalScopeService])
], CosteoController);
//# sourceMappingURL=costeo.controller.js.map