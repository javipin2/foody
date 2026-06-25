import { Module } from '@nestjs/common';
import { AuthModule } from '../../core/auth/auth.module';
import { AlertasModule } from '../alertas/alertas.module';
import { MesasController } from './mesas.controller';
import { MesasService } from './mesas.service';

@Module({
  imports: [AuthModule, AlertasModule],
  controllers: [MesasController],
  providers: [MesasService],
})
export class MesasModule {}
