import { Module } from '@nestjs/common';
import { AuthModule } from '../../core/auth/auth.module';
import { RealtimeModule } from '../../core/realtime/realtime.module';
import { AlertasController } from './alertas.controller';
import { AlertasRiesgoService } from './alertas-riesgo.service';
import { AlertasService } from './alertas.service';

@Module({
  imports: [AuthModule, RealtimeModule],
  controllers: [AlertasController],
  providers: [AlertasService, AlertasRiesgoService],
  exports: [AlertasService, AlertasRiesgoService],
})
export class AlertasModule {}
