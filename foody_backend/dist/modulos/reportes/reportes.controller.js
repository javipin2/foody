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
exports.ReportesController = void 0;
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
const filtro_reporte_dto_1 = require("./dto/filtro-reporte.dto");
const reportes_service_1 = require("./reportes.service");
let ReportesController = class ReportesController {
    reportesService;
    sucursalScope;
    constructor(reportesService, sucursalScope) {
        this.reportesService = reportesService;
        this.sucursalScope = sucursalScope;
    }
    async financiero(usuario, query) {
        const id = await this.sucursalScope.resolverLecturaOperativa(usuario, query.sucursal_id);
        const rango = this.reportesService.resolverRango(query.desde, query.hasta);
        return this.reportesService.financiero(id, rango);
    }
    async productos(usuario, query) {
        const id = await this.sucursalScope.resolverLecturaOperativa(usuario, query.sucursal_id);
        const rango = this.reportesService.resolverRango(query.desde, query.hasta);
        return this.reportesService.productos(id, rango);
    }
    async pedidos(usuario, query) {
        const id = await this.sucursalScope.resolverLecturaOperativa(usuario, query.sucursal_id);
        const rango = this.reportesService.resolverRango(query.desde, query.hasta);
        return this.reportesService.pedidos(id, rango);
    }
};
exports.ReportesController = ReportesController;
__decorate([
    (0, common_1.Get)('financiero'),
    (0, permisos_decorator_1.Permisos)('ver_reportes'),
    __param(0, (0, usuario_actual_decorator_1.UsuarioActual)()),
    __param(1, (0, common_1.Query)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [jwt_payload_1.JwtPayload,
        filtro_reporte_dto_1.FiltroReporteDto]),
    __metadata("design:returntype", Promise)
], ReportesController.prototype, "financiero", null);
__decorate([
    (0, common_1.Get)('productos'),
    (0, permisos_decorator_1.Permisos)('ver_reportes'),
    __param(0, (0, usuario_actual_decorator_1.UsuarioActual)()),
    __param(1, (0, common_1.Query)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [jwt_payload_1.JwtPayload,
        filtro_reporte_dto_1.FiltroReporteDto]),
    __metadata("design:returntype", Promise)
], ReportesController.prototype, "productos", null);
__decorate([
    (0, common_1.Get)('pedidos'),
    (0, permisos_decorator_1.Permisos)('ver_reportes'),
    __param(0, (0, usuario_actual_decorator_1.UsuarioActual)()),
    __param(1, (0, common_1.Query)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [jwt_payload_1.JwtPayload,
        filtro_reporte_dto_1.FiltroReporteDto]),
    __metadata("design:returntype", Promise)
], ReportesController.prototype, "pedidos", null);
exports.ReportesController = ReportesController = __decorate([
    (0, common_1.Controller)('reportes'),
    (0, common_1.UseGuards)(jwt_auth_guard_1.JwtAuthGuard, usuario_activo_guard_1.UsuarioActivoGuard, suscripcion_activa_guard_1.SuscripcionActivaGuard, plan_features_guard_1.PlanFeaturesGuard, rol_guard_1.RolGuard),
    (0, requiere_modulo_decorator_1.RequiereModulo)('reportes'),
    __metadata("design:paramtypes", [reportes_service_1.ReportesService,
        sucursal_scope_service_1.SucursalScopeService])
], ReportesController);
//# sourceMappingURL=reportes.controller.js.map