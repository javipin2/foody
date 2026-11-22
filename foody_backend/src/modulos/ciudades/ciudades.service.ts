import { CACHE_MANAGER } from '@nestjs/cache-manager';
import { Inject, Injectable } from '@nestjs/common';
import type { Cache } from 'cache-manager';
import { DatabaseService } from '../../core/database/database.service';

export interface CiudadDto {
  id: string;
  nombre: string;
  slug: string;
  activa: boolean;
}

const TTL_CIUDADES_MS = 3 * 60 * 1000;
const CLAVE_ACTIVAS = 'ciudades:activas';

@Injectable()
export class CiudadesService {
  constructor(
    private readonly database: DatabaseService,
    @Inject(CACHE_MANAGER) private readonly cache: Cache,
  ) {}

  async listarActivas(): Promise<CiudadDto[]> {
    const hit = await this.cache.get<CiudadDto[]>(CLAVE_ACTIVAS);
    if (hit) return hit;
    const data = await this.database.consultar<CiudadDto>(
      `SELECT id, nombre, slug, activa
       FROM ciudades
       WHERE activa = true
       ORDER BY nombre ASC`,
    );
    await this.cache.set(CLAVE_ACTIVAS, data, TTL_CIUDADES_MS);
    return data;
  }

  async listarRestaurantesPorSlug(slug: string) {
    const clave = `ciudades:rest:${slug}`;
    const hit = await this.cache.get<unknown[]>(clave);
    if (hit) return hit;
    const data = await this.database.consultar(
      `SELECT r.id, r.nombre, r.descripcion, r.logo_url, r.banner_url, r.activo
       FROM restaurantes r
       INNER JOIN ciudades c ON c.id = r.ciudad_id
       WHERE c.slug = $1 AND c.activa = true AND r.activo = true
       ORDER BY r.nombre ASC`,
      [slug],
    );
    await this.cache.set(clave, data, TTL_CIUDADES_MS);
    return data;
  }

  /** Tras PATCH super ciudad / alta restaurante. */
  async invalidarCache(): Promise<void> {
    await this.cache.del(CLAVE_ACTIVAS);
    // ponytail: no enumeramos slugs; TTL 3 min cubre listados por ciudad.
  }
}
