import { Module } from '@nestjs/common';
import { AuthModule } from '../../core/auth/auth.module';
import { AlertasModule } from '../alertas/alertas.module';
import { CosteoModule } from '../costeo/costeo.module';
import { CatalogoModule } from '../catalogo/catalogo.module';
import { InventarioController } from './inventario.controller';
import { InventarioService } from './inventario.service';
import { StockMovimientoModule } from './stock-movimiento.module';

@Module({
  imports: [
    AuthModule,
    AlertasModule,
    CosteoModule,
    CatalogoModule,
    StockMovimientoModule,
  ],
  controllers: [InventarioController],
  providers: [InventarioService],
  exports: [InventarioService, StockMovimientoModule],
})
export class InventarioModule {}
