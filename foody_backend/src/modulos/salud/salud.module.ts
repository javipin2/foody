import { Module } from '@nestjs/common';
import { RealtimeModule } from '../../core/realtime/realtime.module';
import { ImpresionModule } from '../../core/impresion/impresion.module';
import { HealthController } from './health.controller';
import { SaludController } from './salud.controller';
import { SaludService } from './salud.service';

@Module({
  imports: [RealtimeModule, ImpresionModule],
  controllers: [SaludController, HealthController],
  providers: [SaludService],
})
export class SaludModule {}
