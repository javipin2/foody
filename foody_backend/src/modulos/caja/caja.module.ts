import { Module } from '@nestjs/common';
import { AuthModule } from '../../core/auth/auth.module';
import { RealtimeModule } from '../../core/realtime/realtime.module';
import { AlertasModule } from '../alertas/alertas.module';
import { AuditoriaModule } from '../auditoria/auditoria.module';
import { PedidosModule } from '../pedidos/pedidos.module';
import { CajaController } from './caja.controller';
import { CajaService } from './caja.service';

@Module({
  imports: [AuthModule, AlertasModule, RealtimeModule, AuditoriaModule, PedidosModule],
  controllers: [CajaController],
  providers: [CajaService],
  exports: [CajaService],
})
export class CajaModule {}
