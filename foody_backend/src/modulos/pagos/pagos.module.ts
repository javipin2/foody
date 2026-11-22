import { Module } from '@nestjs/common';
import { AuthModule } from '../../core/auth/auth.module';
import { DatabaseModule } from '../../core/database/database.module';
import { PagosController } from './pagos.controller';
import { PagosRecurrentesService } from './pagos-recurrentes.service';
import { PagosService } from './pagos.service';
import { WompiService } from './wompi.service';

@Module({
  imports: [DatabaseModule, AuthModule],
  controllers: [PagosController],
  providers: [PagosService, PagosRecurrentesService, WompiService],
  exports: [PagosService, PagosRecurrentesService, WompiService],
})
export class PagosModule {}
