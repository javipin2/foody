import { Module } from '@nestjs/common';
import { AuthModule } from '../../core/auth/auth.module';
import { AuditoriaModule } from '../auditoria/auditoria.module';
import { FacturacionController } from './facturacion.controller';
import { FacturacionService } from './facturacion.service';

@Module({
  imports: [AuthModule, AuditoriaModule],
  controllers: [FacturacionController],
  providers: [FacturacionService],
  exports: [FacturacionService],
})
export class FacturacionModule {}
