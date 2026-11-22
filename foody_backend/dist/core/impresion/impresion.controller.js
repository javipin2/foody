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
exports.ImpresionController = void 0;
const common_1 = require("@nestjs/common");
const permisos_decorator_1 = require("../../compartido/decoradores/permisos.decorator");
const usuario_actual_decorator_1 = require("../../compartido/decoradores/usuario-actual.decorator");
const requiere_modulo_decorator_1 = require("../../compartido/decoradores/requiere-modulo.decorator");
const jwt_payload_1 = require("../auth/jwt-payload");
const jwt_auth_guard_1 = require("../auth/guards/jwt-auth.guard");
const rol_guard_1 = require("../auth/guards/rol.guard");
const suscripcion_activa_guard_1 = require("../auth/guards/suscripcion-activa.guard");
const plan_features_guard_1 = require("../auth/guards/plan-features.guard");
const usuario_activo_guard_1 = require("../auth/guards/usuario-activo.guard");
const sucursal_scope_service_1 = require("../auth/sucursal-scope.service");
const impresion_service_1 = require("./impresion.service");
const reimprimir_dto_1 = require("./dto/reimprimir.dto");
let ImpresionController = class ImpresionController {
    impresion;
    sucursalScope;
    constructor(impresion, sucursalScope) {
        this.impresion = impresion;
        this.sucursalScope = sucursalScope;
    }
    async listarJobs(usuario, sucursalId, limit) {
        const sid = await this.sucursalScope.resolverLecturaOperativa(usuario, sucursalId);
        const datos = await this.impresion.listarJobs(sid, Math.min(Number(limit) || 20, 50));
        return datos;
    }
    async reimprimir(usuario, dto) {
        const sid = await this.sucursalScope.resolverLecturaOperativa(usuario, dto.sucursal_id);
        return this.impresion.reimprimirPedido(dto.pedido_id, sid);
    }
    async procesarColaManual() {
        await this.impresion.procesarColaManual();
        return { procesado: true };
    }
};
exports.ImpresionController = ImpresionController;
__decorate([
    (0, common_1.Get)('jobs'),
    (0, permisos_decorator_1.Permisos)('ver_cocina'),
    __param(0, (0, usuario_actual_decorator_1.UsuarioActual)()),
    __param(1, (0, common_1.Query)('sucursal_id')),
    __param(2, (0, common_1.Query)('limit')),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [jwt_payload_1.JwtPayload, String, String]),
    __metadata("design:returntype", Promise)
], ImpresionController.prototype, "listarJobs", null);
__decorate([
    (0, common_1.Post)('reimprimir'),
    (0, permisos_decorator_1.Permisos)('ver_cocina'),
    __param(0, (0, usuario_actual_decorator_1.UsuarioActual)()),
    __param(1, (0, common_1.Body)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [jwt_payload_1.JwtPayload,
        reimprimir_dto_1.ReimprimirComandaDto]),
    __metadata("design:returntype", Promise)
], ImpresionController.prototype, "reimprimir", null);
__decorate([
    (0, common_1.Post)('procesar-cola'),
    (0, permisos_decorator_1.Permisos)('ver_cocina'),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", []),
    __metadata("design:returntype", Promise)
], ImpresionController.prototype, "procesarColaManual", null);
exports.ImpresionController = ImpresionController = __decorate([
    (0, common_1.Controller)('impresion'),
    (0, common_1.UseGuards)(jwt_auth_guard_1.JwtAuthGuard, usuario_activo_guard_1.UsuarioActivoGuard, suscripcion_activa_guard_1.SuscripcionActivaGuard, plan_features_guard_1.PlanFeaturesGuard, rol_guard_1.RolGuard),
    (0, requiere_modulo_decorator_1.RequiereModulo)('cocina'),
    __metadata("design:paramtypes", [impresion_service_1.ImpresionService,
        sucursal_scope_service_1.SucursalScopeService])
], ImpresionController);
//# sourceMappingURL=impresion.controller.js.map