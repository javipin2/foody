import { Module, forwardRef } from '@nestjs/common';
import { AuthModule } from '../../core/auth/auth.module';
import { AlertasModule } from '../alertas/alertas.module';
import { CosteoModule } from '../costeo/costeo.module';
import { FacturacionModule } from '../facturacion/facturacion.module';
import { DomiciliariosModule } from '../domiciliarios/domiciliarios.module';
import { ZonasModule } from '../zonas/zonas.module';
import { PromocionesModule } from '../promociones/promociones.module';
import { RealtimeModule } from '../../core/realtime/realtime.module';
import { ImpresionModule } from '../../core/impresion/impresion.module';
import { PedidosController } from './pedidos.controller';
import { PedidosPublicController } from './pedidos-public.controller';
import { PedidosService } from './pedidos.service';
import { PedidosCajaAuditoriaService } from './pedidos-caja-auditoria.service';
import { PedidosCuentaMesaService } from './pedidos-cuenta-mesa.service';
import { PedidosCrearService } from './pedidos-crear.service';
import { PedidosEstadoService } from './pedidos-estado.service';
import { PedidosPagosService } from './pedidos-pagos.service';
import { PedidosSoporteService } from './pedidos-soporte.service';
import { PedidosItemsService } from './pedidos-items.service';
import { PedidosDescuentoService } from './pedidos-descuento.service';

@Module({
  imports: [
    AuthModule,
    AlertasModule,
    CosteoModule,
    FacturacionModule,
    forwardRef(() => DomiciliariosModule),
    ZonasModule,
    PromocionesModule,
    RealtimeModule,
    ImpresionModule,
  ],
  controllers: [PedidosController, PedidosPublicController],
  providers: [
    PedidosService,
    PedidosCajaAuditoriaService,
    PedidosCuentaMesaService,
    PedidosSoporteService,
    PedidosEstadoService,
    PedidosCrearService,
    PedidosItemsService,
    PedidosDescuentoService,
    PedidosPagosService,
  ],
  exports: [PedidosService, PedidosCajaAuditoriaService],
})
export class PedidosModule {}
