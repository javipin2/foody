import { Module } from '@nestjs/common';
import { AuthModule } from '../../core/auth/auth.module';
import { AlertasModule } from '../alertas/alertas.module';
import { CosteoController } from './costeo.controller';
import { CosteoService } from './costeo.service';

@Module({
  imports: [AuthModule, AlertasModule],
  controllers: [CosteoController],
  providers: [CosteoService],
  exports: [CosteoService],
})
export class CosteoModule {}
