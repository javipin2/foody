import { Module } from '@nestjs/common';
import { ConfigModule, ConfigService } from '@nestjs/config';
import { JwtModule } from '@nestjs/jwt';
import { PassportModule } from '@nestjs/passport';
import { DatabaseModule } from '../database/database.module';
import { OnboardingModule } from '../onboarding/onboarding.module';
import { AuthController } from './auth.controller';
import { AuthService } from './auth.service';
import { JwtStrategy } from './jwt.strategy';
import { JwtAuthGuard } from './guards/jwt-auth.guard';
import { UsuarioActivoGuard } from './guards/usuario-activo.guard';
import { SuscripcionActivaGuard } from './guards/suscripcion-activa.guard';
import { RolGuard } from './guards/rol.guard';
import { SuperAdminGuard } from './guards/super-admin.guard';
import { SucursalScopeService } from './sucursal-scope.service';
import { PlanFeaturesService } from './plan-features.service';
import { PlanFeaturesGuard } from './guards/plan-features.guard';
import { SuscripcionesVencimientoService } from './suscripciones-vencimiento.service';
import { SupabaseAuthService } from './supabase-auth.service';

@Module({
  imports: [
    DatabaseModule,
    OnboardingModule,
    PassportModule.register({ defaultStrategy: 'jwt' }),
    JwtModule.registerAsync({
      imports: [ConfigModule],
      inject: [ConfigService],
      useFactory: (config: ConfigService) => ({
        secret: config.get<string>('JWT_SECRET') ?? 'foody_jwt_secret_cambiar',
        signOptions: {
          expiresIn: (config.get<string>('JWT_EXPIRACION') ?? '7d') as '7d',
        },
      }),
    }),
  ],
  controllers: [AuthController],
  providers: [
    AuthService,
    SupabaseAuthService,
    JwtStrategy,
    JwtAuthGuard,
    UsuarioActivoGuard,
    SuscripcionActivaGuard,
    RolGuard,
    SuperAdminGuard,
    SucursalScopeService,
    PlanFeaturesService,
    PlanFeaturesGuard,
    SuscripcionesVencimientoService,
  ],
  exports: [
    AuthService,
    SupabaseAuthService,
    JwtModule,
    JwtAuthGuard,
    UsuarioActivoGuard,
    SuscripcionActivaGuard,
    PlanFeaturesGuard,
    PlanFeaturesService,
    SuscripcionesVencimientoService,
    RolGuard,
    SuperAdminGuard,
    SucursalScopeService,
  ],
})
export class AuthModule {}
