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
exports.AuthController = void 0;
const common_1 = require("@nestjs/common");
const omitir_suscripcion_activa_decorator_1 = require("../../compartido/decoradores/omitir-suscripcion-activa.decorator");
const rate_limit_guard_1 = require("../../compartido/guards/rate-limit.guard");
const auth_service_1 = require("./auth.service");
const fcm_dto_1 = require("./dto/fcm.dto");
const login_dto_1 = require("./dto/login.dto");
const login_google_dto_1 = require("./dto/login-google.dto");
const registro_domiciliario_dto_1 = require("./dto/registro-domiciliario.dto");
const registro_restaurante_dto_1 = require("./dto/registro-restaurante.dto");
const jwt_auth_guard_1 = require("./guards/jwt-auth.guard");
const suscripcion_activa_guard_1 = require("./guards/suscripcion-activa.guard");
const usuario_activo_guard_1 = require("./guards/usuario-activo.guard");
const usuario_actual_decorator_1 = require("../../compartido/decoradores/usuario-actual.decorator");
const jwt_payload_1 = require("./jwt-payload");
let AuthController = class AuthController {
    authService;
    constructor(authService) {
        this.authService = authService;
    }
    login(dto) {
        return this.authService.login(dto.email, dto.contrasena);
    }
    loginDomiciliario(dto) {
        return this.authService.loginDomiciliarioIndependiente(dto.email, dto.contrasena);
    }
    registroDomiciliario(dto) {
        return this.authService.registrarDomiciliarioIndependiente(dto);
    }
    registroRestaurante(dto) {
        return this.authService.registrarRestaurante(dto);
    }
    registroEstado() {
        return this.authService.estadoRegistroRestaurante();
    }
    loginGoogle(dto) {
        return this.authService.loginGoogle(dto.access_token);
    }
    refresh(usuario) {
        return this.authService.refresh(usuario);
    }
    logout(usuario) {
        return this.authService.logout(usuario);
    }
    perfil(usuario) {
        return this.authService.perfil(usuario);
    }
    realtimeCanales(usuario, sucursalId, cocinaId) {
        return this.authService.realtimeCanales(usuario, sucursalId, cocinaId);
    }
    registrarFcm(usuario, dto) {
        return this.authService.registrarFcm(usuario, dto.fcm_token, dto.plataforma);
    }
    desactivarFcm(usuario, dto) {
        return this.authService.desactivarFcm(usuario, dto.fcm_token);
    }
};
exports.AuthController = AuthController;
__decorate([
    (0, common_1.Post)('login'),
    (0, rate_limit_guard_1.RateLimitPublico)(15, 60_000),
    __param(0, (0, common_1.Body)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [login_dto_1.LoginDto]),
    __metadata("design:returntype", void 0)
], AuthController.prototype, "login", null);
__decorate([
    (0, common_1.Post)('login-domiciliario'),
    (0, rate_limit_guard_1.RateLimitPublico)(15, 60_000),
    __param(0, (0, common_1.Body)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [login_dto_1.LoginDto]),
    __metadata("design:returntype", void 0)
], AuthController.prototype, "loginDomiciliario", null);
__decorate([
    (0, common_1.Post)('registro-domiciliario'),
    (0, rate_limit_guard_1.RateLimitPublico)(10, 60_000),
    __param(0, (0, common_1.Body)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [registro_domiciliario_dto_1.RegistroDomiciliarioDto]),
    __metadata("design:returntype", void 0)
], AuthController.prototype, "registroDomiciliario", null);
__decorate([
    (0, common_1.Post)('registro-restaurante'),
    (0, rate_limit_guard_1.RateLimitPublico)(5, 60_000),
    __param(0, (0, common_1.Body)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [registro_restaurante_dto_1.RegistroRestauranteDto]),
    __metadata("design:returntype", void 0)
], AuthController.prototype, "registroRestaurante", null);
__decorate([
    (0, common_1.Get)('registro-estado'),
    (0, rate_limit_guard_1.RateLimitPublico)(60, 60_000),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", []),
    __metadata("design:returntype", void 0)
], AuthController.prototype, "registroEstado", null);
__decorate([
    (0, common_1.Post)('login-google'),
    (0, rate_limit_guard_1.RateLimitPublico)(20, 60_000),
    __param(0, (0, common_1.Body)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [login_google_dto_1.LoginGoogleDto]),
    __metadata("design:returntype", void 0)
], AuthController.prototype, "loginGoogle", null);
__decorate([
    (0, common_1.Post)('refresh'),
    (0, omitir_suscripcion_activa_decorator_1.OmitirSuscripcionActiva)(),
    (0, rate_limit_guard_1.RateLimitPublico)(30, 60_000),
    (0, common_1.UseGuards)(jwt_auth_guard_1.JwtAuthGuard, usuario_activo_guard_1.UsuarioActivoGuard),
    __param(0, (0, usuario_actual_decorator_1.UsuarioActual)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [jwt_payload_1.JwtPayload]),
    __metadata("design:returntype", void 0)
], AuthController.prototype, "refresh", null);
__decorate([
    (0, common_1.Post)('logout'),
    (0, omitir_suscripcion_activa_decorator_1.OmitirSuscripcionActiva)(),
    (0, common_1.UseGuards)(jwt_auth_guard_1.JwtAuthGuard),
    __param(0, (0, usuario_actual_decorator_1.UsuarioActual)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [jwt_payload_1.JwtPayload]),
    __metadata("design:returntype", void 0)
], AuthController.prototype, "logout", null);
__decorate([
    (0, common_1.Get)('perfil'),
    (0, omitir_suscripcion_activa_decorator_1.OmitirSuscripcionActiva)(),
    (0, common_1.UseGuards)(jwt_auth_guard_1.JwtAuthGuard, usuario_activo_guard_1.UsuarioActivoGuard, suscripcion_activa_guard_1.SuscripcionActivaGuard),
    __param(0, (0, usuario_actual_decorator_1.UsuarioActual)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [jwt_payload_1.JwtPayload]),
    __metadata("design:returntype", void 0)
], AuthController.prototype, "perfil", null);
__decorate([
    (0, common_1.Get)('realtime-canales'),
    (0, omitir_suscripcion_activa_decorator_1.OmitirSuscripcionActiva)(),
    (0, common_1.UseGuards)(jwt_auth_guard_1.JwtAuthGuard, usuario_activo_guard_1.UsuarioActivoGuard, suscripcion_activa_guard_1.SuscripcionActivaGuard),
    __param(0, (0, usuario_actual_decorator_1.UsuarioActual)()),
    __param(1, (0, common_1.Query)('sucursal_id')),
    __param(2, (0, common_1.Query)('cocina_id')),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [jwt_payload_1.JwtPayload, String, String]),
    __metadata("design:returntype", void 0)
], AuthController.prototype, "realtimeCanales", null);
__decorate([
    (0, common_1.Post)('registrar-fcm'),
    (0, omitir_suscripcion_activa_decorator_1.OmitirSuscripcionActiva)(),
    (0, common_1.UseGuards)(jwt_auth_guard_1.JwtAuthGuard, usuario_activo_guard_1.UsuarioActivoGuard, suscripcion_activa_guard_1.SuscripcionActivaGuard),
    __param(0, (0, usuario_actual_decorator_1.UsuarioActual)()),
    __param(1, (0, common_1.Body)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [jwt_payload_1.JwtPayload,
        fcm_dto_1.RegistrarFcmDto]),
    __metadata("design:returntype", void 0)
], AuthController.prototype, "registrarFcm", null);
__decorate([
    (0, common_1.Post)('desactivar-fcm'),
    (0, omitir_suscripcion_activa_decorator_1.OmitirSuscripcionActiva)(),
    (0, common_1.UseGuards)(jwt_auth_guard_1.JwtAuthGuard, usuario_activo_guard_1.UsuarioActivoGuard, suscripcion_activa_guard_1.SuscripcionActivaGuard),
    __param(0, (0, usuario_actual_decorator_1.UsuarioActual)()),
    __param(1, (0, common_1.Body)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [jwt_payload_1.JwtPayload,
        fcm_dto_1.DesactivarFcmDto]),
    __metadata("design:returntype", void 0)
], AuthController.prototype, "desactivarFcm", null);
exports.AuthController = AuthController = __decorate([
    (0, common_1.Controller)('auth'),
    __metadata("design:paramtypes", [auth_service_1.AuthService])
], AuthController);
//# sourceMappingURL=auth.controller.js.map