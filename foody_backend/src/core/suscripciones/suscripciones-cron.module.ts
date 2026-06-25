import { Module } from '@nestjs/common';
import { DatabaseModule } from '../database/database.module';
import { NotificacionesModule } from '../../modulos/notificaciones/notificaciones.module';
import { SuscripcionesCronService } from './suscripciones-cron.service';

@Module({
  imports: [DatabaseModule, NotificacionesModule],
  providers: [SuscripcionesCronService],
})
export class SuscripcionesCronModule {}
