import { Module } from '@nestjs/common';
import { DatabaseModule } from '../database/database.module';
import { NotificacionesModule } from '../../modulos/notificaciones/notificaciones.module';
import { PagosModule } from '../../modulos/pagos/pagos.module';
import { SuscripcionesCronService } from './suscripciones-cron.service';

@Module({
  imports: [DatabaseModule, NotificacionesModule, PagosModule],
  providers: [SuscripcionesCronService],
})
export class SuscripcionesCronModule {}
