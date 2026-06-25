"use strict";
var __decorate = (this && this.__decorate) || function (decorators, target, key, desc) {
    var c = arguments.length, r = c < 3 ? target : desc === null ? desc = Object.getOwnPropertyDescriptor(target, key) : desc, d;
    if (typeof Reflect === "object" && typeof Reflect.decorate === "function") r = Reflect.decorate(decorators, target, key, desc);
    else for (var i = decorators.length - 1; i >= 0; i--) if (d = decorators[i]) r = (c < 3 ? d(r) : c > 3 ? d(target, key, r) : d(target, key)) || r;
    return c > 3 && r && Object.defineProperty(target, key, r), r;
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.AuthModule = void 0;
const common_1 = require("@nestjs/common");
const config_1 = require("@nestjs/config");
const jwt_1 = require("@nestjs/jwt");
const passport_1 = require("@nestjs/passport");
const database_module_1 = require("../database/database.module");
const onboarding_module_1 = require("../onboarding/onboarding.module");
const auth_controller_1 = require("./auth.controller");
const auth_service_1 = require("./auth.service");
const jwt_strategy_1 = require("./jwt.strategy");
const jwt_auth_guard_1 = require("./guards/jwt-auth.guard");
const usuario_activo_guard_1 = require("./guards/usuario-activo.guard");
const suscripcion_activa_guard_1 = require("./guards/suscripcion-activa.guard");
const rol_guard_1 = require("./guards/rol.guard");
const super_admin_guard_1 = require("./guards/super-admin.guard");
const sucursal_scope_service_1 = require("./sucursal-scope.service");
const plan_features_service_1 = require("./plan-features.service");
const plan_features_guard_1 = require("./guards/plan-features.guard");
const suscripciones_vencimiento_service_1 = require("./suscripciones-vencimiento.service");
const supabase_auth_service_1 = require("./supabase-auth.service");
let AuthModule = class AuthModule {
};
exports.AuthModule = AuthModule;
exports.AuthModule = AuthModule = __decorate([
    (0, common_1.Module)({
        imports: [
            database_module_1.DatabaseModule,
            onboarding_module_1.OnboardingModule,
            passport_1.PassportModule.register({ defaultStrategy: 'jwt' }),
            jwt_1.JwtModule.registerAsync({
                imports: [config_1.ConfigModule],
                inject: [config_1.ConfigService],
                useFactory: (config) => ({
                    secret: config.get('JWT_SECRET') ?? 'foody_jwt_secret_cambiar',
                    signOptions: {
                        expiresIn: (config.get('JWT_EXPIRACION') ?? '7d'),
                    },
                }),
            }),
        ],
        controllers: [auth_controller_1.AuthController],
        providers: [
            auth_service_1.AuthService,
            supabase_auth_service_1.SupabaseAuthService,
            jwt_strategy_1.JwtStrategy,
            jwt_auth_guard_1.JwtAuthGuard,
            usuario_activo_guard_1.UsuarioActivoGuard,
            suscripcion_activa_guard_1.SuscripcionActivaGuard,
            rol_guard_1.RolGuard,
            super_admin_guard_1.SuperAdminGuard,
            sucursal_scope_service_1.SucursalScopeService,
            plan_features_service_1.PlanFeaturesService,
            plan_features_guard_1.PlanFeaturesGuard,
            suscripciones_vencimiento_service_1.SuscripcionesVencimientoService,
        ],
        exports: [
            auth_service_1.AuthService,
            supabase_auth_service_1.SupabaseAuthService,
            jwt_1.JwtModule,
            jwt_auth_guard_1.JwtAuthGuard,
            usuario_activo_guard_1.UsuarioActivoGuard,
            suscripcion_activa_guard_1.SuscripcionActivaGuard,
            plan_features_guard_1.PlanFeaturesGuard,
            plan_features_service_1.PlanFeaturesService,
            suscripciones_vencimiento_service_1.SuscripcionesVencimientoService,
            rol_guard_1.RolGuard,
            super_admin_guard_1.SuperAdminGuard,
            sucursal_scope_service_1.SucursalScopeService,
        ],
    })
], AuthModule);
//# sourceMappingURL=auth.module.js.map