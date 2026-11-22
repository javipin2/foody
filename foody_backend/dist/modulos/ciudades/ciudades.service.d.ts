import type { Cache } from 'cache-manager';
import { DatabaseService } from '../../core/database/database.service';
export interface CiudadDto {
    id: string;
    nombre: string;
    slug: string;
    activa: boolean;
}
export declare class CiudadesService {
    private readonly database;
    private readonly cache;
    constructor(database: DatabaseService, cache: Cache);
    listarActivas(): Promise<CiudadDto[]>;
    listarRestaurantesPorSlug(slug: string): Promise<unknown[]>;
    invalidarCache(): Promise<void>;
}
