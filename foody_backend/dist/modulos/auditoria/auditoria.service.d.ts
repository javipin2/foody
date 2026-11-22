import { PoolClient } from 'pg';
import { DatabaseService } from '../../core/database/database.service';
export interface FiltroTimeline {
    sucursal_id: string;
    desde: string;
    hasta: string;
}
export interface RegistroAuditoria {
    sucursalId: string;
    accion: string;
    tablaAfectada: string;
    registroId: string;
    usuarioId?: string | null;
    datosAntes?: Record<string, unknown> | null;
    datosDespues?: Record<string, unknown> | null;
}
export declare class AuditoriaService {
    private readonly database;
    constructor(database: DatabaseService);
    registrarEnTransaccion(client: PoolClient, registro: RegistroAuditoria): Promise<void>;
    registrar(registro: RegistroAuditoria): Promise<void>;
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
