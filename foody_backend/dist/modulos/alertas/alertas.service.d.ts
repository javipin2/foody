import { DatabaseService } from '../../core/database/database.service';
export declare class AlertasService {
    private readonly database;
    constructor(database: DatabaseService);
    listar(sucursalId: string, soloPendientes?: boolean): Promise<import("pg").QueryResultRow[]>;
    revisar(alertaId: string, sucursalId: string, usuarioId: string): Promise<{
        id: string;
        revisada: boolean;
    }>;
}
