import { DatabaseService } from '../../core/database/database.service';
export declare class DashboardService {
    private readonly database;
    constructor(database: DatabaseService);
    resumen(sucursalId: string): Promise<{
        ventas_hoy: number;
        pedidos_activos: number;
        pedidos_pendientes_qr: number;
        pedidos_completados_hoy: number;
        alertas_pendientes: number;
    }>;
}
