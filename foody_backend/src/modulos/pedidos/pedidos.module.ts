import { Module } from '@nestjs/common';
import { AuthModule } from '../../core/auth/auth.module';
import { AlertasModule } from '../alertas/alertas.module';
import { AuditoriaModule } from '../auditoria/auditoria.module';
import { CosteoModule } from '../costeo/costeo.module';
import { CatalogoModule } from '../catalogo/catalogo.module';
import { FacturacionModule } from '../facturacion/facturacion.module';
import { ZonasModule } from '../zonas/zonas.module';
import { PromocionesModule } from '../promociones/promociones.module';
import { RealtimeModule } from '../../core/realtime/realtime.module';
import { ImpresionModule } from '../../core/impresion/impresion.module';
import { InventarioModule } from '../inventario/inventario.module';
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
import { PedidosEstadoCommandService } from './pedidos-estado-command.service';
import { PedidosInventarioService } from './pedidos-inventario.service';
import { PedidosDispatchHooksService } from './pedidos-dispatch-hooks.service';
import { NotificacionesModule } from '../notificaciones/notificaciones.module';
import { PedidosQrCronService } from './pedidos-qr-cron.service';

@Module({
  imports: [
    AuthModule,
    AlertasModule,
    AuditoriaModule,
    CosteoModule,
    CatalogoModule,
    FacturacionModule,
    InventarioModule,
    ZonasModule,
    PromocionesModule,
    RealtimeModule,
    ImpresionModule,
    NotificacionesModule,
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
    PedidosEstadoCommandService,
    PedidosInventarioService,
    PedidosDispatchHooksService,
    PedidosQrCronService,
  ],
  exports: [
    PedidosService,
    PedidosCajaAuditoriaService,
    PedidosCuentaMesaService,
    PedidosEstadoService,
    PedidosEstadoCommandService,
    PedidosInventarioService,
    PedidosSoporteService,
    PedidosDispatchHooksService,
  ],
})
export class PedidosModule {}
