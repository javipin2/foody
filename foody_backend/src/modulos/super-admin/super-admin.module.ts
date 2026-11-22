import { Module } from '@nestjs/common';
import { AuthModule } from '../../core/auth/auth.module';
import { OnboardingModule } from '../../core/onboarding/onboarding.module';
import { NotificacionesModule } from '../notificaciones/notificaciones.module';
import { SuperAdminController } from './super-admin.controller';
import { SuperAdminService } from './super-admin.service';

@Module({
  imports: [AuthModule, OnboardingModule, NotificacionesModule],
  controllers: [SuperAdminController],
  providers: [SuperAdminService],
})
export class SuperAdminModule {}
