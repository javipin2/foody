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
exports.DomiciliariosDocumentosController = void 0;
const common_1 = require("@nestjs/common");
const platform_express_1 = require("@nestjs/platform-express");
const permisos_decorator_1 = require("../../compartido/decoradores/permisos.decorator");
const usuario_actual_decorator_1 = require("../../compartido/decoradores/usuario-actual.decorator");
const domiciliario_cuenta_guard_1 = require("../../core/auth/guards/domiciliario-cuenta.guard");
const jwt_auth_guard_1 = require("../../core/auth/guards/jwt-auth.guard");
const rol_guard_1 = require("../../core/auth/guards/rol.guard");
const jwt_payload_1 = require("../../core/auth/jwt-payload");
const domiciliarios_documentos_service_1 = require("./domiciliarios-documentos.service");
let DomiciliariosDocumentosController = class DomiciliariosDocumentosController {
    documentos;
    constructor(documentos) {
        this.documentos = documentos;
    }
    tipos() {
        return { tipos: this.documentos.listarTiposRequeridos() };
    }
    misDocumentos(usuario) {
        return this.documentos.resumenCarga(usuario.sub);
    }
    subir(tipo, archivo, usuario) {
        if (!archivo?.buffer?.length) {
            throw new common_1.BadRequestException('Debes adjuntar una imagen');
        }
        return this.documentos.subir(usuario.sub, tipo, archivo.buffer);
    }
};
exports.DomiciliariosDocumentosController = DomiciliariosDocumentosController;
__decorate([
    (0, common_1.Get)('documentos/tipos'),
    (0, permisos_decorator_1.Permisos)('domiciliario_independiente'),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", []),
    __metadata("design:returntype", void 0)
], DomiciliariosDocumentosController.prototype, "tipos", null);
__decorate([
    (0, common_1.Get)('documentos'),
    (0, permisos_decorator_1.Permisos)('domiciliario_independiente'),
    __param(0, (0, usuario_actual_decorator_1.UsuarioActual)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [jwt_payload_1.JwtPayload]),
    __metadata("design:returntype", void 0)
], DomiciliariosDocumentosController.prototype, "misDocumentos", null);
__decorate([
    (0, common_1.Post)('documentos/:tipo'),
    (0, permisos_decorator_1.Permisos)('domiciliario_independiente'),
    (0, common_1.UseInterceptors)((0, platform_express_1.FileInterceptor)('archivo', {
        limits: { fileSize: 5 * 1024 * 1024 },
    })),
    __param(0, (0, common_1.Param)('tipo')),
    __param(1, (0, common_1.UploadedFile)()),
    __param(2, (0, usuario_actual_decorator_1.UsuarioActual)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, Object, jwt_payload_1.JwtPayload]),
    __metadata("design:returntype", void 0)
], DomiciliariosDocumentosController.prototype, "subir", null);
exports.DomiciliariosDocumentosController = DomiciliariosDocumentosController = __decorate([
    (0, common_1.Controller)('domiciliarios'),
    (0, common_1.UseGuards)(jwt_auth_guard_1.JwtAuthGuard, domiciliario_cuenta_guard_1.DomiciliarioCuentaGuard, rol_guard_1.RolGuard),
    __metadata("design:paramtypes", [domiciliarios_documentos_service_1.DomiciliariosDocumentosService])
], DomiciliariosDocumentosController);
//# sourceMappingURL=domiciliarios-documentos.controller.js.map