import { DatabaseService } from '../../core/database/database.service';
export interface FiltroTimeline {
    sucursal_id: string;
    desde: string;
    hasta: string;
}
export declare class AuditoriaService {
    private readonly database;
    constructor(database: DatabaseService);
    timelineTurno(filtro: FiltroTimeline): Promise<{
        sucursal_id: string;
        desde: string;
        hasta: string;
        total_eventos: number;
        resumen: {
            auditoria: number;
            alertas: number;
            caja: number;
            pedidos: number;
        };
        eventos: {
            ocurrido_at: string;
        }[];
    }>;
}
