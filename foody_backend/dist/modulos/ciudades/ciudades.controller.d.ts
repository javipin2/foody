import { CiudadesService } from './ciudades.service';
export declare class CiudadesController {
    private readonly ciudadesService;
    constructor(ciudadesService: CiudadesService);
    listarCiudades(): Promise<import("./ciudades.service").CiudadDto[]>;
    listarRestaurantes(slug: string): Promise<import("pg").QueryResultRow[]>;
}
