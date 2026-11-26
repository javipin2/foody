import { JwtPayload } from '../../core/auth/jwt-payload';
import { SucursalScopeService } from '../../core/auth/sucursal-scope.service';
import { FiltroReporteDto } from './dto/filtro-reporte.dto';
import { ReportesService } from './reportes.service';
export declare class ReportesController {
    private readonly reportesService;
    private readonly sucursalScope;
    constructor(reportesService: ReportesService, sucursalScope: SucursalScopeService);
    financiero(usuario: JwtPayload, query: FiltroReporteDto): Promise<{
        periodo: import("./reportes.service").RangoFechas;
        resumen: {
            ventas_total: number;
            subtotal: number;
            costo_domicilio: number;
            descuentos: number;
            pedidos: number;
            ticket_promedio: number;
        };
        cuadre_caja: {
            ventas_pedidos: number;
            ventas_movimientos_caja: number;
            diferencia: number;
            movimientos_venta: number;
            etiqueta_ventas_pedidos: string;
            etiqueta_ventas_caja: string;
            nota_periodo_caja: string;
            nota_universos: string;
            por_metodo_caja: {
                metodo_pago: string;
                total: number;
            }[];
        };
        recaudo_periodo: {
            total_neto: number;
            movimientos_venta: number;
            etiqueta: string;
            nota: string;
        };
        por_tipo: {
            tipo: string;
            pedidos: number;
            ventas: number;
            costo_domicilio: number;
        }[];
    }>;
    productos(usuario: JwtPayload, query: FiltroReporteDto): Promise<{
        periodo: import("./reportes.service").RangoFechas;
        ranking: {
            producto_id: string;
            nombre: string;
            cantidad: number;
            ventas: number;
        }[];
    }>;
    pedidos(usuario: JwtPayload, query: FiltroReporteDto): Promise<{
        periodo: import("./reportes.service").RangoFechas;
        por_estado: {
            estado: string;
            total: number;
        }[];
        por_dia: {
            dia: string;
            pedidos: number;
            ventas: number;
            costo_domicilio: number;
        }[];
    }>;
}
