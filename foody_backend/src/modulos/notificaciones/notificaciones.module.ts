import { Global, Module } from '@nestjs/common';
import { AuthModule } from '../../core/auth/auth.module';
import { FcmService } from './fcm.service';
import { NotificacionesController } from './notificaciones.controller';
import { NotificacionesCronService } from './notificaciones-cron.service';
import { NotificacionesService } from './notificaciones.service';

@Global()
@Module({
  imports: [AuthModule],
  controllers: [NotificacionesController],
  providers: [FcmService, NotificacionesService, NotificacionesCronService],
  exports: [NotificacionesService, FcmService],
})
export class NotificacionesModule {}
