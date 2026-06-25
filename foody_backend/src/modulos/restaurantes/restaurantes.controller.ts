import { Controller, Get, Param } from '@nestjs/common';
import { RestaurantesService } from './restaurantes.service';

@Controller('restaurantes')
export class RestaurantesController {
  constructor(private readonly restaurantesService: RestaurantesService) {}

  /** Público — sucursales de un restaurante */
  @Get(':id/sucursales')
  listarSucursales(@Param('id') id: string) {
    return this.restaurantesService.listarSucursales(id);
  }
}
