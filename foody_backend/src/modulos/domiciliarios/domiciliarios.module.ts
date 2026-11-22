import { Module } from '@nestjs/common';
import { AuthModule } from '../../core/auth/auth.module';
import { RealtimeModule } from '../../core/realtime/realtime.module';
import { AlertasModule } from '../alertas/alertas.module';
import { AlmacenamientoModule } from '../almacenamiento/almacenamiento.module';
import { PedidosModule } from '../pedidos/pedidos.module';
import { DomiciliarioCuentaGuard } from '../../core/auth/guards/domiciliario-cuenta.guard';
import { DomiciliarioIndependienteGuard } from '../../core/auth/guards/domiciliario-independiente.guard';
import { DispatchService } from './dispatch.service';
import { DomiciliariosDocumentosController } from './domiciliarios-documentos.controller';
import { DomiciliariosDocumentosService } from './domiciliarios-documentos.service';
import { DomiciliariosIndependientesService } from './domiciliarios-independientes.service';
import {
  DomiciliarioPlantaController,
  DomiciliariosIndependientesController,
  DomiciliariosPlantaController,
} from './domiciliarios.controller';
import { DomiciliariosService } from './domiciliarios.service';

@Module({
  imports: [
    AuthModule,
    AlertasModule,
    RealtimeModule,
    AlmacenamientoModule,
    PedidosModule,
  ],
  controllers: [
    DomiciliariosPlantaController,
    DomiciliarioPlantaController,
    DomiciliariosIndependientesController,
    DomiciliariosDocumentosController,
  ],
  providers: [
    DomiciliariosService,
    DomiciliariosIndependientesService,
    DomiciliariosDocumentosService,
    DispatchService,
    DomiciliarioIndependienteGuard,
    DomiciliarioCuentaGuard,
  ],
  exports: [DomiciliariosService, DispatchService, DomiciliariosDocumentosService],
})
export class DomiciliariosModule {}
