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
exports.CajaController = void 0;
const common_1 = require("@nestjs/common");
const permisos_decorator_1 = require("../../compartido/decoradores/permisos.decorator");
const usuario_actual_decorator_1 = require("../../compartido/decoradores/usuario-actual.decorator");
const jwt_payload_1 = require("../../core/auth/jwt-payload");
const jwt_auth_guard_1 = require("../../core/auth/guards/jwt-auth.guard");
const rol_guard_1 = require("../../core/auth/guards/rol.guard");
const suscripcion_activa_guard_1 = require("../../core/auth/guards/suscripcion-activa.guard");
const usuario_activo_guard_1 = require("../../core/auth/guards/usuario-activo.guard");
const sucursal_scope_service_1 = require("../../core/auth/sucursal-scope.service");
const caja_service_1 = require("./caja.service");
const abrir_caja_dto_1 = require("./dto/abrir-caja.dto");
const cerrar_caja_dto_1 = require("./dto/cerrar-caja.dto");
const gasto_caja_dto_1 = require("./dto/gasto-caja.dto");
const crear_cuenta_por_cobrar_dto_1 = require("./dto/crear-cuenta-por-cobrar.dto");
const retiro_caja_dto_1 = require("./dto/retiro-caja.dto");
const devolucion_caja_dto_1 = require("./dto/devolucion-caja.dto");
let CajaController = class CajaController {
    cajaService;
    sucursalScope;
    constructor(cajaService, sucursalScope) {
        this.cajaService = cajaService;
        this.sucursalScope = sucursalScope;
    }
    async activa(sucursalId, usuario) {
        const id = await this.sucursalScope.resolverLecturaOperativa(usuario, sucursalId);
        return this.cajaService.obtenerActiva(id, {
            ocultarSaldo: usuario.rol === 'cajero',
        });
    }
    async abrir(dto, usuario) {
        const id = await this.sucursalScope.resolverEscritura(usuario, dto.sucursal_id);
        return this.cajaService.abrir({ ...dto, sucursal_id: id }, usuario.sub);
    }
    async cerrar(dto, usuario) {
        await this.sucursalScope.resolverEscritura(usuario, usuario.sucursal_id);
        return this.cajaService.cerrar(dto, usuario.sub);
    }
    async listarFiados(sucursalId, usuario) {
        const id = await this.sucursalScope.resolverLecturaOperativa(usuario, sucursalId);
        return this.cajaService.listarCuentasPorCobrar(id);
    }
    async crearFiado(dto, usuario) {
        const id = await this.sucursalScope.resolverEscritura(usuario, dto.sucursal_id);
        return this.cajaService.crearCuentaPorCobrar({ ...dto, sucursal_id: id }, usuario.sub);
    }
    async pagarFiado(id, usuario) {
        const sucursalId = await this.sucursalScope.resolverEscritura(usuario, usuario.sucursal_id);
        return this.cajaService.pagarCuentaPorCobrar(id, sucursalId, usuario.sub);
    }
    async movimientos(cajaId, usuario) {
        const sucursalId = await this.sucursalScope.resolverLecturaOperativa(usuario, usuario.sucursal_id);
        return this.cajaService.listarMovimientos(cajaId, sucursalId);
    }
    async retiro(dto, usuario) {
        const sucursalId = await this.sucursalScope.resolverEscritura(usuario, usuario.sucursal_id);
        return this.cajaService.retiroParcial(dto, usuario.sub, sucursalId);
    }
    async devolucion(dto, usuario) {
        const sucursalId = await this.sucursalScope.resolverEscritura(usuario, dto.sucursal_id);
        return this.cajaService.registrarDevolucion({ ...dto, sucursal_id: sucursalId }, usuario.sub);
    }
    async gasto(dto, usuario) {
        const sucursalId = await this.sucursalScope.resolverEscritura(usuario, usuario.sucursal_id);
        return this.cajaService.registrarGasto(dto, usuario.sub, sucursalId);
    }
};
exports.CajaController = CajaController;
__decorate([
    (0, common_1.Get)('activa/:sucursal_id'),
    (0, permisos_decorator_1.Permisos)('ver_caja'),
    __param(0, (0, common_1.Param)('sucursal_id')),
    __param(1, (0, usuario_actual_decorator_1.UsuarioActual)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, jwt_payload_1.JwtPayload]),
    __metadata("design:returntype", Promise)
], CajaController.prototype, "activa", null);
__decorate([
    (0, common_1.Post)('abrir'),
    (0, permisos_decorator_1.Permisos)('abrir_caja'),
    __param(0, (0, common_1.Body)()),
    __param(1, (0, usuario_actual_decorator_1.UsuarioActual)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [abrir_caja_dto_1.AbrirCajaDto,
        jwt_payload_1.JwtPayload]),
    __metadata("design:returntype", Promise)
], CajaController.prototype, "abrir", null);
__decorate([
    (0, common_1.Post)('cerrar'),
    (0, permisos_decorator_1.Permisos)('cerrar_caja'),
    __param(0, (0, common_1.Body)()),
    __param(1, (0, usuario_actual_decorator_1.UsuarioActual)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [cerrar_caja_dto_1.CerrarCajaDto,
        jwt_payload_1.JwtPayload]),
    __metadata("design:returntype", Promise)
], CajaController.prototype, "cerrar", null);
__decorate([
    (0, common_1.Get)('cuentas-por-cobrar/:sucursal_id'),
    (0, permisos_decorator_1.Permisos)('ver_caja'),
    __param(0, (0, common_1.Param)('sucursal_id')),
    __param(1, (0, usuario_actual_decorator_1.UsuarioActual)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, jwt_payload_1.JwtPayload]),
    __metadata("design:returntype", Promise)
], CajaController.prototype, "listarFiados", null);
__decorate([
    (0, common_1.Post)('cuentas-por-cobrar'),
    (0, permisos_decorator_1.Permisos)('ver_caja'),
    __param(0, (0, common_1.Body)()),
    __param(1, (0, usuario_actual_decorator_1.UsuarioActual)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [crear_cuenta_por_cobrar_dto_1.CrearCuentaPorCobrarDto,
        jwt_payload_1.JwtPayload]),
    __metadata("design:returntype", Promise)
], CajaController.prototype, "crearFiado", null);
__decorate([
    (0, common_1.Patch)('cuentas-por-cobrar/:id/pagar'),
    (0, permisos_decorator_1.Permisos)('ver_caja'),
    __param(0, (0, common_1.Param)('id')),
    __param(1, (0, usuario_actual_decorator_1.UsuarioActual)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, jwt_payload_1.JwtPayload]),
    __metadata("design:returntype", Promise)
], CajaController.prototype, "pagarFiado", null);
__decorate([
    (0, common_1.Get)(':caja_id/movimientos'),
    (0, permisos_decorator_1.Permisos)('ver_caja'),
    __param(0, (0, common_1.Param)('caja_id')),
    __param(1, (0, usuario_actual_decorator_1.UsuarioActual)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, jwt_payload_1.JwtPayload]),
    __metadata("design:returntype", Promise)
], CajaController.prototype, "movimientos", null);
__decorate([
    (0, common_1.Post)('retiro-parcial'),
    (0, permisos_decorator_1.Permisos)('hacer_retiro_parcial'),
    __param(0, (0, common_1.Body)()),
    __param(1, (0, usuario_actual_decorator_1.UsuarioActual)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [retiro_caja_dto_1.RetiroCajaDto,
        jwt_payload_1.JwtPayload]),
    __metadata("design:returntype", Promise)
], CajaController.prototype, "retiro", null);
__decorate([
    (0, common_1.Post)('devolucion'),
    (0, permisos_decorator_1.Permisos)('ver_caja'),
    __param(0, (0, common_1.Body)()),
    __param(1, (0, usuario_actual_decorator_1.UsuarioActual)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [devolucion_caja_dto_1.DevolucionCajaDto,
        jwt_payload_1.JwtPayload]),
    __metadata("design:returntype", Promise)
], CajaController.prototype, "devolucion", null);
__decorate([
    (0, common_1.Post)('gastos'),
    (0, permisos_decorator_1.Permisos)('ver_caja'),
    __param(0, (0, common_1.Body)()),
    __param(1, (0, usuario_actual_decorator_1.UsuarioActual)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [gasto_caja_dto_1.GastoCajaDto,
        jwt_payload_1.JwtPayload]),
    __metadata("design:returntype", Promise)
], CajaController.prototype, "gasto", null);
exports.CajaController = CajaController = __decorate([
    (0, common_1.Controller)('caja'),
    (0, common_1.UseGuards)(jwt_auth_guard_1.JwtAuthGuard, usuario_activo_guard_1.UsuarioActivoGuard, suscripcion_activa_guard_1.SuscripcionActivaGuard, rol_guard_1.RolGuard),
    __metadata("design:paramtypes", [caja_service_1.CajaService,
        sucursal_scope_service_1.SucursalScopeService])
], CajaController);
//# sourceMappingURL=caja.controller.js.map