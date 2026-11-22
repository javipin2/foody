import { Module } from '@nestjs/common';
import { StockMovimientoService } from './stock-movimiento.service';

/** Escritura única stock + movimiento (sin deps Costeo/Inventario → evita ciclos Nest). */
@Module({
  providers: [StockMovimientoService],
  exports: [StockMovimientoService],
})
export class StockMovimientoModule {}
