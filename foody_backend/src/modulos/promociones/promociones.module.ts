import { Module } from '@nestjs/common';
import { AuthModule } from '../../core/auth/auth.module';
import { PromocionesController } from './promociones.controller';
import { PromocionesService } from './promociones.service';

@Module({
  imports: [AuthModule],
  controllers: [PromocionesController],
  providers: [PromocionesService],
  exports: [PromocionesService],
})
export class PromocionesModule {}
