import { Module } from '@nestjs/common';
import { AuthModule } from '../../core/auth/auth.module';
import { RestaurantesController } from './restaurantes.controller';
import { SucursalesStaffController } from './sucursales-staff.controller';
import { RestaurantesService } from './restaurantes.service';

@Module({
  imports: [AuthModule],
  controllers: [RestaurantesController, SucursalesStaffController],
  providers: [RestaurantesService],
  exports: [RestaurantesService],
})
export class RestaurantesModule {}
