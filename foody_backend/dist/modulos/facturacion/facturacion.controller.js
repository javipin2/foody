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
exports.FacturacionController = void 0;
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
const guardar_config_fiscal_dto_1 = require("./dto/guardar-config-fiscal.dto");
const anular_factura_dto_1 = require("./dto/anular-factura.dto");
const facturacion_service_1 = require("./facturacion.service");
let FacturacionController = class FacturacionController {
    facturacionService;
    sucursalScope;
    constructor(facturacionService, sucursalScope) {
        this.facturacionService = facturacionService;
        this.sucursalScope = sucursalScope;
    }
    async obtenerConfig(sucursalId, usuario) {
        await this.sucursalScope.validarLecturaOperativa(usuario, sucursalId);
        return this.facturacionService.obtenerConfig(sucursalId);
    }
    async guardarConfig(dto, usuario) {
        await this.sucursalScope.validarEscritura(usuario, dto.sucursal_id);
        return this.facturacionService.guardarConfig(dto);
    }
    async pdf(facturaId, usuario, sucursalId) {
        const sid = await this.sucursalScope.resolverLecturaOperativa(usuario, sucursalId);
        return this.facturacionService.obtenerPdf(facturaId, sid);
    }
    async listarFacturas(sucursalId, estado, usuario) {
        await this.sucursalScope.validarLecturaOperativa(usuario, sucursalId);
        return this.facturacionService.listarFacturas(sucursalId, estado);
    }
    async emitir(pedidoId, usuario, sucursalId) {
        const sid = await this.sucursalScope.resolverEscritura(usuario, sucursalId);
        return this.facturacionService.emitir(pedidoId, sid);
    }
    async anular(facturaId, body, usuario, sucursalId) {
        const sid = await this.sucursalScope.resolverEscritura(usuario, sucursalId);
        return this.facturacionService.anular(facturaId, sid, usuario.sub, body.motivo);
    }
};
exports.FacturacionController = FacturacionController;
__decorate([
    (0, common_1.Get)('config/:sucursal_id'),
    (0, permisos_decorator_1.Permisos)('ver_facturacion', 'gestionar_facturacion'),
    __param(0, (0, common_1.Param)('sucursal_id', common_1.ParseUUIDPipe)),
    __param(1, (0, usuario_actual_decorator_1.UsuarioActual)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, jwt_payload_1.JwtPayload]),
    __metadata("design:returntype", Promise)
], FacturacionController.prototype, "obtenerConfig", null);
__decorate([
    (0, common_1.Post)('config'),
    (0, permisos_decorator_1.Permisos)('gestionar_facturacion'),
    __param(0, (0, common_1.Body)()),
    __param(1, (0, usuario_actual_decorator_1.UsuarioActual)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [guardar_config_fiscal_dto_1.GuardarConfigFiscalDto,
        jwt_payload_1.JwtPayload]),
    __metadata("design:returntype", Promise)
], FacturacionController.prototype, "guardarConfig", null);
__decorate([
    (0, common_1.Get)('facturas/:id/pdf'),
    (0, permisos_decorator_1.Permisos)('ver_facturacion', 'gestionar_facturacion'),
    __param(0, (0, common_1.Param)('id', common_1.ParseUUIDPipe)),
    __param(1, (0, usuario_actual_decorator_1.UsuarioActual)()),
    __param(2, (0, common_1.Query)('sucursal_id')),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, jwt_payload_1.JwtPayload, String]),
    __metadata("design:returntype", Promise)
], FacturacionController.prototype, "pdf", null);
__decorate([
    (0, common_1.Get)('facturas/:sucursal_id'),
    (0, permisos_decorator_1.Permisos)('ver_facturacion', 'gestionar_facturacion'),
    __param(0, (0, common_1.Param)('sucursal_id', common_1.ParseUUIDPipe)),
    __param(1, (0, common_1.Query)('estado')),
    __param(2, (0, usuario_actual_decorator_1.UsuarioActual)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, Object, jwt_payload_1.JwtPayload]),
    __metadata("design:returntype", Promise)
], FacturacionController.prototype, "listarFacturas", null);
__decorate([
    (0, common_1.Post)('emitir/:pedido_id'),
    (0, permisos_decorator_1.Permisos)('gestionar_facturacion'),
    __param(0, (0, common_1.Param)('pedido_id', common_1.ParseUUIDPipe)),
    __param(1, (0, usuario_actual_decorator_1.UsuarioActual)()),
    __param(2, (0, common_1.Query)('sucursal_id')),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, jwt_payload_1.JwtPayload, String]),
    __metadata("design:returntype", Promise)
], FacturacionController.prototype, "emitir", null);
__decorate([
    (0, common_1.Post)('anular/:factura_id'),
    (0, permisos_decorator_1.Permisos)('gestionar_facturacion'),
    __param(0, (0, common_1.Param)('factura_id', common_1.ParseUUIDPipe)),
    __param(1, (0, common_1.Body)()),
    __param(2, (0, usuario_actual_decorator_1.UsuarioActual)()),
    __param(3, (0, common_1.Query)('sucursal_id')),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, anular_factura_dto_1.AnularFacturaDto,
        jwt_payload_1.JwtPayload, String]),
    __metadata("design:returntype", Promise)
], FacturacionController.prototype, "anular", null);
exports.FacturacionController = FacturacionController = __decorate([
    (0, common_1.Controller)('facturacion'),
    (0, common_1.UseGuards)(jwt_auth_guard_1.JwtAuthGuard, usuario_activo_guard_1.UsuarioActivoGuard, suscripcion_activa_guard_1.SuscripcionActivaGuard, plan_features_guard_1.PlanFeaturesGuard, rol_guard_1.RolGuard),
    (0, requiere_modulo_decorator_1.RequiereModulo)('facturacion'),
    __metadata("design:paramtypes", [facturacion_service_1.FacturacionService,
        sucursal_scope_service_1.SucursalScopeService])
], FacturacionController);
//# sourceMappingURL=facturacion.controller.js.map