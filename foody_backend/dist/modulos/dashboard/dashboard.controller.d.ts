import { JwtPayload } from '../../core/auth/jwt-payload';
import { SucursalScopeService } from '../../core/auth/sucursal-scope.service';
import { DashboardService } from './dashboard.service';
export declare class DashboardController {
    private readonly dashboardService;
    private readonly sucursalScope;
    constructor(dashboardService: DashboardService, sucursalScope: SucursalScopeService);
    resumen(usuario: JwtPayload, sucursalId?: string): Promise<Record<string, unknown> | {
        ventas_hoy: number;
        pedidos_activos: number;
        pedidos_pendientes_qr: number;
        pedidos_completados_hoy: number;
        alertas_pendientes: number;
    }>;
    graficos(usuario: JwtPayload, sucursalId?: string): Promise<{
        ventas_7_dias: {
            dia: string;
            pedidos: number;
            ventas: number;
        }[];
        pedidos_por_tipo_hoy: {
            tipo: string;
            pedidos: number;
            ventas: number;
        }[];
        top_productos_7d: {
            nombre: string;
            cantidad: number;
            ventas: number;
        }[];
    }>;
    consolidado(usuario: JwtPayload): Promise<{
        restaurante_id: string;
        sucursales_activas: number;
        totales: {
            ventas_hoy: number;
            pedidos_activos: number;
            pedidos_pendientes_qr: number;
            pedidos_completados_hoy: number;
            alertas_pendientes: number;
        };
        por_sucursal: import("./dashboard.service").ResumenSucursalDashboard[];
    }>;
}
