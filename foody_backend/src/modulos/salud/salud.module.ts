import { Module } from '@nestjs/common';
import { HealthController } from './health.controller';
import { SaludController } from './salud.controller';
import { SaludService } from './salud.service';

@Module({
  controllers: [SaludController, HealthController],
  providers: [SaludService],
})
export class SaludModule {}
