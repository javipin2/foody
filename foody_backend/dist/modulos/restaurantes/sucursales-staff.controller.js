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
exports.SucursalesStaffController = void 0;
const common_1 = require("@nestjs/common");
const permisos_decorator_1 = require("../../compartido/decoradores/permisos.decorator");
const usuario_actual_decorator_1 = require("../../compartido/decoradores/usuario-actual.decorator");
const jwt_payload_1 = require("../../core/auth/jwt-payload");
const jwt_auth_guard_1 = require("../../core/auth/guards/jwt-auth.guard");
const rol_guard_1 = require("../../core/auth/guards/rol.guard");
const suscripcion_activa_guard_1 = require("../../core/auth/guards/suscripcion-activa.guard");
const usuario_activo_guard_1 = require("../../core/auth/guards/usuario-activo.guard");
const actualizar_horario_dto_1 = require("./dto/actualizar-horario.dto");
const crear_sucursal_dto_1 = require("./dto/crear-sucursal.dto");
const restaurantes_service_1 = require("./restaurantes.service");
let SucursalesStaffController = class SucursalesStaffController {
    restaurantes;
    constructor(restaurantes) {
        this.restaurantes = restaurantes;
    }
    listarMiRestaurante(usuario) {
        return this.restaurantes.listarSucursalesStaff(usuario.restaurante_id, usuario.restaurante_id);
    }
    crear(usuario, dto) {
        return this.restaurantes.crearSucursal(usuario.restaurante_id, usuario.restaurante_id, dto);
    }
    listarHorarios(usuario, sucursalId) {
        return this.restaurantes.listarHorarios(sucursalId, usuario.restaurante_id);
    }
    actualizarHorario(usuario, horarioId, dto) {
        return this.restaurantes.actualizarHorario(horarioId, usuario.restaurante_id, dto);
    }
};
exports.SucursalesStaffController = SucursalesStaffController;
__decorate([
    (0, common_1.Get)('mi-restaurante'),
    (0, permisos_decorator_1.Permisos)('gestionar_sucursales', 'ver_dashboard'),
    __param(0, (0, usuario_actual_decorator_1.UsuarioActual)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [jwt_payload_1.JwtPayload]),
    __metadata("design:returntype", void 0)
], SucursalesStaffController.prototype, "listarMiRestaurante", null);
__decorate([
    (0, common_1.Post)(),
    (0, permisos_decorator_1.Permisos)('gestionar_sucursales'),
    __param(0, (0, usuario_actual_decorator_1.UsuarioActual)()),
    __param(1, (0, common_1.Body)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [jwt_payload_1.JwtPayload, crear_sucursal_dto_1.CrearSucursalDto]),
    __metadata("design:returntype", void 0)
], SucursalesStaffController.prototype, "crear", null);
__decorate([
    (0, common_1.Get)(':sucursalId/horarios'),
    (0, permisos_decorator_1.Permisos)('gestionar_sucursales'),
    __param(0, (0, usuario_actual_decorator_1.UsuarioActual)()),
    __param(1, (0, common_1.Param)('sucursalId')),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [jwt_payload_1.JwtPayload, String]),
    __metadata("design:returntype", void 0)
], SucursalesStaffController.prototype, "listarHorarios", null);
__decorate([
    (0, common_1.Patch)('horarios/:horarioId'),
    (0, permisos_decorator_1.Permisos)('gestionar_sucursales'),
    __param(0, (0, usuario_actual_decorator_1.UsuarioActual)()),
    __param(1, (0, common_1.Param)('horarioId')),
    __param(2, (0, common_1.Body)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [jwt_payload_1.JwtPayload, String, actualizar_horario_dto_1.ActualizarHorarioDto]),
    __metadata("design:returntype", void 0)
], SucursalesStaffController.prototype, "actualizarHorario", null);
exports.SucursalesStaffController = SucursalesStaffController = __decorate([
    (0, common_1.Controller)('sucursales'),
    (0, common_1.UseGuards)(jwt_auth_guard_1.JwtAuthGuard, usuario_activo_guard_1.UsuarioActivoGuard, suscripcion_activa_guard_1.SuscripcionActivaGuard, rol_guard_1.RolGuard),
    __metadata("design:paramtypes", [restaurantes_service_1.RestaurantesService])
], SucursalesStaffController);
//# sourceMappingURL=sucursales-staff.controller.js.map