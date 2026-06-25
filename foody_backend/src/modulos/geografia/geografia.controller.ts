import { Controller, Get, Query } from '@nestjs/common';
import { GeografiaService } from './geografia.service';

@Controller('geografia')
export class GeografiaController {
  constructor(private readonly geografia: GeografiaService) {}

  /** Público: autocompletar direcciones vía Photon (OSM). */
  @Get('buscar')
  buscar(
    @Query('q') consulta: string,
    @Query('lat') lat?: string,
    @Query('lng') lng?: string,
    @Query('limite') limite?: string,
  ) {
    return this.geografia.buscarDirecciones(consulta ?? '', {
      lat: lat != null ? Number(lat) : undefined,
      lng: lng != null ? Number(lng) : undefined,
      limite: limite != null ? Number(limite) : undefined,
    });
  }
}
