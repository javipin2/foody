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
exports.AlmacenamientoController = void 0;
const common_1 = require("@nestjs/common");
const platform_express_1 = require("@nestjs/platform-express");
const permisos_decorator_1 = require("../../compartido/decoradores/permisos.decorator");
const usuario_actual_decorator_1 = require("../../compartido/decoradores/usuario-actual.decorator");
const jwt_payload_1 = require("../../core/auth/jwt-payload");
const jwt_auth_guard_1 = require("../../core/auth/guards/jwt-auth.guard");
const rol_guard_1 = require("../../core/auth/guards/rol.guard");
const suscripcion_activa_guard_1 = require("../../core/auth/guards/suscripcion-activa.guard");
const usuario_activo_guard_1 = require("../../core/auth/guards/usuario-activo.guard");
const sucursal_scope_service_1 = require("../../core/auth/sucursal-scope.service");
const almacenamiento_service_1 = require("./almacenamiento.service");
const subir_media_query_dto_1 = require("./dto/subir-media-query.dto");
let AlmacenamientoController = class AlmacenamientoController {
    almacenamiento;
    sucursalScope;
    constructor(almacenamiento, sucursalScope) {
        this.almacenamiento = almacenamiento;
        this.sucursalScope = sucursalScope;
    }
    async subirImagen(archivo, usuario, query) {
        if (!archivo?.buffer?.length) {
            throw new common_1.BadRequestException('Falta el archivo «archivo» (multipart)');
        }
        if (!archivo.mimetype?.startsWith('image/')) {
            throw new common_1.BadRequestException('Solo se permiten imágenes');
        }
        const sucursalId = await this.sucursalScope.resolverEscritura(usuario, query.sucursal_id);
        const tipo = this.almacenamiento.parseTipoImagen(query.tipo);
        return this.almacenamiento.subirImagenDesdeSucursal(archivo.buffer, {
            sucursalId,
            tipo,
            entidadId: query.entidad_id,
        });
    }
    async subirVideo(archivo, usuario, query) {
        if (!archivo?.buffer?.length) {
            throw new common_1.BadRequestException('Falta el archivo «archivo» (multipart)');
        }
        if (!archivo.mimetype?.startsWith('video/')) {
            throw new common_1.BadRequestException('Solo se permiten videos');
        }
        const sucursalId = await this.sucursalScope.resolverEscritura(usuario, query.sucursal_id);
        return this.almacenamiento.subirVideoDesdeSucursal(archivo.buffer, {
            sucursalId,
            tipoQuery: query.tipo,
            contentType: archivo.mimetype,
            originalName: archivo.originalname,
        });
    }
    async subirImagenProducto(productoId, archivo, usuario, sucursalIdQuery) {
        return this.subirEntidad('producto', productoId, archivo, usuario, sucursalIdQuery);
    }
    async subirImagenPromocion(promocionId, archivo, usuario, sucursalIdQuery) {
        return this.subirEntidad('promocion', promocionId, archivo, usuario, sucursalIdQuery);
    }
    async subirImagenCombo(comboId, archivo, usuario, sucursalIdQuery) {
        return this.subirEntidad('combo', comboId, archivo, usuario, sucursalIdQuery);
    }
    async subirImagenCategoria(categoriaId, archivo, usuario, sucursalIdQuery) {
        return this.subirEntidad('categoria', categoriaId, archivo, usuario, sucursalIdQuery);
    }
    async subirEntidad(tipo, entidadId, archivo, usuario, sucursalIdQuery) {
        if (!archivo?.buffer?.length) {
            throw new common_1.BadRequestException('Falta el archivo «archivo»');
        }
        const sucursalId = await this.sucursalScope.resolverEscritura(usuario, sucursalIdQuery);
        return this.almacenamiento.subirImagenEntidadCatalogo(archivo.buffer, {
            sucursalId,
            tipo,
            entidadId,
        });
    }
};
exports.AlmacenamientoController = AlmacenamientoController;
__decorate([
    (0, common_1.Post)('imagen'),
    (0, permisos_decorator_1.Permisos)('editar_productos'),
    (0, common_1.UseInterceptors)((0, platform_express_1.FileInterceptor)('archivo', {
        limits: { fileSize: 5 * 1024 * 1024 },
    })),
    __param(0, (0, common_1.UploadedFile)()),
    __param(1, (0, usuario_actual_decorator_1.UsuarioActual)()),
    __param(2, (0, common_1.Query)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object, jwt_payload_1.JwtPayload,
        subir_media_query_dto_1.SubirImagenQueryDto]),
    __metadata("design:returntype", Promise)
], AlmacenamientoController.prototype, "subirImagen", null);
__decorate([
    (0, common_1.Post)('video'),
    (0, permisos_decorator_1.Permisos)('editar_productos'),
    (0, common_1.UseInterceptors)((0, platform_express_1.FileInterceptor)('archivo', {
        limits: { fileSize: 20 * 1024 * 1024 },
    })),
    __param(0, (0, common_1.UploadedFile)()),
    __param(1, (0, usuario_actual_decorator_1.UsuarioActual)()),
    __param(2, (0, common_1.Query)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object, jwt_payload_1.JwtPayload,
        subir_media_query_dto_1.SubirVideoQueryDto]),
    __metadata("design:returntype", Promise)
], AlmacenamientoController.prototype, "subirVideo", null);
__decorate([
    (0, common_1.Post)('productos/:productoId/imagen'),
    (0, permisos_decorator_1.Permisos)('editar_productos'),
    (0, common_1.UseInterceptors)((0, platform_express_1.FileInterceptor)('archivo', {
        limits: { fileSize: 5 * 1024 * 1024 },
    })),
    __param(0, (0, common_1.Param)('productoId', common_1.ParseUUIDPipe)),
    __param(1, (0, common_1.UploadedFile)()),
    __param(2, (0, usuario_actual_decorator_1.UsuarioActual)()),
    __param(3, (0, common_1.Query)('sucursal_id')),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, Object, jwt_payload_1.JwtPayload, String]),
    __metadata("design:returntype", Promise)
], AlmacenamientoController.prototype, "subirImagenProducto", null);
__decorate([
    (0, common_1.Post)('promociones/:promocionId/imagen'),
    (0, permisos_decorator_1.Permisos)('editar_productos'),
    (0, common_1.UseInterceptors)((0, platform_express_1.FileInterceptor)('archivo', {
        limits: { fileSize: 5 * 1024 * 1024 },
    })),
    __param(0, (0, common_1.Param)('promocionId', common_1.ParseUUIDPipe)),
    __param(1, (0, common_1.UploadedFile)()),
    __param(2, (0, usuario_actual_decorator_1.UsuarioActual)()),
    __param(3, (0, common_1.Query)('sucursal_id')),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, Object, jwt_payload_1.JwtPayload, String]),
    __metadata("design:returntype", Promise)
], AlmacenamientoController.prototype, "subirImagenPromocion", null);
__decorate([
    (0, common_1.Post)('combos/:comboId/imagen'),
    (0, permisos_decorator_1.Permisos)('editar_productos'),
    (0, common_1.UseInterceptors)((0, platform_express_1.FileInterceptor)('archivo', {
        limits: { fileSize: 5 * 1024 * 1024 },
    })),
    __param(0, (0, common_1.Param)('comboId', common_1.ParseUUIDPipe)),
    __param(1, (0, common_1.UploadedFile)()),
    __param(2, (0, usuario_actual_decorator_1.UsuarioActual)()),
    __param(3, (0, common_1.Query)('sucursal_id')),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, Object, jwt_payload_1.JwtPayload, String]),
    __metadata("design:returntype", Promise)
], AlmacenamientoController.prototype, "subirImagenCombo", null);
__decorate([
    (0, common_1.Post)('categorias/:categoriaId/imagen'),
    (0, permisos_decorator_1.Permisos)('editar_productos'),
    (0, common_1.UseInterceptors)((0, platform_express_1.FileInterceptor)('archivo', {
        limits: { fileSize: 5 * 1024 * 1024 },
    })),
    __param(0, (0, common_1.Param)('categoriaId', common_1.ParseUUIDPipe)),
    __param(1, (0, common_1.UploadedFile)()),
    __param(2, (0, usuario_actual_decorator_1.UsuarioActual)()),
    __param(3, (0, common_1.Query)('sucursal_id')),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, Object, jwt_payload_1.JwtPayload, String]),
    __metadata("design:returntype", Promise)
], AlmacenamientoController.prototype, "subirImagenCategoria", null);
exports.AlmacenamientoController = AlmacenamientoController = __decorate([
    (0, common_1.Controller)('almacenamiento'),
    (0, common_1.UseGuards)(jwt_auth_guard_1.JwtAuthGuard, usuario_activo_guard_1.UsuarioActivoGuard, suscripcion_activa_guard_1.SuscripcionActivaGuard, rol_guard_1.RolGuard),
    __metadata("design:paramtypes", [almacenamiento_service_1.AlmacenamientoService,
        sucursal_scope_service_1.SucursalScopeService])
], AlmacenamientoController);
//# sourceMappingURL=almacenamiento.controller.js.map