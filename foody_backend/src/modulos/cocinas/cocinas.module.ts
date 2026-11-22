import { Module, forwardRef } from '@nestjs/common';
import { AuthModule } from '../../core/auth/auth.module';
import { AlertasModule } from '../alertas/alertas.module';
import { DomiciliariosModule } from '../domiciliarios/domiciliarios.module';
import { PedidosModule } from '../pedidos/pedidos.module';
import { CocinaTicketsController } from './cocina-tickets.controller';
import { CocinasController } from './cocinas.controller';
import { CocinasService } from './cocinas.service';
import { ImpresorasController } from './impresoras.controller';

@Module({
  imports: [AuthModule, AlertasModule, DomiciliariosModule, forwardRef(() => PedidosModule)],
  controllers: [
    CocinasController,
    ImpresorasController,
    CocinaTicketsController,
  ],
  providers: [CocinasService],
  exports: [CocinasService],
})
export class CocinasModule {}
