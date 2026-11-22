import { Module } from '@nestjs/common';
import { AuthModule } from '../../core/auth/auth.module';
import { AlertasModule } from '../alertas/alertas.module';
import { StockMovimientoModule } from '../inventario/stock-movimiento.module';
import { CosteoController } from './costeo.controller';
import { CosteoService } from './costeo.service';

@Module({
  imports: [AuthModule, AlertasModule, StockMovimientoModule],
  controllers: [CosteoController],
  providers: [CosteoService],
  exports: [CosteoService],
})
export class CosteoModule {}
