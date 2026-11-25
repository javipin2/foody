import type { Cache } from 'cache-manager';
import { DatabaseService } from '../../core/database/database.service';
import { JwtPayload } from '../../core/auth/jwt-payload';
import { SucursalScopeService } from '../../core/auth/sucursal-scope.service';
export type ResumenSucursalDashboard = {
    sucursal_id: string;
    nombre: string;
    ventas_hoy: number;
    pedidos_activos: number;
    pedidos_pendientes_qr: number;
    pedidos_completados_hoy: number;
    alertas_pendientes: number;
    domicilios_tardios: Array<{
        numero: string;
        detalle: string;
        minutos: number;
        severidad: number;
    }>;
};
export declare class DashboardService {
    private readonly database;
    private readonly sucursalScope;
    private readonly cache;
    constructor(database: DatabaseService, sucursalScope: SucursalScopeService, cache: Cache);
    consolidadoParaUsuario(usuario: JwtPayload): Promise<{
        restaurante_id: string;
        sucursales_activas: number;
        totales: {
            ventas_hoy: number;
            pedidos_activos: number;
            pedidos_pendientes_qr: number;
            pedidos_completados_hoy: number;
            alertas_pendientes: number;
        };
        por_sucursal: ResumenSucursalDashboard[];
    }>;
    resumen(sucursalId: string): Promise<Record<string, unknown> | {
        ventas_hoy: number;
        pedidos_activos: number;
        pedidos_pendientes_qr: number;
        pedidos_completados_hoy: number;
        alertas_pendientes: number;
        domicilios_tardios: {
            numero: string;
            detalle: string;
            minutos: number;
            severidad: number;
        }[];
    }>;
    graficos(sucursalId: string): Promise<{
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
    consolidado(restauranteId: string): Promise<{
        restaurante_id: string;
        sucursales_activas: number;
        totales: {
            ventas_hoy: number;
            pedidos_activos: number;
            pedidos_pendientes_qr: number;
            pedidos_completados_hoy: number;
            alertas_pendientes: number;
        };
        por_sucursal: ResumenSucursalDashboard[];
    }>;
    private resumenVacio;
    private resumenSucursalSql;
}
