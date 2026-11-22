import { Global, Module } from '@nestjs/common';
import { CajaMovimientosService } from './caja-movimientos.service';

/** Escritura centralizada de `movimientos_caja` (A-02). */
@Global()
@Module({
  providers: [CajaMovimientosService],
  exports: [CajaMovimientosService],
})
export class CajaMovimientosModule {}
