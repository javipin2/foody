import type { Cache } from 'cache-manager';
export declare class MenuCacheService {
    private readonly cache;
    constructor(cache: Cache);
    clave(sucursalId: string): string;
    obtener<T>(sucursalId: string): Promise<T | undefined>;
    guardar<T>(sucursalId: string, datos: T): Promise<void>;
    invalidar(sucursalId: string): Promise<void>;
}
