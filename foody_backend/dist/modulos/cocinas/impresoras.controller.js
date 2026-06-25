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
exports.ImpresorasController = void 0;
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
const cocinas_service_1 = require("./cocinas.service");
const cocina_dto_1 = require("./dto/cocina.dto");
let ImpresorasController = class ImpresorasController {
    cocinas;
    constructor(cocinas) {
        this.cocinas = cocinas;
    }
    listar(sucursalId, cocinaId) {
        return this.cocinas.listarImpresoras(sucursalId, cocinaId);
    }
    crear(dto) {
        return this.cocinas.crearImpresora(dto);
    }
    actualizar(id, dto, usuario) {
        return this.cocinas.actualizarImpresora(id, usuario.sucursal_id, dto);
    }
    eliminar(id, usuario) {
        return this.cocinas.eliminarImpresora(id, usuario.sucursal_id);
    }
};
exports.ImpresorasController = ImpresorasController;
__decorate([
    (0, common_1.Get)(':sucursal_id'),
    (0, permisos_decorator_1.Permisos)('editar_productos'),
    __param(0, (0, common_1.Param)('sucursal_id')),
    __param(1, (0, common_1.Query)('cocina_id')),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, String]),
    __metadata("design:returntype", void 0)
], ImpresorasController.prototype, "listar", null);
__decorate([
    (0, common_1.Post)(),
    (0, permisos_decorator_1.Permisos)('editar_productos'),
    __param(0, (0, common_1.Body)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [cocina_dto_1.CrearImpresoraDto]),
    __metadata("design:returntype", void 0)
], ImpresorasController.prototype, "crear", null);
__decorate([
    (0, common_1.Patch)(':id'),
    (0, permisos_decorator_1.Permisos)('editar_productos'),
    __param(0, (0, common_1.Param)('id')),
    __param(1, (0, common_1.Body)()),
    __param(2, (0, usuario_actual_decorator_1.UsuarioActual)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, cocina_dto_1.ActualizarImpresoraDto,
        jwt_payload_1.JwtPayload]),
    __metadata("design:returntype", void 0)
], ImpresorasController.prototype, "actualizar", null);
__decorate([
    (0, common_1.Delete)(':id'),
    (0, permisos_decorator_1.Permisos)('editar_productos'),
    __param(0, (0, common_1.Param)('id')),
    __param(1, (0, usuario_actual_decorator_1.UsuarioActual)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, jwt_payload_1.JwtPayload]),
    __metadata("design:returntype", void 0)
], ImpresorasController.prototype, "eliminar", null);
exports.ImpresorasController = ImpresorasController = __decorate([
    (0, common_1.Controller)('impresoras'),
    (0, common_1.UseGuards)(jwt_auth_guard_1.JwtAuthGuard, usuario_activo_guard_1.UsuarioActivoGuard, suscripcion_activa_guard_1.SuscripcionActivaGuard, plan_features_guard_1.PlanFeaturesGuard, rol_guard_1.RolGuard),
    (0, requiere_modulo_decorator_1.RequiereModulo)('cocina'),
    __metadata("design:paramtypes", [cocinas_service_1.CocinasService])
], ImpresorasController);
//# sourceMappingURL=impresoras.controller.js.map