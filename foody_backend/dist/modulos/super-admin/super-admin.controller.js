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
exports.SuperAdminController = void 0;
const common_1 = require("@nestjs/common");
const usuario_actual_decorator_1 = require("../../compartido/decoradores/usuario-actual.decorator");
const jwt_payload_1 = require("../../core/auth/jwt-payload");
const jwt_auth_guard_1 = require("../../core/auth/guards/jwt-auth.guard");
const super_admin_guard_1 = require("../../core/auth/guards/super-admin.guard");
const usuario_activo_guard_1 = require("../../core/auth/guards/usuario-activo.guard");
const super_admin_dto_1 = require("./dto/super-admin.dto");
const super_admin_service_1 = require("./super-admin.service");
let SuperAdminController = class SuperAdminController {
    superAdminService;
    constructor(superAdminService) {
        this.superAdminService = superAdminService;
    }
    resumen() {
        return this.superAdminService.resumenGlobal();
    }
    estadisticas() {
        return this.superAdminService.estadisticas();
    }
    ciudades() {
        return this.superAdminService.listarCiudades();
    }
    crearCiudad(dto) {
        return this.superAdminService.crearCiudad(dto);
    }
    actualizarCiudad(id, dto) {
        return this.superAdminService.actualizarCiudad(id, dto);
    }
    restaurantes() {
        return this.superAdminService.listarRestaurantes();
    }
    crearRestaurante(dto) {
        return this.superAdminService.crearRestaurante(dto);
    }
    actualizarRestaurante(id, dto) {
        return this.superAdminService.actualizarRestaurante(id, dto);
    }
    sucursalesRestaurante(restauranteId) {
        return this.superAdminService.listarSucursalesRestaurante(restauranteId);
    }
    suscripciones() {
        return this.superAdminService.listarSuscripciones();
    }
    actualizarSuscripcion(id, dto) {
        return this.superAdminService.actualizarSuscripcion(id, dto);
    }
    usuarios() {
        return this.superAdminService.listarUsuarios();
    }
    crearUsuario(dto) {
        return this.superAdminService.crearUsuario(dto);
    }
    actualizarUsuario(id, dto) {
        return this.superAdminService.actualizarUsuario(id, dto);
    }
    cambiarContrasena(id, dto) {
        return this.superAdminService.cambiarContrasenaUsuario(id, dto);
    }
    usuarioEstado(id, dto) {
        return this.superAdminService.cambiarEstadoUsuario(id, dto);
    }
    domiciliarios() {
        return this.superAdminService.listarDomiciliarios();
    }
    domiciliarioEstado(id, dto) {
        return this.superAdminService.actualizarEstadoDomiciliario(id, dto);
    }
    documentosPendientes() {
        return this.superAdminService.listarDocumentosPendientes();
    }
    documentosDomiciliario(id) {
        return this.superAdminService.listarDocumentosDomiciliario(id);
    }
    aprobarDocumento(id, dto, usuario) {
        return this.superAdminService.aprobarDocumento(id, dto, usuario.sub);
    }
    rechazarDocumento(id, dto, usuario) {
        return this.superAdminService.rechazarDocumento(id, dto, usuario.sub);
    }
    configuracion() {
        return this.superAdminService.listarConfiguracion();
    }
    actualizarConfiguracion(clave, dto, usuario) {
        return this.superAdminService.actualizarConfiguracion(clave, dto, usuario.sub);
    }
};
exports.SuperAdminController = SuperAdminController;
__decorate([
    (0, common_1.Get)('resumen'),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", []),
    __metadata("design:returntype", void 0)
], SuperAdminController.prototype, "resumen", null);
__decorate([
    (0, common_1.Get)('estadisticas'),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", []),
    __metadata("design:returntype", void 0)
], SuperAdminController.prototype, "estadisticas", null);
__decorate([
    (0, common_1.Get)('ciudades'),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", []),
    __metadata("design:returntype", void 0)
], SuperAdminController.prototype, "ciudades", null);
__decorate([
    (0, common_1.Post)('ciudades'),
    __param(0, (0, common_1.Body)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [super_admin_dto_1.CrearCiudadDto]),
    __metadata("design:returntype", void 0)
], SuperAdminController.prototype, "crearCiudad", null);
__decorate([
    (0, common_1.Patch)('ciudades/:id'),
    __param(0, (0, common_1.Param)('id', common_1.ParseUUIDPipe)),
    __param(1, (0, common_1.Body)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, super_admin_dto_1.ActualizarCiudadDto]),
    __metadata("design:returntype", void 0)
], SuperAdminController.prototype, "actualizarCiudad", null);
__decorate([
    (0, common_1.Get)('restaurantes'),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", []),
    __metadata("design:returntype", void 0)
], SuperAdminController.prototype, "restaurantes", null);
__decorate([
    (0, common_1.Post)('restaurantes'),
    __param(0, (0, common_1.Body)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [super_admin_dto_1.CrearRestauranteDto]),
    __metadata("design:returntype", void 0)
], SuperAdminController.prototype, "crearRestaurante", null);
__decorate([
    (0, common_1.Patch)('restaurantes/:id'),
    __param(0, (0, common_1.Param)('id', common_1.ParseUUIDPipe)),
    __param(1, (0, common_1.Body)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, super_admin_dto_1.ActualizarRestauranteDto]),
    __metadata("design:returntype", void 0)
], SuperAdminController.prototype, "actualizarRestaurante", null);
__decorate([
    (0, common_1.Get)('restaurantes/:restauranteId/sucursales'),
    __param(0, (0, common_1.Param)('restauranteId', common_1.ParseUUIDPipe)),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String]),
    __metadata("design:returntype", void 0)
], SuperAdminController.prototype, "sucursalesRestaurante", null);
__decorate([
    (0, common_1.Get)('suscripciones'),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", []),
    __metadata("design:returntype", void 0)
], SuperAdminController.prototype, "suscripciones", null);
__decorate([
    (0, common_1.Patch)('suscripciones/:id'),
    __param(0, (0, common_1.Param)('id', common_1.ParseUUIDPipe)),
    __param(1, (0, common_1.Body)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, super_admin_dto_1.ActualizarSuscripcionDto]),
    __metadata("design:returntype", void 0)
], SuperAdminController.prototype, "actualizarSuscripcion", null);
__decorate([
    (0, common_1.Get)('usuarios'),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", []),
    __metadata("design:returntype", void 0)
], SuperAdminController.prototype, "usuarios", null);
__decorate([
    (0, common_1.Post)('usuarios'),
    __param(0, (0, common_1.Body)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [super_admin_dto_1.CrearUsuarioSuperDto]),
    __metadata("design:returntype", void 0)
], SuperAdminController.prototype, "crearUsuario", null);
__decorate([
    (0, common_1.Patch)('usuarios/:id'),
    __param(0, (0, common_1.Param)('id', common_1.ParseUUIDPipe)),
    __param(1, (0, common_1.Body)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, super_admin_dto_1.ActualizarUsuarioSuperDto]),
    __metadata("design:returntype", void 0)
], SuperAdminController.prototype, "actualizarUsuario", null);
__decorate([
    (0, common_1.Post)('usuarios/:id/cambiar-contrasena'),
    __param(0, (0, common_1.Param)('id', common_1.ParseUUIDPipe)),
    __param(1, (0, common_1.Body)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, super_admin_dto_1.CambiarContrasenaSuperDto]),
    __metadata("design:returntype", void 0)
], SuperAdminController.prototype, "cambiarContrasena", null);
__decorate([
    (0, common_1.Patch)('usuarios/:id/estado'),
    __param(0, (0, common_1.Param)('id', common_1.ParseUUIDPipe)),
    __param(1, (0, common_1.Body)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, super_admin_dto_1.CambiarEstadoUsuarioSuperDto]),
    __metadata("design:returntype", void 0)
], SuperAdminController.prototype, "usuarioEstado", null);
__decorate([
    (0, common_1.Get)('domiciliarios'),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", []),
    __metadata("design:returntype", void 0)
], SuperAdminController.prototype, "domiciliarios", null);
__decorate([
    (0, common_1.Patch)('domiciliarios/:id/estado'),
    __param(0, (0, common_1.Param)('id', common_1.ParseUUIDPipe)),
    __param(1, (0, common_1.Body)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, super_admin_dto_1.ActualizarDomiciliarioEstadoDto]),
    __metadata("design:returntype", void 0)
], SuperAdminController.prototype, "domiciliarioEstado", null);
__decorate([
    (0, common_1.Get)('domiciliarios/documentos-pendientes'),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", []),
    __metadata("design:returntype", void 0)
], SuperAdminController.prototype, "documentosPendientes", null);
__decorate([
    (0, common_1.Get)('domiciliarios/:id/documentos'),
    __param(0, (0, common_1.Param)('id', common_1.ParseUUIDPipe)),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String]),
    __metadata("design:returntype", void 0)
], SuperAdminController.prototype, "documentosDomiciliario", null);
__decorate([
    (0, common_1.Post)('domiciliarios/:id/aprobar-documento'),
    __param(0, (0, common_1.Param)('id', common_1.ParseUUIDPipe)),
    __param(1, (0, common_1.Body)()),
    __param(2, (0, usuario_actual_decorator_1.UsuarioActual)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, super_admin_dto_1.AprobarDocumentoDto,
        jwt_payload_1.JwtPayload]),
    __metadata("design:returntype", void 0)
], SuperAdminController.prototype, "aprobarDocumento", null);
__decorate([
    (0, common_1.Post)('domiciliarios/:id/rechazar-documento'),
    __param(0, (0, common_1.Param)('id', common_1.ParseUUIDPipe)),
    __param(1, (0, common_1.Body)()),
    __param(2, (0, usuario_actual_decorator_1.UsuarioActual)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, super_admin_dto_1.RechazarDocumentoDto,
        jwt_payload_1.JwtPayload]),
    __metadata("design:returntype", void 0)
], SuperAdminController.prototype, "rechazarDocumento", null);
__decorate([
    (0, common_1.Get)('configuracion'),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", []),
    __metadata("design:returntype", void 0)
], SuperAdminController.prototype, "configuracion", null);
__decorate([
    (0, common_1.Patch)('configuracion/:clave'),
    __param(0, (0, common_1.Param)('clave')),
    __param(1, (0, common_1.Body)()),
    __param(2, (0, usuario_actual_decorator_1.UsuarioActual)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, super_admin_dto_1.ActualizarConfiguracionDto,
        jwt_payload_1.JwtPayload]),
    __metadata("design:returntype", void 0)
], SuperAdminController.prototype, "actualizarConfiguracion", null);
exports.SuperAdminController = SuperAdminController = __decorate([
    (0, common_1.Controller)('super'),
    (0, common_1.UseGuards)(jwt_auth_guard_1.JwtAuthGuard, usuario_activo_guard_1.UsuarioActivoGuard, super_admin_guard_1.SuperAdminGuard),
    __metadata("design:paramtypes", [super_admin_service_1.SuperAdminService])
], SuperAdminController);
//# sourceMappingURL=super-admin.controller.js.map