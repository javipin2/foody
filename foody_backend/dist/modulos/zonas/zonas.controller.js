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
exports.ZonasController = void 0;
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
const zona_dto_1 = require("./dto/zona.dto");
const zonas_service_1 = require("./zonas.service");
let ZonasController = class ZonasController {
    zonas;
    sucursalScope;
    constructor(zonas, sucursalScope) {
        this.zonas = zonas;
        this.sucursalScope = sucursalScope;
    }
    cotizar(dto) {
        return this.zonas.cotizarDomicilio(dto.sucursal_id, dto.lat, dto.lng);
    }
    async configuracionMapa(sucursalId, usuario) {
        await this.sucursalScope.validarLecturaOperativa(usuario, sucursalId);
        return this.zonas.configuracionMapa(sucursalId);
    }
    async ubicacionSucursal(sucursalId, dto, usuario) {
        const sid = await this.sucursalScope.resolverEscritura(usuario, sucursalId);
        return this.zonas.actualizarUbicacionSucursal(sid, dto.lat, dto.lng);
    }
    async listar(sucursalId, usuario) {
        await this.sucursalScope.validarLecturaOperativa(usuario, sucursalId);
        return this.zonas.listar(sucursalId);
    }
    async crear(dto, usuario) {
        await this.sucursalScope.validarEscritura(usuario, dto.sucursal_id);
        return this.zonas.crear(dto);
    }
    async actualizar(id, dto, usuario, sucursalIdQuery) {
        const sid = sucursalIdQuery ?? (await this.zonas.obtenerSucursalIdDeZona(id));
        const sucursalId = await this.sucursalScope.resolverEscritura(usuario, sid);
        return this.zonas.actualizar(id, sucursalId, dto);
    }
    async desactivar(id, usuario, sucursalIdQuery) {
        const sid = sucursalIdQuery ?? (await this.zonas.obtenerSucursalIdDeZona(id));
        const sucursalId = await this.sucursalScope.resolverEscritura(usuario, sid);
        return this.zonas.desactivar(id, sucursalId);
    }
};
exports.ZonasController = ZonasController;
__decorate([
    (0, common_1.Get)('cotizar-domicilio'),
    __param(0, (0, common_1.Query)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [zona_dto_1.CotizarDomicilioDto]),
    __metadata("design:returntype", void 0)
], ZonasController.prototype, "cotizar", null);
__decorate([
    (0, common_1.Get)('sucursal/:sucursal_id/configuracion-mapa'),
    (0, common_1.UseGuards)(jwt_auth_guard_1.JwtAuthGuard, usuario_activo_guard_1.UsuarioActivoGuard, suscripcion_activa_guard_1.SuscripcionActivaGuard, plan_features_guard_1.PlanFeaturesGuard, rol_guard_1.RolGuard),
    (0, requiere_modulo_decorator_1.RequiereModulo)('zonas_domicilio'),
    (0, permisos_decorator_1.Permisos)('gestionar_sucursales', 'editar_productos'),
    __param(0, (0, common_1.Param)('sucursal_id')),
    __param(1, (0, usuario_actual_decorator_1.UsuarioActual)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, jwt_payload_1.JwtPayload]),
    __metadata("design:returntype", Promise)
], ZonasController.prototype, "configuracionMapa", null);
__decorate([
    (0, common_1.Patch)('sucursal/:sucursal_id/ubicacion'),
    (0, common_1.UseGuards)(jwt_auth_guard_1.JwtAuthGuard, usuario_activo_guard_1.UsuarioActivoGuard, suscripcion_activa_guard_1.SuscripcionActivaGuard, plan_features_guard_1.PlanFeaturesGuard, rol_guard_1.RolGuard),
    (0, requiere_modulo_decorator_1.RequiereModulo)('zonas_domicilio'),
    (0, permisos_decorator_1.Permisos)('gestionar_sucursales'),
    __param(0, (0, common_1.Param)('sucursal_id')),
    __param(1, (0, common_1.Body)()),
    __param(2, (0, usuario_actual_decorator_1.UsuarioActual)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, zona_dto_1.UbicacionSucursalDto,
        jwt_payload_1.JwtPayload]),
    __metadata("design:returntype", Promise)
], ZonasController.prototype, "ubicacionSucursal", null);
__decorate([
    (0, common_1.Get)(':sucursal_id'),
    (0, common_1.UseGuards)(jwt_auth_guard_1.JwtAuthGuard, usuario_activo_guard_1.UsuarioActivoGuard, suscripcion_activa_guard_1.SuscripcionActivaGuard, plan_features_guard_1.PlanFeaturesGuard, rol_guard_1.RolGuard),
    (0, requiere_modulo_decorator_1.RequiereModulo)('zonas_domicilio'),
    (0, permisos_decorator_1.Permisos)('gestionar_sucursales', 'editar_productos'),
    __param(0, (0, common_1.Param)('sucursal_id')),
    __param(1, (0, usuario_actual_decorator_1.UsuarioActual)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, jwt_payload_1.JwtPayload]),
    __metadata("design:returntype", Promise)
], ZonasController.prototype, "listar", null);
__decorate([
    (0, common_1.Post)(),
    (0, common_1.UseGuards)(jwt_auth_guard_1.JwtAuthGuard, usuario_activo_guard_1.UsuarioActivoGuard, suscripcion_activa_guard_1.SuscripcionActivaGuard, plan_features_guard_1.PlanFeaturesGuard, rol_guard_1.RolGuard),
    (0, requiere_modulo_decorator_1.RequiereModulo)('zonas_domicilio'),
    (0, permisos_decorator_1.Permisos)('gestionar_sucursales'),
    __param(0, (0, common_1.Body)()),
    __param(1, (0, usuario_actual_decorator_1.UsuarioActual)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [zona_dto_1.CrearZonaDto, jwt_payload_1.JwtPayload]),
    __metadata("design:returntype", Promise)
], ZonasController.prototype, "crear", null);
__decorate([
    (0, common_1.Patch)(':id'),
    (0, common_1.UseGuards)(jwt_auth_guard_1.JwtAuthGuard, usuario_activo_guard_1.UsuarioActivoGuard, suscripcion_activa_guard_1.SuscripcionActivaGuard, plan_features_guard_1.PlanFeaturesGuard, rol_guard_1.RolGuard),
    (0, requiere_modulo_decorator_1.RequiereModulo)('zonas_domicilio'),
    (0, permisos_decorator_1.Permisos)('gestionar_sucursales'),
    __param(0, (0, common_1.Param)('id', common_1.ParseUUIDPipe)),
    __param(1, (0, common_1.Body)()),
    __param(2, (0, usuario_actual_decorator_1.UsuarioActual)()),
    __param(3, (0, common_1.Query)('sucursal_id')),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, zona_dto_1.ActualizarZonaDto,
        jwt_payload_1.JwtPayload, String]),
    __metadata("design:returntype", Promise)
], ZonasController.prototype, "actualizar", null);
__decorate([
    (0, common_1.Delete)(':id'),
    (0, common_1.UseGuards)(jwt_auth_guard_1.JwtAuthGuard, usuario_activo_guard_1.UsuarioActivoGuard, suscripcion_activa_guard_1.SuscripcionActivaGuard, plan_features_guard_1.PlanFeaturesGuard, rol_guard_1.RolGuard),
    (0, requiere_modulo_decorator_1.RequiereModulo)('zonas_domicilio'),
    (0, permisos_decorator_1.Permisos)('gestionar_sucursales'),
    __param(0, (0, common_1.Param)('id', common_1.ParseUUIDPipe)),
    __param(1, (0, usuario_actual_decorator_1.UsuarioActual)()),
    __param(2, (0, common_1.Query)('sucursal_id')),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, jwt_payload_1.JwtPayload, String]),
    __metadata("design:returntype", Promise)
], ZonasController.prototype, "desactivar", null);
exports.ZonasController = ZonasController = __decorate([
    (0, common_1.Controller)('zonas'),
    __metadata("design:paramtypes", [zonas_service_1.ZonasService,
        sucursal_scope_service_1.SucursalScopeService])
], ZonasController);
//# sourceMappingURL=zonas.controller.js.map