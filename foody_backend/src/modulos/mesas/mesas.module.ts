import { Module } from '@nestjs/common';
import { AuthModule } from '../../core/auth/auth.module';
import { AlertasModule } from '../alertas/alertas.module';
import { AuditoriaModule } from '../auditoria/auditoria.module';
import { RealtimeModule } from '../../core/realtime/realtime.module';
import { PedidosModule } from '../pedidos/pedidos.module';
import { MesasController } from './mesas.controller';
import { MesasService } from './mesas.service';
import { MesasReservaCronService } from './mesas-reserva-cron.service';

@Module({
  imports: [AuthModule, AlertasModule, AuditoriaModule, PedidosModule, RealtimeModule],
  controllers: [MesasController],
  providers: [MesasService, MesasReservaCronService],
})
export class MesasModule {}
