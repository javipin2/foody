import { DatabaseService } from '../../core/database/database.service';
export interface RangoFechas {
    desde: string;
    hasta: string;
}
export declare class ReportesService {
    private readonly database;
    constructor(database: DatabaseService);
    financiero(sucursalId: string, rango: RangoFechas): Promise<{
        periodo: RangoFechas;
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
            nota_universos: string;
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
    productos(sucursalId: string, rango: RangoFechas): Promise<{
        periodo: RangoFechas;
        ranking: {
            producto_id: string;
            nombre: string;
            cantidad: number;
            ventas: number;
        }[];
    }>;
    pedidos(sucursalId: string, rango: RangoFechas): Promise<{
        periodo: RangoFechas;
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
    resolverRango(desde?: string, hasta?: string): RangoFechas;
}
