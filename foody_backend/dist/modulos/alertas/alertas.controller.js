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
exports.AlertasController = void 0;
const common_1 = require("@nestjs/common");
const permisos_decorator_1 = require("../../compartido/decoradores/permisos.decorator");
const usuario_actual_decorator_1 = require("../../compartido/decoradores/usuario-actual.decorator");
const jwt_payload_1 = require("../../core/auth/jwt-payload");
const jwt_auth_guard_1 = require("../../core/auth/guards/jwt-auth.guard");
const rol_guard_1 = require("../../core/auth/guards/rol.guard");
const suscripcion_activa_guard_1 = require("../../core/auth/guards/suscripcion-activa.guard");
const usuario_activo_guard_1 = require("../../core/auth/guards/usuario-activo.guard");
const sucursal_scope_service_1 = require("../../core/auth/sucursal-scope.service");
const alertas_riesgo_service_1 = require("./alertas-riesgo.service");
const alertas_service_1 = require("./alertas.service");
let AlertasController = class AlertasController {
    alertasService;
    alertasRiesgo;
    sucursalScope;
    constructor(alertasService, alertasRiesgo, sucursalScope) {
        this.alertasService = alertasService;
        this.alertasRiesgo = alertasRiesgo;
        this.sucursalScope = sucursalScope;
    }
    async evaluar(sucursalId, usuario) {
        const sid = await this.sucursalScope.resolverEscritura(usuario, sucursalId);
        return this.alertasRiesgo.evaluarAlertasProgramadas(sid);
    }
    async listar(sucursalId, soloPendientes, usuario) {
        await this.sucursalScope.validarLecturaOperativa(usuario, sucursalId);
        return this.alertasService.listar(sucursalId, soloPendientes !== 'false');
    }
    async revisar(alertaId, usuario, sucursalId) {
        const sid = await this.sucursalScope.resolverEscritura(usuario, sucursalId);
        return this.alertasService.revisar(alertaId, sid, usuario.sub);
    }
};
exports.AlertasController = AlertasController;
__decorate([
    (0, common_1.Post)('evaluar/:sucursal_id'),
    (0, permisos_decorator_1.Permisos)('ver_alertas'),
    __param(0, (0, common_1.Param)('sucursal_id')),
    __param(1, (0, usuario_actual_decorator_1.UsuarioActual)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, jwt_payload_1.JwtPayload]),
    __metadata("design:returntype", Promise)
], AlertasController.prototype, "evaluar", null);
__decorate([
    (0, common_1.Get)(':sucursal_id'),
    (0, permisos_decorator_1.Permisos)('ver_alertas'),
    __param(0, (0, common_1.Param)('sucursal_id')),
    __param(1, (0, common_1.Query)('solo_pendientes')),
    __param(2, (0, usuario_actual_decorator_1.UsuarioActual)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, Object, jwt_payload_1.JwtPayload]),
    __metadata("design:returntype", Promise)
], AlertasController.prototype, "listar", null);
__decorate([
    (0, common_1.Patch)(':id/revisar'),
    (0, permisos_decorator_1.Permisos)('ver_alertas'),
    __param(0, (0, common_1.Param)('id', common_1.ParseUUIDPipe)),
    __param(1, (0, usuario_actual_decorator_1.UsuarioActual)()),
    __param(2, (0, common_1.Query)('sucursal_id')),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, jwt_payload_1.JwtPayload, String]),
    __metadata("design:returntype", Promise)
], AlertasController.prototype, "revisar", null);
exports.AlertasController = AlertasController = __decorate([
    (0, common_1.Controller)('alertas'),
    (0, common_1.UseGuards)(jwt_auth_guard_1.JwtAuthGuard, usuario_activo_guard_1.UsuarioActivoGuard, suscripcion_activa_guard_1.SuscripcionActivaGuard, rol_guard_1.RolGuard),
    __metadata("design:paramtypes", [alertas_service_1.AlertasService,
        alertas_riesgo_service_1.AlertasRiesgoService,
        sucursal_scope_service_1.SucursalScopeService])
], AlertasController);
//# sourceMappingURL=alertas.controller.js.map