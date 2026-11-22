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
exports.CategoriasController = void 0;
const common_1 = require("@nestjs/common");
const permisos_decorator_1 = require("../../compartido/decoradores/permisos.decorator");
const usuario_actual_decorator_1 = require("../../compartido/decoradores/usuario-actual.decorator");
const jwt_payload_1 = require("../../core/auth/jwt-payload");
const jwt_auth_guard_1 = require("../../core/auth/guards/jwt-auth.guard");
const rol_guard_1 = require("../../core/auth/guards/rol.guard");
const suscripcion_activa_guard_1 = require("../../core/auth/guards/suscripcion-activa.guard");
const usuario_activo_guard_1 = require("../../core/auth/guards/usuario-activo.guard");
const sucursal_scope_service_1 = require("../../core/auth/sucursal-scope.service");
const catalogo_service_1 = require("./catalogo.service");
const actualizar_categoria_dto_1 = require("./dto/actualizar-categoria.dto");
const crear_categoria_dto_1 = require("./dto/crear-categoria.dto");
let CategoriasController = class CategoriasController {
    catalogo;
    sucursalScope;
    constructor(catalogo, sucursalScope) {
        this.catalogo = catalogo;
        this.sucursalScope = sucursalScope;
    }
    async listar(sucursalId, usuario) {
        await this.sucursalScope.validarLecturaOperativa(usuario, sucursalId);
        return this.catalogo.listarCategorias(sucursalId);
    }
    async crear(dto, usuario) {
        await this.sucursalScope.validarEscritura(usuario, dto.sucursal_id);
        return this.catalogo.crearCategoria(dto);
    }
    async actualizar(id, dto, usuario) {
        const sid = await this.sucursalScope.resolverEscritura(usuario);
        return this.catalogo.actualizarCategoria(id, sid, dto);
    }
    async eliminar(id, usuario) {
        const sid = await this.sucursalScope.resolverEscritura(usuario);
        return this.catalogo.eliminarCategoria(id, sid);
    }
    async copiarDesde(destinoId, origenId, usuario) {
        await this.sucursalScope.validarEscritura(usuario, destinoId);
        if (!this.sucursalScope.puedeVerInventarioHermanas(usuario)) {
            throw new common_1.ForbiddenException({
                error: 'COPIAR_MENU_REQUIERE_MULTI_SUCURSAL',
                message: 'Copiar menú entre sedes requiere permiso corporativo (gestionar sucursales).',
            });
        }
        return this.catalogo.copiarMenuDesde(usuario.restaurante_id, destinoId, origenId, usuario.sub);
    }
};
exports.CategoriasController = CategoriasController;
__decorate([
    (0, common_1.Get)(':sucursal_id'),
    (0, permisos_decorator_1.Permisos)('editar_productos'),
    __param(0, (0, common_1.Param)('sucursal_id')),
    __param(1, (0, usuario_actual_decorator_1.UsuarioActual)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, jwt_payload_1.JwtPayload]),
    __metadata("design:returntype", Promise)
], CategoriasController.prototype, "listar", null);
__decorate([
    (0, common_1.Post)(),
    (0, permisos_decorator_1.Permisos)('editar_productos'),
    __param(0, (0, common_1.Body)()),
    __param(1, (0, usuario_actual_decorator_1.UsuarioActual)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [crear_categoria_dto_1.CrearCategoriaDto, jwt_payload_1.JwtPayload]),
    __metadata("design:returntype", Promise)
], CategoriasController.prototype, "crear", null);
__decorate([
    (0, common_1.Patch)(':id'),
    (0, permisos_decorator_1.Permisos)('editar_productos'),
    __param(0, (0, common_1.Param)('id', common_1.ParseUUIDPipe)),
    __param(1, (0, common_1.Body)()),
    __param(2, (0, usuario_actual_decorator_1.UsuarioActual)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, actualizar_categoria_dto_1.ActualizarCategoriaDto,
        jwt_payload_1.JwtPayload]),
    __metadata("design:returntype", Promise)
], CategoriasController.prototype, "actualizar", null);
__decorate([
    (0, common_1.Delete)(':id'),
    (0, permisos_decorator_1.Permisos)('editar_productos'),
    __param(0, (0, common_1.Param)('id', common_1.ParseUUIDPipe)),
    __param(1, (0, usuario_actual_decorator_1.UsuarioActual)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, jwt_payload_1.JwtPayload]),
    __metadata("design:returntype", Promise)
], CategoriasController.prototype, "eliminar", null);
__decorate([
    (0, common_1.Post)('sucursal/:destino_id/copiar-desde/:origen_id'),
    (0, permisos_decorator_1.Permisos)('editar_productos', 'gestionar_sucursales'),
    __param(0, (0, common_1.Param)('destino_id', common_1.ParseUUIDPipe)),
    __param(1, (0, common_1.Param)('origen_id', common_1.ParseUUIDPipe)),
    __param(2, (0, usuario_actual_decorator_1.UsuarioActual)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, String, jwt_payload_1.JwtPayload]),
    __metadata("design:returntype", Promise)
], CategoriasController.prototype, "copiarDesde", null);
exports.CategoriasController = CategoriasController = __decorate([
    (0, common_1.Controller)('categorias'),
    (0, common_1.UseGuards)(jwt_auth_guard_1.JwtAuthGuard, usuario_activo_guard_1.UsuarioActivoGuard, suscripcion_activa_guard_1.SuscripcionActivaGuard, rol_guard_1.RolGuard),
    __metadata("design:paramtypes", [catalogo_service_1.CatalogoService,
        sucursal_scope_service_1.SucursalScopeService])
], CategoriasController);
//# sourceMappingURL=categorias.controller.js.map