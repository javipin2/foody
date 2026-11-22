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
exports.CocinasController = void 0;
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
const cocinas_service_1 = require("./cocinas.service");
const cocina_dto_1 = require("./dto/cocina.dto");
let CocinasController = class CocinasController {
    cocinas;
    sucursalScope;
    constructor(cocinas, sucursalScope) {
        this.cocinas = cocinas;
        this.sucursalScope = sucursalScope;
    }
    async listar(usuario, sucursalId) {
        const id = await this.sucursalScope.resolverLecturaOperativa(usuario, sucursalId);
        return this.cocinas.listarCocinas(id);
    }
    async crear(usuario, dto) {
        await this.sucursalScope.validarEscritura(usuario, dto.sucursal_id);
        return this.cocinas.crearCocina(dto);
    }
    async actualizar(id, dto, usuario) {
        const sid = await this.sucursalScope.resolverEscritura(usuario);
        return this.cocinas.actualizarCocina(id, sid, dto);
    }
    async eliminar(id, usuario) {
        const sid = await this.sucursalScope.resolverEscritura(usuario);
        return this.cocinas.eliminarCocina(id, sid);
    }
};
exports.CocinasController = CocinasController;
__decorate([
    (0, common_1.Get)(':sucursal_id'),
    (0, permisos_decorator_1.Permisos)('editar_productos'),
    __param(0, (0, usuario_actual_decorator_1.UsuarioActual)()),
    __param(1, (0, common_1.Param)('sucursal_id')),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [jwt_payload_1.JwtPayload, String]),
    __metadata("design:returntype", Promise)
], CocinasController.prototype, "listar", null);
__decorate([
    (0, common_1.Post)(),
    (0, permisos_decorator_1.Permisos)('editar_productos'),
    __param(0, (0, usuario_actual_decorator_1.UsuarioActual)()),
    __param(1, (0, common_1.Body)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [jwt_payload_1.JwtPayload,
        cocina_dto_1.CrearCocinaDto]),
    __metadata("design:returntype", Promise)
], CocinasController.prototype, "crear", null);
__decorate([
    (0, common_1.Patch)(':id'),
    (0, permisos_decorator_1.Permisos)('editar_productos'),
    __param(0, (0, common_1.Param)('id', common_1.ParseUUIDPipe)),
    __param(1, (0, common_1.Body)()),
    __param(2, (0, usuario_actual_decorator_1.UsuarioActual)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, cocina_dto_1.ActualizarCocinaDto,
        jwt_payload_1.JwtPayload]),
    __metadata("design:returntype", Promise)
], CocinasController.prototype, "actualizar", null);
__decorate([
    (0, common_1.Delete)(':id'),
    (0, permisos_decorator_1.Permisos)('editar_productos'),
    __param(0, (0, common_1.Param)('id', common_1.ParseUUIDPipe)),
    __param(1, (0, usuario_actual_decorator_1.UsuarioActual)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, jwt_payload_1.JwtPayload]),
    __metadata("design:returntype", Promise)
], CocinasController.prototype, "eliminar", null);
exports.CocinasController = CocinasController = __decorate([
    (0, common_1.Controller)('cocinas'),
    (0, common_1.UseGuards)(jwt_auth_guard_1.JwtAuthGuard, usuario_activo_guard_1.UsuarioActivoGuard, suscripcion_activa_guard_1.SuscripcionActivaGuard, plan_features_guard_1.PlanFeaturesGuard, rol_guard_1.RolGuard),
    (0, requiere_modulo_decorator_1.RequiereModulo)('cocina'),
    __metadata("design:paramtypes", [cocinas_service_1.CocinasService,
        sucursal_scope_service_1.SucursalScopeService])
], CocinasController);
//# sourceMappingURL=cocinas.controller.js.map