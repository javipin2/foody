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
exports.UsuariosController = void 0;
const common_1 = require("@nestjs/common");
const permisos_decorator_1 = require("../../compartido/decoradores/permisos.decorator");
const usuario_actual_decorator_1 = require("../../compartido/decoradores/usuario-actual.decorator");
const jwt_payload_1 = require("../../core/auth/jwt-payload");
const jwt_auth_guard_1 = require("../../core/auth/guards/jwt-auth.guard");
const rol_guard_1 = require("../../core/auth/guards/rol.guard");
const suscripcion_activa_guard_1 = require("../../core/auth/guards/suscripcion-activa.guard");
const usuario_activo_guard_1 = require("../../core/auth/guards/usuario-activo.guard");
const crear_usuario_dto_1 = require("./dto/crear-usuario.dto");
const sucursal_scope_service_1 = require("../../core/auth/sucursal-scope.service");
const usuarios_service_1 = require("./usuarios.service");
const listar_usuarios_query_dto_1 = require("./dto/listar-usuarios-query.dto");
let UsuariosController = class UsuariosController {
    usuariosService;
    sucursalScope;
    constructor(usuariosService, sucursalScope) {
        this.usuariosService = usuariosService;
        this.sucursalScope = sucursalScope;
    }
    async listar(usuario, query) {
        const id = this.sucursalScope.resolverSucursalId(usuario, query.sucursal_id);
        await this.sucursalScope.validarLecturaOperativa(usuario, id);
        return this.usuariosService.listarPorSucursal(id, query);
    }
    async meserosActivos(usuario, sucursalId) {
        const id = this.sucursalScope.resolverSucursalId(usuario, sucursalId);
        await this.sucursalScope.validarLecturaOperativa(usuario, id);
        return this.usuariosService.listarMeserosActivos(id);
    }
    catalogoRoles() {
        return this.usuariosService.catalogoRolesPermisos();
    }
    async permisosUsuario(usuarioId, usuario, sucursalId) {
        const id = this.sucursalScope.resolverSucursalId(usuario, sucursalId);
        await this.sucursalScope.validarLecturaOperativa(usuario, id);
        return this.usuariosService.permisosDeUsuario(usuarioId, id);
    }
    async crear(usuario, dto) {
        return this.usuariosService.crear(dto, usuario);
    }
    async cambiarEstado(usuarioId, usuario, dto, sucursalId) {
        const id = this.sucursalScope.resolverSucursalId(usuario, sucursalId);
        await this.sucursalScope.validarEscritura(usuario, id);
        return this.usuariosService.cambiarEstado(usuarioId, id, dto);
    }
    async actualizar(usuarioId, usuario, dto, sucursalId) {
        const id = this.sucursalScope.resolverSucursalId(usuario, sucursalId);
        await this.sucursalScope.validarEscritura(usuario, id);
        return this.usuariosService.actualizar(usuarioId, id, dto, usuario);
    }
};
exports.UsuariosController = UsuariosController;
__decorate([
    (0, common_1.Get)(),
    (0, permisos_decorator_1.Permisos)('gestionar_usuarios'),
    __param(0, (0, usuario_actual_decorator_1.UsuarioActual)()),
    __param(1, (0, common_1.Query)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [jwt_payload_1.JwtPayload,
        listar_usuarios_query_dto_1.ListarUsuariosQueryDto]),
    __metadata("design:returntype", Promise)
], UsuariosController.prototype, "listar", null);
__decorate([
    (0, common_1.Get)('meseros-activos'),
    (0, permisos_decorator_1.Permisos)('aprobar_pedido_mesa', 'ver_pedidos', 'gestionar_mesas'),
    __param(0, (0, usuario_actual_decorator_1.UsuarioActual)()),
    __param(1, (0, common_1.Query)('sucursal_id')),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [jwt_payload_1.JwtPayload, String]),
    __metadata("design:returntype", Promise)
], UsuariosController.prototype, "meserosActivos", null);
__decorate([
    (0, common_1.Get)('catalogo-roles'),
    (0, permisos_decorator_1.Permisos)('gestionar_usuarios'),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", []),
    __metadata("design:returntype", void 0)
], UsuariosController.prototype, "catalogoRoles", null);
__decorate([
    (0, common_1.Get)(':id/permisos'),
    (0, permisos_decorator_1.Permisos)('gestionar_usuarios'),
    __param(0, (0, common_1.Param)('id', common_1.ParseUUIDPipe)),
    __param(1, (0, usuario_actual_decorator_1.UsuarioActual)()),
    __param(2, (0, common_1.Query)('sucursal_id')),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, jwt_payload_1.JwtPayload, String]),
    __metadata("design:returntype", Promise)
], UsuariosController.prototype, "permisosUsuario", null);
__decorate([
    (0, common_1.Post)(),
    (0, common_1.HttpCode)(common_1.HttpStatus.CREATED),
    (0, permisos_decorator_1.Permisos)('gestionar_usuarios'),
    __param(0, (0, usuario_actual_decorator_1.UsuarioActual)()),
    __param(1, (0, common_1.Body)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [jwt_payload_1.JwtPayload,
        crear_usuario_dto_1.CrearUsuarioDto]),
    __metadata("design:returntype", Promise)
], UsuariosController.prototype, "crear", null);
__decorate([
    (0, common_1.Patch)(':id/estado'),
    (0, permisos_decorator_1.Permisos)('gestionar_usuarios'),
    __param(0, (0, common_1.Param)('id', common_1.ParseUUIDPipe)),
    __param(1, (0, usuario_actual_decorator_1.UsuarioActual)()),
    __param(2, (0, common_1.Body)()),
    __param(3, (0, common_1.Query)('sucursal_id')),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, jwt_payload_1.JwtPayload,
        crear_usuario_dto_1.CambiarEstadoUsuarioDto, String]),
    __metadata("design:returntype", Promise)
], UsuariosController.prototype, "cambiarEstado", null);
__decorate([
    (0, common_1.Patch)(':id'),
    (0, permisos_decorator_1.Permisos)('gestionar_usuarios'),
    __param(0, (0, common_1.Param)('id', common_1.ParseUUIDPipe)),
    __param(1, (0, usuario_actual_decorator_1.UsuarioActual)()),
    __param(2, (0, common_1.Body)()),
    __param(3, (0, common_1.Query)('sucursal_id')),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, jwt_payload_1.JwtPayload,
        crear_usuario_dto_1.ActualizarUsuarioDto, String]),
    __metadata("design:returntype", Promise)
], UsuariosController.prototype, "actualizar", null);
exports.UsuariosController = UsuariosController = __decorate([
    (0, common_1.Controller)('usuarios'),
    (0, common_1.UseGuards)(jwt_auth_guard_1.JwtAuthGuard, usuario_activo_guard_1.UsuarioActivoGuard, suscripcion_activa_guard_1.SuscripcionActivaGuard, rol_guard_1.RolGuard),
    __metadata("design:paramtypes", [usuarios_service_1.UsuariosService,
        sucursal_scope_service_1.SucursalScopeService])
], UsuariosController);
//# sourceMappingURL=usuarios.controller.js.map