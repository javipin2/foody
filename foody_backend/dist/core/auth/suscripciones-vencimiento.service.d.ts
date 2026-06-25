import { DatabaseService } from '../database/database.service';
export declare class SuscripcionesVencimientoService {
    private readonly database;
    private readonly logger;
    constructor(database: DatabaseService);
    asegurarEstadoVigente(restauranteId: string): Promise<string>;
}
