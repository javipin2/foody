import { Controller, Get, Param } from '@nestjs/common';
import { RateLimitPublico } from '../../compartido/guards/rate-limit.guard';
import { CiudadesService } from './ciudades.service';

@Controller()
export class CiudadesController {
  constructor(private readonly ciudadesService: CiudadesService) {}

  /** Público — app cliente */
  @Get('ciudades')
  @RateLimitPublico(120, 60_000)
  listarCiudades() {
    return this.ciudadesService.listarActivas();
  }

  /** Público — restaurantes por ciudad */
  @Get('ciudades/:slug/restaurantes')
  @RateLimitPublico(90, 60_000)
  listarRestaurantes(@Param('slug') slug: string) {
    return this.ciudadesService.listarRestaurantesPorSlug(slug);
  }
}
