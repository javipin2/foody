import { Controller, Get, Param } from '@nestjs/common';
import { CiudadesService } from './ciudades.service';

@Controller()
export class CiudadesController {
  constructor(private readonly ciudadesService: CiudadesService) {}

  /** Público — app cliente */
  @Get('ciudades')
  listarCiudades() {
    return this.ciudadesService.listarActivas();
  }

  /** Público — restaurantes por ciudad */
  @Get('ciudades/:slug/restaurantes')
  listarRestaurantes(@Param('slug') slug: string) {
    return this.ciudadesService.listarRestaurantesPorSlug(slug);
  }
}
