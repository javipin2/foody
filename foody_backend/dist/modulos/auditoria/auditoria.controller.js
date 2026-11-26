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
exports.AuditoriaController = void 0;
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
const ventas_metricas_sql_1 = require("../../compartido/sql/ventas-metricas.sql");
const auditoria_service_1 = require("./auditoria.service");
const timeline_auditoria_dto_1 = require("./dto/timeline-auditoria.dto");
let AuditoriaController = class AuditoriaController {
    auditoria;
    sucursalScope;
    constructor(auditoria, sucursalScope) {
        this.auditoria = auditoria;
        this.sucursalScope = sucursalScope;
    }
    async timeline(usuario, query) {
        const hoy = new Intl.DateTimeFormat('en-CA', {
            timeZone: ventas_metricas_sql_1.SQL_TZ_NEGOCIO,
            year: 'numeric',
            month: '2-digit',
            day: '2-digit',
        }).format(new Date());
        const id = await this.sucursalScope.resolverLecturaOperativa(usuario, query.sucursal_id);
        return this.auditoria.timelineTurno({
            sucursal_id: id,
            desde: query.desde ?? hoy,
            hasta: query.hasta ?? hoy,
        });
    }
};
exports.AuditoriaController = AuditoriaController;
__decorate([
    (0, common_1.Get)('timeline'),
    (0, permisos_decorator_1.Permisos)('ver_reportes'),
    __param(0, (0, usuario_actual_decorator_1.UsuarioActual)()),
    __param(1, (0, common_1.Query)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [jwt_payload_1.JwtPayload,
        timeline_auditoria_dto_1.TimelineAuditoriaDto]),
    __metadata("design:returntype", Promise)
], AuditoriaController.prototype, "timeline", null);
exports.AuditoriaController = AuditoriaController = __decorate([
    (0, common_1.Controller)('auditoria'),
    (0, common_1.UseGuards)(jwt_auth_guard_1.JwtAuthGuard, usuario_activo_guard_1.UsuarioActivoGuard, suscripcion_activa_guard_1.SuscripcionActivaGuard, plan_features_guard_1.PlanFeaturesGuard, rol_guard_1.RolGuard),
    (0, requiere_modulo_decorator_1.RequiereModulo)('reportes'),
    __metadata("design:paramtypes", [auditoria_service_1.AuditoriaService,
        sucursal_scope_service_1.SucursalScopeService])
], AuditoriaController);
//# sourceMappingURL=auditoria.controller.js.map