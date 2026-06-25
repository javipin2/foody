import { JwtPayload } from '../../core/auth/jwt-payload';
import { FiltroReporteDto } from './dto/filtro-reporte.dto';
import { ReportesService } from './reportes.service';
export declare class ReportesController {
    private readonly reportesService;
    constructor(reportesService: ReportesService);
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
            por_metodo_caja: {
                metodo_pago: string;
                total: number;
            }[];
        };
        por_tipo: {
            tipo: string;
            pedidos: number;
            ventas: number;
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
        }[];
    }>;
}
