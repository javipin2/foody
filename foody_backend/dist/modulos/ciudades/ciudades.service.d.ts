import { DatabaseService } from '../../core/database/database.service';
export interface CiudadDto {
    id: string;
    nombre: string;
    slug: string;
    activa: boolean;
}
export declare class CiudadesService {
    private readonly database;
    constructor(database: DatabaseService);
    listarActivas(): Promise<CiudadDto[]>;
    listarRestaurantesPorSlug(slug: string): Promise<import("pg").QueryResultRow[]>;
}
