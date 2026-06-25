import { Injectable } from '@nestjs/common';
import { DatabaseService } from '../../core/database/database.service';

export interface CiudadDto {
  id: string;
  nombre: string;
  slug: string;
  activa: boolean;
}

@Injectable()
export class CiudadesService {
  constructor(private readonly database: DatabaseService) {}

  async listarActivas(): Promise<CiudadDto[]> {
    return this.database.consultar<CiudadDto>(
      `SELECT id, nombre, slug, activa
       FROM ciudades
       WHERE activa = true
       ORDER BY nombre ASC`,
    );
  }

  async listarRestaurantesPorSlug(slug: string) {
    return this.database.consultar(
      `SELECT r.id, r.nombre, r.descripcion, r.logo_url, r.banner_url, r.activo
       FROM restaurantes r
       INNER JOIN ciudades c ON c.id = r.ciudad_id
       WHERE c.slug = $1 AND c.activa = true AND r.activo = true
       ORDER BY r.nombre ASC`,
      [slug],
    );
  }
}
