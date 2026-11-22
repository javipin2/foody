import { Module } from '@nestjs/common';
import { AuthModule } from '../../core/auth/auth.module';
import { AlmacenamientoModule } from '../almacenamiento/almacenamiento.module';
import { PromocionesController } from './promociones.controller';
import { PromocionesCronService } from './promociones-cron.service';
import { PromocionesService } from './promociones.service';

@Module({
  imports: [AuthModule, AlmacenamientoModule],
  controllers: [PromocionesController],
  providers: [PromocionesService, PromocionesCronService],
  exports: [PromocionesService],
})
export class PromocionesModule {}
