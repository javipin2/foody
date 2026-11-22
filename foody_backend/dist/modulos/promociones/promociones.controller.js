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
exports.PromocionesController = void 0;
const common_1 = require("@nestjs/common");
const permisos_decorator_1 = require("../../compartido/decoradores/permisos.decorator");
const usuario_actual_decorator_1 = require("../../compartido/decoradores/usuario-actual.decorator");
const rate_limit_guard_1 = require("../../compartido/guards/rate-limit.guard");
const jwt_payload_1 = require("../../core/auth/jwt-payload");
const jwt_auth_guard_1 = require("../../core/auth/guards/jwt-auth.guard");
const rol_guard_1 = require("../../core/auth/guards/rol.guard");
const suscripcion_activa_guard_1 = require("../../core/auth/guards/suscripcion-activa.guard");
const usuario_activo_guard_1 = require("../../core/auth/guards/usuario-activo.guard");
const sucursal_scope_service_1 = require("../../core/auth/sucursal-scope.service");
const promocion_dto_1 = require("./dto/promocion.dto");
const promociones_service_1 = require("./promociones.service");
let PromocionesController = class PromocionesController {
    promociones;
    sucursalScope;
    constructor(promociones, sucursalScope) {
        this.promociones = promociones;
        this.sucursalScope = sucursalScope;
    }
    listarActivas(sucursalId) {
        return this.promociones.listarActivas(sucursalId);
    }
    storiesCiudad(slug) {
        return this.promociones.listarStoriesPorCiudad(slug);
    }
    validarCodigo(dto) {
        return this.promociones.previewCodigo(dto.sucursal_id, dto.codigo, dto.subtotal);
    }
    registrarVista(id, dto) {
        return this.promociones.registrarVista(id, dto.device_id);
    }
    async crear(usuario, dto) {
        await this.sucursalScope.validarEscritura(usuario, dto.sucursal_id);
        return this.promociones.crear(dto);
    }
    limpiarExpiradas() {
        return this.promociones.limpiarExpiradas(7);
    }
    async listarAdmin(usuario, sucursalId) {
        const id = await this.sucursalScope.resolverLecturaOperativa(usuario, sucursalId);
        return this.promociones.listarAdmin(id);
    }
    actualizar(id, dto, usuario) {
        return this.promociones.actualizar(id, usuario.sucursal_id, dto);
    }
    eliminar(id, usuario) {
        return this.promociones.eliminar(id, usuario.sucursal_id);
    }
};
exports.PromocionesController = PromocionesController;
__decorate([
    (0, common_1.Get)(),
    (0, rate_limit_guard_1.RateLimitPublico)(120, 60_000),
    __param(0, (0, common_1.Query)('sucursal_id')),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String]),
    __metadata("design:returntype", void 0)
], PromocionesController.prototype, "listarActivas", null);
__decorate([
    (0, common_1.Get)('ciudad/:slug/stories'),
    (0, rate_limit_guard_1.RateLimitPublico)(120, 60_000),
    __param(0, (0, common_1.Param)('slug')),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String]),
    __metadata("design:returntype", void 0)
], PromocionesController.prototype, "storiesCiudad", null);
__decorate([
    (0, common_1.Get)('validar-codigo'),
    (0, rate_limit_guard_1.RateLimitPublico)(60, 60_000),
    __param(0, (0, common_1.Query)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [promocion_dto_1.ValidarCodigoPromocionDto]),
    __metadata("design:returntype", void 0)
], PromocionesController.prototype, "validarCodigo", null);
__decorate([
    (0, common_1.Post)(':id/vista'),
    (0, rate_limit_guard_1.RateLimitPublico)(60, 60_000),
    __param(0, (0, common_1.Param)('id', common_1.ParseUUIDPipe)),
    __param(1, (0, common_1.Body)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, promocion_dto_1.RegistrarVistaPromocionDto]),
    __metadata("design:returntype", void 0)
], PromocionesController.prototype, "registrarVista", null);
__decorate([
    (0, common_1.Post)(),
    (0, common_1.UseGuards)(jwt_auth_guard_1.JwtAuthGuard, usuario_activo_guard_1.UsuarioActivoGuard, suscripcion_activa_guard_1.SuscripcionActivaGuard, rol_guard_1.RolGuard),
    (0, permisos_decorator_1.Permisos)('editar_productos'),
    __param(0, (0, usuario_actual_decorator_1.UsuarioActual)()),
    __param(1, (0, common_1.Body)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [jwt_payload_1.JwtPayload,
        promocion_dto_1.CrearPromocionDto]),
    __metadata("design:returntype", Promise)
], PromocionesController.prototype, "crear", null);
__decorate([
    (0, common_1.Post)('admin/limpiar-expiradas'),
    (0, common_1.UseGuards)(jwt_auth_guard_1.JwtAuthGuard, usuario_activo_guard_1.UsuarioActivoGuard, suscripcion_activa_guard_1.SuscripcionActivaGuard, rol_guard_1.RolGuard),
    (0, permisos_decorator_1.Permisos)('editar_productos'),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", []),
    __metadata("design:returntype", void 0)
], PromocionesController.prototype, "limpiarExpiradas", null);
__decorate([
    (0, common_1.Get)('admin/:sucursal_id'),
    (0, common_1.UseGuards)(jwt_auth_guard_1.JwtAuthGuard, usuario_activo_guard_1.UsuarioActivoGuard, suscripcion_activa_guard_1.SuscripcionActivaGuard, rol_guard_1.RolGuard),
    (0, permisos_decorator_1.Permisos)('editar_productos'),
    __param(0, (0, usuario_actual_decorator_1.UsuarioActual)()),
    __param(1, (0, common_1.Param)('sucursal_id')),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [jwt_payload_1.JwtPayload, String]),
    __metadata("design:returntype", Promise)
], PromocionesController.prototype, "listarAdmin", null);
__decorate([
    (0, common_1.Patch)(':id'),
    (0, common_1.UseGuards)(jwt_auth_guard_1.JwtAuthGuard, usuario_activo_guard_1.UsuarioActivoGuard, suscripcion_activa_guard_1.SuscripcionActivaGuard, rol_guard_1.RolGuard),
    (0, permisos_decorator_1.Permisos)('editar_productos'),
    __param(0, (0, common_1.Param)('id', common_1.ParseUUIDPipe)),
    __param(1, (0, common_1.Body)()),
    __param(2, (0, usuario_actual_decorator_1.UsuarioActual)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, promocion_dto_1.ActualizarPromocionDto,
        jwt_payload_1.JwtPayload]),
    __metadata("design:returntype", void 0)
], PromocionesController.prototype, "actualizar", null);
__decorate([
    (0, common_1.Delete)(':id'),
    (0, common_1.UseGuards)(jwt_auth_guard_1.JwtAuthGuard, usuario_activo_guard_1.UsuarioActivoGuard, suscripcion_activa_guard_1.SuscripcionActivaGuard, rol_guard_1.RolGuard),
    (0, permisos_decorator_1.Permisos)('editar_productos'),
    __param(0, (0, common_1.Param)('id', common_1.ParseUUIDPipe)),
    __param(1, (0, usuario_actual_decorator_1.UsuarioActual)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, jwt_payload_1.JwtPayload]),
    __metadata("design:returntype", void 0)
], PromocionesController.prototype, "eliminar", null);
exports.PromocionesController = PromocionesController = __decorate([
    (0, common_1.Controller)('promociones'),
    __metadata("design:paramtypes", [promociones_service_1.PromocionesService,
        sucursal_scope_service_1.SucursalScopeService])
], PromocionesController);
//# sourceMappingURL=promociones.controller.js.map