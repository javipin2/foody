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
exports.FinanzasController = void 0;
const common_1 = require("@nestjs/common");
const permisos_decorator_1 = require("../../compartido/decoradores/permisos.decorator");
const usuario_actual_decorator_1 = require("../../compartido/decoradores/usuario-actual.decorator");
const jwt_payload_1 = require("../../core/auth/jwt-payload");
const jwt_auth_guard_1 = require("../../core/auth/guards/jwt-auth.guard");
const rol_guard_1 = require("../../core/auth/guards/rol.guard");
const suscripcion_activa_guard_1 = require("../../core/auth/guards/suscripcion-activa.guard");
const usuario_activo_guard_1 = require("../../core/auth/guards/usuario-activo.guard");
const sucursal_scope_service_1 = require("../../core/auth/sucursal-scope.service");
const actualizar_costo_fijo_dto_1 = require("./dto/actualizar-costo-fijo.dto");
const actualizar_empleado_dto_1 = require("./dto/actualizar-empleado.dto");
const crear_costo_fijo_dto_1 = require("./dto/crear-costo-fijo.dto");
const crear_empleado_dto_1 = require("./dto/crear-empleado.dto");
const crear_gasto_manual_dto_1 = require("./dto/crear-gasto-manual.dto");
const pagar_costo_fijo_dto_1 = require("./dto/pagar-costo-fijo.dto");
const pagar_empleado_dto_1 = require("./dto/pagar-empleado.dto");
const finanzas_service_1 = require("./finanzas.service");
let FinanzasController = class FinanzasController {
    finanzasService;
    sucursalScope;
    constructor(finanzasService, sucursalScope) {
        this.finanzasService = finanzasService;
        this.sucursalScope = sucursalScope;
    }
    async listarCostosFijos(sucursalId, incluirInactivos, usuario) {
        const id = await this.sucursalScope.resolverLecturaOperativa(usuario, sucursalId);
        return this.finanzasService.listarCostosFijos(id, incluirInactivos === 'true' || incluirInactivos === '1');
    }
    async crearCostoFijo(dto, usuario) {
        const id = await this.sucursalScope.resolverEscritura(usuario, dto.sucursal_id);
        return this.finanzasService.crearCostoFijo({ ...dto, sucursal_id: id });
    }
    async actualizarCostoFijo(id, dto, sucursalId, usuario) {
        const sid = await this.sucursalScope.resolverEscritura(usuario, sucursalId ?? usuario.sucursal_id);
        return this.finanzasService.actualizarCostoFijo(id, sid, dto);
    }
    async eliminarCostoFijo(id, sucursalId, usuario) {
        const sid = await this.sucursalScope.resolverEscritura(usuario, sucursalId ?? usuario.sucursal_id);
        return this.finanzasService.eliminarCostoFijo(id, sid);
    }
    async pagarCostoFijo(id, dto, sucursalId, usuario) {
        const sid = await this.sucursalScope.resolverEscritura(usuario, sucursalId ?? usuario.sucursal_id);
        return this.finanzasService.pagarCostoFijo(id, sid, usuario.sub, dto);
    }
    async listarEmpleados(sucursalId, incluirInactivos, usuario) {
        const id = await this.sucursalScope.resolverLecturaOperativa(usuario, sucursalId);
        return this.finanzasService.listarEmpleados(id, incluirInactivos === 'true' || incluirInactivos === '1');
    }
    async crearEmpleado(dto, usuario) {
        const id = await this.sucursalScope.resolverEscritura(usuario, dto.sucursal_id);
        return this.finanzasService.crearEmpleado({ ...dto, sucursal_id: id });
    }
    async actualizarEmpleado(id, dto, sucursalId, usuario) {
        const sid = await this.sucursalScope.resolverEscritura(usuario, sucursalId ?? usuario.sucursal_id);
        return this.finanzasService.actualizarEmpleado(id, sid, dto);
    }
    async pagarEmpleado(id, dto, sucursalId, usuario) {
        const sid = await this.sucursalScope.resolverEscritura(usuario, sucursalId ?? usuario.sucursal_id);
        return this.finanzasService.pagarEmpleado(id, sid, usuario.sub, dto);
    }
    async resumen(sucursalId, usuario) {
        const id = await this.sucursalScope.resolverLecturaOperativa(usuario, sucursalId);
        return this.finanzasService.resumen(id);
    }
    async listarGastos(sucursalId, desde, hasta, usuario) {
        const id = await this.sucursalScope.resolverLecturaOperativa(usuario, sucursalId);
        return this.finanzasService.listarGastos(id, desde, hasta);
    }
    async crearGastoManual(dto, usuario) {
        const id = await this.sucursalScope.resolverEscritura(usuario, dto.sucursal_id);
        return this.finanzasService.crearGastoManual({ ...dto, sucursal_id: id }, usuario.sub);
    }
};
exports.FinanzasController = FinanzasController;
__decorate([
    (0, common_1.Get)('costos-fijos/:sucursal_id'),
    (0, permisos_decorator_1.Permisos)('ver_finanzas'),
    __param(0, (0, common_1.Param)('sucursal_id', common_1.ParseUUIDPipe)),
    __param(1, (0, common_1.Query)('incluir_inactivos')),
    __param(2, (0, usuario_actual_decorator_1.UsuarioActual)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, Object, jwt_payload_1.JwtPayload]),
    __metadata("design:returntype", Promise)
], FinanzasController.prototype, "listarCostosFijos", null);
__decorate([
    (0, common_1.Post)('costos-fijos'),
    (0, permisos_decorator_1.Permisos)('gestionar_finanzas'),
    __param(0, (0, common_1.Body)()),
    __param(1, (0, usuario_actual_decorator_1.UsuarioActual)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [crear_costo_fijo_dto_1.CrearCostoFijoDto,
        jwt_payload_1.JwtPayload]),
    __metadata("design:returntype", Promise)
], FinanzasController.prototype, "crearCostoFijo", null);
__decorate([
    (0, common_1.Patch)('costos-fijos/:id'),
    (0, permisos_decorator_1.Permisos)('gestionar_finanzas'),
    __param(0, (0, common_1.Param)('id', common_1.ParseUUIDPipe)),
    __param(1, (0, common_1.Body)()),
    __param(2, (0, common_1.Query)('sucursal_id')),
    __param(3, (0, usuario_actual_decorator_1.UsuarioActual)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, actualizar_costo_fijo_dto_1.ActualizarCostoFijoDto, Object, jwt_payload_1.JwtPayload]),
    __metadata("design:returntype", Promise)
], FinanzasController.prototype, "actualizarCostoFijo", null);
__decorate([
    (0, common_1.Delete)('costos-fijos/:id'),
    (0, permisos_decorator_1.Permisos)('gestionar_finanzas'),
    __param(0, (0, common_1.Param)('id', common_1.ParseUUIDPipe)),
    __param(1, (0, common_1.Query)('sucursal_id')),
    __param(2, (0, usuario_actual_decorator_1.UsuarioActual)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, Object, jwt_payload_1.JwtPayload]),
    __metadata("design:returntype", Promise)
], FinanzasController.prototype, "eliminarCostoFijo", null);
__decorate([
    (0, common_1.Post)('costos-fijos/:id/pagar'),
    (0, permisos_decorator_1.Permisos)('gestionar_finanzas'),
    __param(0, (0, common_1.Param)('id', common_1.ParseUUIDPipe)),
    __param(1, (0, common_1.Body)()),
    __param(2, (0, common_1.Query)('sucursal_id')),
    __param(3, (0, usuario_actual_decorator_1.UsuarioActual)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, pagar_costo_fijo_dto_1.PagarCostoFijoDto, Object, jwt_payload_1.JwtPayload]),
    __metadata("design:returntype", Promise)
], FinanzasController.prototype, "pagarCostoFijo", null);
__decorate([
    (0, common_1.Get)('empleados/:sucursal_id'),
    (0, permisos_decorator_1.Permisos)('ver_finanzas'),
    __param(0, (0, common_1.Param)('sucursal_id', common_1.ParseUUIDPipe)),
    __param(1, (0, common_1.Query)('incluir_inactivos')),
    __param(2, (0, usuario_actual_decorator_1.UsuarioActual)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, Object, jwt_payload_1.JwtPayload]),
    __metadata("design:returntype", Promise)
], FinanzasController.prototype, "listarEmpleados", null);
__decorate([
    (0, common_1.Post)('empleados'),
    (0, permisos_decorator_1.Permisos)('gestionar_finanzas'),
    __param(0, (0, common_1.Body)()),
    __param(1, (0, usuario_actual_decorator_1.UsuarioActual)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [crear_empleado_dto_1.CrearEmpleadoDto,
        jwt_payload_1.JwtPayload]),
    __metadata("design:returntype", Promise)
], FinanzasController.prototype, "crearEmpleado", null);
__decorate([
    (0, common_1.Patch)('empleados/:id'),
    (0, permisos_decorator_1.Permisos)('gestionar_finanzas'),
    __param(0, (0, common_1.Param)('id', common_1.ParseUUIDPipe)),
    __param(1, (0, common_1.Body)()),
    __param(2, (0, common_1.Query)('sucursal_id')),
    __param(3, (0, usuario_actual_decorator_1.UsuarioActual)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, actualizar_empleado_dto_1.ActualizarEmpleadoDto, Object, jwt_payload_1.JwtPayload]),
    __metadata("design:returntype", Promise)
], FinanzasController.prototype, "actualizarEmpleado", null);
__decorate([
    (0, common_1.Post)('empleados/:id/pagar'),
    (0, permisos_decorator_1.Permisos)('gestionar_finanzas'),
    __param(0, (0, common_1.Param)('id', common_1.ParseUUIDPipe)),
    __param(1, (0, common_1.Body)()),
    __param(2, (0, common_1.Query)('sucursal_id')),
    __param(3, (0, usuario_actual_decorator_1.UsuarioActual)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, pagar_empleado_dto_1.PagarEmpleadoDto, Object, jwt_payload_1.JwtPayload]),
    __metadata("design:returntype", Promise)
], FinanzasController.prototype, "pagarEmpleado", null);
__decorate([
    (0, common_1.Get)('resumen/:sucursal_id'),
    (0, permisos_decorator_1.Permisos)('ver_finanzas'),
    __param(0, (0, common_1.Param)('sucursal_id', common_1.ParseUUIDPipe)),
    __param(1, (0, usuario_actual_decorator_1.UsuarioActual)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, jwt_payload_1.JwtPayload]),
    __metadata("design:returntype", Promise)
], FinanzasController.prototype, "resumen", null);
__decorate([
    (0, common_1.Get)('gastos/:sucursal_id'),
    (0, permisos_decorator_1.Permisos)('ver_finanzas'),
    __param(0, (0, common_1.Param)('sucursal_id', common_1.ParseUUIDPipe)),
    __param(1, (0, common_1.Query)('desde')),
    __param(2, (0, common_1.Query)('hasta')),
    __param(3, (0, usuario_actual_decorator_1.UsuarioActual)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, Object, Object, jwt_payload_1.JwtPayload]),
    __metadata("design:returntype", Promise)
], FinanzasController.prototype, "listarGastos", null);
__decorate([
    (0, common_1.Post)('gastos'),
    (0, permisos_decorator_1.Permisos)('gestionar_finanzas'),
    __param(0, (0, common_1.Body)()),
    __param(1, (0, usuario_actual_decorator_1.UsuarioActual)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [crear_gasto_manual_dto_1.CrearGastoManualDto,
        jwt_payload_1.JwtPayload]),
    __metadata("design:returntype", Promise)
], FinanzasController.prototype, "crearGastoManual", null);
exports.FinanzasController = FinanzasController = __decorate([
    (0, common_1.Controller)('finanzas'),
    (0, common_1.UseGuards)(jwt_auth_guard_1.JwtAuthGuard, usuario_activo_guard_1.UsuarioActivoGuard, suscripcion_activa_guard_1.SuscripcionActivaGuard, rol_guard_1.RolGuard),
    __metadata("design:paramtypes", [finanzas_service_1.FinanzasService,
        sucursal_scope_service_1.SucursalScopeService])
], FinanzasController);
//# sourceMappingURL=finanzas.controller.js.map