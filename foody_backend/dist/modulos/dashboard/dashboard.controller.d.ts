import { JwtPayload } from '../../core/auth/jwt-payload';
import { SucursalScopeService } from '../../core/auth/sucursal-scope.service';
import { DashboardService } from './dashboard.service';
export declare class DashboardController {
    private readonly dashboardService;
    private readonly sucursalScope;
    constructor(dashboardService: DashboardService, sucursalScope: SucursalScopeService);
    resumen(usuario: JwtPayload, sucursalId?: string): Promise<{
        ventas_hoy: number;
        pedidos_activos: number;
        pedidos_pendientes_qr: number;
        pedidos_completados_hoy: number;
        alertas_pendientes: number;
    }>;
}
