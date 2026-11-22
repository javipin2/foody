import { Controller, Get, Query } from '@nestjs/common';
import { RateLimitPublico } from '../../compartido/guards/rate-limit.guard';
import { BuscarGeografiaDto } from './dto/buscar-geografia.dto';
import { GeografiaService } from './geografia.service';

@Controller('geografia')
export class GeografiaController {
  constructor(private readonly geografia: GeografiaService) {}

  /** Público: autocompletar direcciones vía Photon (OSM). */
  @Get('buscar')
  @RateLimitPublico(40, 60_000)
  buscar(@Query() dto: BuscarGeografiaDto) {
    return this.geografia.buscarDirecciones(dto.q ?? '', {
      lat: dto.lat,
      lng: dto.lng,
      limite: dto.limite,
    });
  }
}
