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
exports.MesasController = void 0;
const common_1 = require("@nestjs/common");
const permisos_decorator_1 = require("../../compartido/decoradores/permisos.decorator");
const jwt_auth_guard_1 = require("../../core/auth/guards/jwt-auth.guard");
const rol_guard_1 = require("../../core/auth/guards/rol.guard");
const suscripcion_activa_guard_1 = require("../../core/auth/guards/suscripcion-activa.guard");
const usuario_activo_guard_1 = require("../../core/auth/guards/usuario-activo.guard");
const usuario_actual_decorator_1 = require("../../compartido/decoradores/usuario-actual.decorator");
const jwt_payload_1 = require("../../core/auth/jwt-payload");
const sucursal_scope_service_1 = require("../../core/auth/sucursal-scope.service");
const crear_mesa_dto_1 = require("./dto/crear-mesa.dto");
const transferir_mesa_dto_1 = require("./dto/transferir-mesa.dto");
const mesa_ops_dto_1 = require("./dto/mesa-ops.dto");
const asignar_turno_mesas_dto_1 = require("./dto/asignar-turno-mesas.dto");
const mesas_service_1 = require("./mesas.service");
let MesasController = class MesasController {
    mesasService;
    sucursalScope;
    constructor(mesasService, sucursalScope) {
        this.mesasService = mesasService;
        this.sucursalScope = sucursalScope;
    }
    async asignarTurno(dto, usuario) {
        await this.sucursalScope.validarEscritura(usuario, dto.sucursal_id);
        return this.mesasService.asignarTurno(dto);
    }
    async transferir(dto, usuario) {
        await this.sucursalScope.validarEscritura(usuario, dto.sucursal_id);
        return this.mesasService.transferir(dto, usuario.sub);
    }
    async reservar(mesaId, dto, usuario) {
        await this.sucursalScope.validarEscritura(usuario, dto.sucursal_id);
        return this.mesasService.reservar(mesaId, dto.sucursal_id, dto);
    }
    async cancelarReserva(mesaId, sucursalId, usuario) {
        const id = await this.sucursalScope.resolverEscritura(usuario, sucursalId);
        return this.mesasService.cancelarReserva(mesaId, id);
    }
    async unir(dto, usuario) {
        await this.sucursalScope.validarEscritura(usuario, dto.sucursal_id);
        return this.mesasService.unirMesas(dto.sucursal_id, dto.mesa_principal_id, dto.mesas_secundarias, usuario.sub);
    }
    async salioSinPagar(mesaId, dto, usuario) {
        await this.sucursalScope.validarEscritura(usuario, dto.sucursal_id);
        return this.mesasService.registrarSalidaSinPagar(mesaId, dto.sucursal_id, usuario.sub, dto, usuario.rol);
    }
    async qr(mesaId, sucursalId, baseUrl, usuario) {
        const id = await this.sucursalScope.resolverLecturaOperativa(usuario, sucursalId);
        return this.mesasService.obtenerQr(mesaId, id, baseUrl);
    }
    async listar(sucursalId, incluirInactivas, usuario) {
        const id = await this.sucursalScope.resolverLecturaOperativa(usuario, sucursalId);
        return this.mesasService.listarConEstado(id, incluirInactivas === 'true');
    }
    async crear(dto, usuario) {
        await this.sucursalScope.validarEscritura(usuario, dto.sucursal_id);
        return this.mesasService.crear(dto, usuario.restaurante_id ?? undefined);
    }
    async actualizar(mesaId, sucursalId, dto, usuario) {
        const id = await this.sucursalScope.resolverEscritura(usuario, sucursalId);
        return this.mesasService.actualizar(mesaId, id, dto);
    }
    async desactivar(mesaId, sucursalId, usuario) {
        const id = await this.sucursalScope.resolverEscritura(usuario, sucursalId);
        return this.mesasService.desactivar(mesaId, id);
    }
};
exports.MesasController = MesasController;
__decorate([
    (0, common_1.Post)('asignar-turno'),
    (0, permisos_decorator_1.Permisos)('gestionar_mesas'),
    __param(0, (0, common_1.Body)()),
    __param(1, (0, usuario_actual_decorator_1.UsuarioActual)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [asignar_turno_mesas_dto_1.AsignarTurnoMesasDto,
        jwt_payload_1.JwtPayload]),
    __metadata("design:returntype", Promise)
], MesasController.prototype, "asignarTurno", null);
__decorate([
    (0, common_1.Post)('transferir'),
    (0, permisos_decorator_1.Permisos)('gestionar_mesas', 'cobrar_pedido'),
    __param(0, (0, common_1.Body)()),
    __param(1, (0, usuario_actual_decorator_1.UsuarioActual)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [transferir_mesa_dto_1.TransferirMesaDto,
        jwt_payload_1.JwtPayload]),
    __metadata("design:returntype", Promise)
], MesasController.prototype, "transferir", null);
__decorate([
    (0, common_1.Post)(':id/reservar'),
    (0, permisos_decorator_1.Permisos)('gestionar_mesas'),
    __param(0, (0, common_1.Param)('id', common_1.ParseUUIDPipe)),
    __param(1, (0, common_1.Body)()),
    __param(2, (0, usuario_actual_decorator_1.UsuarioActual)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, mesa_ops_dto_1.ReservarMesaDto,
        jwt_payload_1.JwtPayload]),
    __metadata("design:returntype", Promise)
], MesasController.prototype, "reservar", null);
__decorate([
    (0, common_1.Post)(':id/cancelar-reserva'),
    (0, permisos_decorator_1.Permisos)('gestionar_mesas'),
    __param(0, (0, common_1.Param)('id', common_1.ParseUUIDPipe)),
    __param(1, (0, common_1.Query)('sucursal_id')),
    __param(2, (0, usuario_actual_decorator_1.UsuarioActual)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, String, jwt_payload_1.JwtPayload]),
    __metadata("design:returntype", Promise)
], MesasController.prototype, "cancelarReserva", null);
__decorate([
    (0, common_1.Post)('unir'),
    (0, permisos_decorator_1.Permisos)('gestionar_mesas'),
    __param(0, (0, common_1.Body)()),
    __param(1, (0, usuario_actual_decorator_1.UsuarioActual)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [mesa_ops_dto_1.UnirMesasDto,
        jwt_payload_1.JwtPayload]),
    __metadata("design:returntype", Promise)
], MesasController.prototype, "unir", null);
__decorate([
    (0, common_1.Post)(':id/salio-sin-pagar'),
    (0, permisos_decorator_1.Permisos)('gestionar_mesas', 'ver_caja'),
    __param(0, (0, common_1.Param)('id', common_1.ParseUUIDPipe)),
    __param(1, (0, common_1.Body)()),
    __param(2, (0, usuario_actual_decorator_1.UsuarioActual)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, mesa_ops_dto_1.SalioSinPagarDto,
        jwt_payload_1.JwtPayload]),
    __metadata("design:returntype", Promise)
], MesasController.prototype, "salioSinPagar", null);
__decorate([
    (0, common_1.Get)(':id/qr'),
    (0, permisos_decorator_1.Permisos)('gestionar_mesas'),
    __param(0, (0, common_1.Param)('id', common_1.ParseUUIDPipe)),
    __param(1, (0, common_1.Query)('sucursal_id')),
    __param(2, (0, common_1.Query)('base_url')),
    __param(3, (0, usuario_actual_decorator_1.UsuarioActual)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, String, Object, jwt_payload_1.JwtPayload]),
    __metadata("design:returntype", Promise)
], MesasController.prototype, "qr", null);
__decorate([
    (0, common_1.Get)(':sucursal_id'),
    (0, permisos_decorator_1.Permisos)('gestionar_mesas', 'ver_mesas', 'ver_pedidos', 'crear_pedido'),
    __param(0, (0, common_1.Param)('sucursal_id', common_1.ParseUUIDPipe)),
    __param(1, (0, common_1.Query)('incluir_inactivas')),
    __param(2, (0, usuario_actual_decorator_1.UsuarioActual)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, Object, jwt_payload_1.JwtPayload]),
    __metadata("design:returntype", Promise)
], MesasController.prototype, "listar", null);
__decorate([
    (0, common_1.Post)(),
    (0, permisos_decorator_1.Permisos)('gestionar_mesas'),
    __param(0, (0, common_1.Body)()),
    __param(1, (0, usuario_actual_decorator_1.UsuarioActual)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [crear_mesa_dto_1.CrearMesaDto,
        jwt_payload_1.JwtPayload]),
    __metadata("design:returntype", Promise)
], MesasController.prototype, "crear", null);
__decorate([
    (0, common_1.Patch)(':id'),
    (0, permisos_decorator_1.Permisos)('gestionar_mesas'),
    __param(0, (0, common_1.Param)('id', common_1.ParseUUIDPipe)),
    __param(1, (0, common_1.Query)('sucursal_id')),
    __param(2, (0, common_1.Body)()),
    __param(3, (0, usuario_actual_decorator_1.UsuarioActual)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, String, crear_mesa_dto_1.ActualizarMesaDto,
        jwt_payload_1.JwtPayload]),
    __metadata("design:returntype", Promise)
], MesasController.prototype, "actualizar", null);
__decorate([
    (0, common_1.Delete)(':id'),
    (0, permisos_decorator_1.Permisos)('gestionar_mesas'),
    __param(0, (0, common_1.Param)('id', common_1.ParseUUIDPipe)),
    __param(1, (0, common_1.Query)('sucursal_id')),
    __param(2, (0, usuario_actual_decorator_1.UsuarioActual)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, String, jwt_payload_1.JwtPayload]),
    __metadata("design:returntype", Promise)
], MesasController.prototype, "desactivar", null);
exports.MesasController = MesasController = __decorate([
    (0, common_1.Controller)('mesas'),
    (0, common_1.UseGuards)(jwt_auth_guard_1.JwtAuthGuard, usuario_activo_guard_1.UsuarioActivoGuard, suscripcion_activa_guard_1.SuscripcionActivaGuard, rol_guard_1.RolGuard),
    __metadata("design:paramtypes", [mesas_service_1.MesasService,
        sucursal_scope_service_1.SucursalScopeService])
], MesasController);
//# sourceMappingURL=mesas.controller.js.map