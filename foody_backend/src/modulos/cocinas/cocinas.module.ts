import { Module } from '@nestjs/common';
import { AuthModule } from '../../core/auth/auth.module';
import { AlertasModule } from '../alertas/alertas.module';
import { CocinaTicketsController } from './cocina-tickets.controller';
import { CocinasController } from './cocinas.controller';
import { CocinasService } from './cocinas.service';
import { ImpresorasController } from './impresoras.controller';

@Module({
  imports: [AuthModule, AlertasModule],
  controllers: [
    CocinasController,
    ImpresorasController,
    CocinaTicketsController,
  ],
  providers: [CocinasService],
  exports: [CocinasService],
})
export class CocinasModule {}
