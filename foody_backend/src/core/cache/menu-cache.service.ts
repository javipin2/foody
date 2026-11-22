import { CACHE_MANAGER } from '@nestjs/cache-manager';
import { Inject, Injectable } from '@nestjs/common';
import type { Cache } from 'cache-manager';

const PREFIJO = 'menu:';
const TTL_MS = 15 * 60 * 1000; // 15 minutos (reduce thrash por expiración)

@Injectable()
export class MenuCacheService {
  constructor(@Inject(CACHE_MANAGER) private readonly cache: Cache) {}

  clave(sucursalId: string): string {
    return `${PREFIJO}${sucursalId}`;
  }

  async obtener<T>(sucursalId: string): Promise<T | undefined> {
    return this.cache.get<T>(this.clave(sucursalId));
  }

  async guardar<T>(sucursalId: string, datos: T): Promise<void> {
    await this.cache.set(this.clave(sucursalId), datos, TTL_MS);
  }

  async invalidar(sucursalId: string): Promise<void> {
    await this.cache.del(this.clave(sucursalId));
  }
}
