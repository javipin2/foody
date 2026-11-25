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
exports.NotificacionesController = void 0;
const common_1 = require("@nestjs/common");
const permisos_decorator_1 = require("../../compartido/decoradores/permisos.decorator");
const usuario_actual_decorator_1 = require("../../compartido/decoradores/usuario-actual.decorator");
const jwt_payload_1 = require("../../core/auth/jwt-payload");
const jwt_auth_guard_1 = require("../../core/auth/guards/jwt-auth.guard");
const rol_guard_1 = require("../../core/auth/guards/rol.guard");
const suscripcion_activa_guard_1 = require("../../core/auth/guards/suscripcion-activa.guard");
const super_admin_guard_1 = require("../../core/auth/guards/super-admin.guard");
const usuario_activo_guard_1 = require("../../core/auth/guards/usuario-activo.guard");
const notificaciones_service_1 = require("./notificaciones.service");
let NotificacionesController = class NotificacionesController {
    notificaciones;
    constructor(notificaciones) {
        this.notificaciones = notificaciones;
    }
    diagnostico() {
        return this.notificaciones.diagnostico();
    }
    procesarCola() {
        return this.notificaciones.procesarPendientes(100);
    }
    prueba(usuario) {
        return this.notificaciones.enviarPrueba(usuario);
    }
    pruebaWeb(usuario) {
        return this.notificaciones.enviarPruebaWeb({
            usuario_id: usuario.sub,
            rol: usuario.rol,
            todos_web: false,
        });
    }
};
exports.NotificacionesController = NotificacionesController;
__decorate([
    (0, common_1.Get)('diagnostico'),
    (0, common_1.UseGuards)(jwt_auth_guard_1.JwtAuthGuard, usuario_activo_guard_1.UsuarioActivoGuard, suscripcion_activa_guard_1.SuscripcionActivaGuard, rol_guard_1.RolGuard),
    (0, permisos_decorator_1.Permisos)('ver_dashboard'),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", []),
    __metadata("design:returntype", void 0)
], NotificacionesController.prototype, "diagnostico", null);
__decorate([
    (0, common_1.Post)('procesar-cola'),
    (0, common_1.UseGuards)(jwt_auth_guard_1.JwtAuthGuard, usuario_activo_guard_1.UsuarioActivoGuard, super_admin_guard_1.SuperAdminGuard),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", []),
    __metadata("design:returntype", void 0)
], NotificacionesController.prototype, "procesarCola", null);
__decorate([
    (0, common_1.Post)('prueba'),
    (0, common_1.UseGuards)(jwt_auth_guard_1.JwtAuthGuard, usuario_activo_guard_1.UsuarioActivoGuard, suscripcion_activa_guard_1.SuscripcionActivaGuard),
    __param(0, (0, usuario_actual_decorator_1.UsuarioActual)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [jwt_payload_1.JwtPayload]),
    __metadata("design:returntype", void 0)
], NotificacionesController.prototype, "prueba", null);
__decorate([
    (0, common_1.Post)('prueba-web'),
    (0, common_1.UseGuards)(jwt_auth_guard_1.JwtAuthGuard, usuario_activo_guard_1.UsuarioActivoGuard, suscripcion_activa_guard_1.SuscripcionActivaGuard, rol_guard_1.RolGuard),
    (0, permisos_decorator_1.Permisos)('ver_dashboard'),
    __param(0, (0, usuario_actual_decorator_1.UsuarioActual)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [jwt_payload_1.JwtPayload]),
    __metadata("design:returntype", void 0)
], NotificacionesController.prototype, "pruebaWeb", null);
exports.NotificacionesController = NotificacionesController = __decorate([
    (0, common_1.Controller)('notificaciones'),
    __metadata("design:paramtypes", [notificaciones_service_1.NotificacionesService])
], NotificacionesController);
//# sourceMappingURL=notificaciones.controller.js.map