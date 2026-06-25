import { Module, forwardRef } from '@nestjs/common';
import { AuthModule } from '../../core/auth/auth.module';
import { AlertasModule } from '../alertas/alertas.module';
import { PedidosModule } from '../pedidos/pedidos.module';
import { DomiciliarioIndependienteGuard } from '../../core/auth/guards/domiciliario-independiente.guard';
import { DispatchService } from './dispatch.service';
import { DomiciliariosIndependientesService } from './domiciliarios-independientes.service';
import {
  DomiciliarioPlantaController,
  DomiciliariosIndependientesController,
  DomiciliariosPlantaController,
} from './domiciliarios.controller';
import { DomiciliariosService } from './domiciliarios.service';

@Module({
  imports: [AuthModule, AlertasModule, forwardRef(() => PedidosModule)],
  controllers: [
    DomiciliariosPlantaController,
    DomiciliarioPlantaController,
    DomiciliariosIndependientesController,
  ],
  providers: [
    DomiciliariosService,
    DomiciliariosIndependientesService,
    DispatchService,
    DomiciliarioIndependienteGuard,
  ],
  exports: [DomiciliariosService, DispatchService],
})
export class DomiciliariosModule {}
