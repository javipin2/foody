import type { Response } from 'express';
import { JwtPayload } from '../../core/auth/jwt-payload';
import { AnaliticaService } from './analitica.service';
import { FiltroAnaliticaDto } from './dto/filtro-analitica.dto';
export declare class AnaliticaController {
    private readonly analiticaService;
    constructor(analiticaService: AnaliticaService);
    resumen(usuario: JwtPayload, query: FiltroAnaliticaDto): Promise<{
        periodo: import("./analitica-periodo.util").PeriodoResuelto;
        sucursal_id: string;
        kpis: {
            ventas_netas: number;
            valor_pedidos: number;
            ventas_reconocidas: number;
            costo_ventas_reconocidas: number;
            cargo_domicilio_pedidos_cumplidos: number;
            pedidos: number;
            ticket_promedio: number;
            margen_bruto_estimado: number;
            margen_bruto_pct: number;
            cobertura_costo_pct: number;
            pct_cancelacion: number;
            pedidos_cancelados: number;
            pedidos_total_cancelacion: number;
            recaudo_neto: number;
            efectivo_vs_digital: {
                efectivo: number;
                digital: number;
            };
            alertas_abiertas: number;
        };
        comparativa: Record<string, unknown> | undefined;
        alertas_abiertas_lista: {
            id: string;
            tipo: string;
            nivel: string;
            descripcion: string;
            created_at: string;
        }[];
    }>;
    ventas(usuario: JwtPayload, query: FiltroAnaliticaDto): Promise<Record<string, unknown>>;
    productos(usuario: JwtPayload, query: FiltroAnaliticaDto): Promise<Record<string, unknown>>;
    cocinas(usuario: JwtPayload, query: FiltroAnaliticaDto): Promise<Record<string, unknown>>;
    inventario(usuario: JwtPayload, query: FiltroAnaliticaDto): Promise<Record<string, unknown>>;
    domiciliarios(usuario: JwtPayload, query: FiltroAnaliticaDto): Promise<Record<string, unknown>>;
    caja(usuario: JwtPayload, query: FiltroAnaliticaDto): Promise<Record<string, unknown>>;
    rentabilidad(usuario: JwtPayload, query: FiltroAnaliticaDto): Promise<{
        comparativa_utilidad?: {
            anterior: {
                desde: string;
                hasta: string;
                utilidad_neta: number | null;
            };
            delta_utilidad_pct: number | null;
        } | undefined;
        periodo: {
            label: string;
            desde: string;
            hasta: string;
        };
        ventas_netas: number;
        valor_pedidos: number;
        cargo_domicilio_pedidos_cumplidos: number;
        costo_ventas: number;
        utilidad_bruta: number;
        utilidad_bruta_pct: number;
        gastos_por_categoria: {
            categoria: string;
            total: number;
            cantidad: number;
        }[];
        gastos_por_origen: {
            origen: string;
            total: number;
            cantidad: number;
        }[];
        total_gastos: number;
        utilidad_neta: number;
        margen_neto_pct: number;
        es_rentable: boolean;
        punto_equilibrio: number | null;
        cobertura_costo_pct: number;
        nota_compras: string;
        fuente_cogs: string;
        nota_cogs: string;
        compras_periodo: number;
        consejos: {
            codigo: string;
            nivel: "info" | "aviso" | "alerta";
            mensaje: string;
        }[];
    }>;
    riesgo(usuario: JwtPayload, query: FiltroAnaliticaDto): Promise<Record<string, unknown>>;
    pedidosRecientes(usuario: JwtPayload, query: FiltroAnaliticaDto): Promise<{
        periodo: import("./analitica-periodo.util").PeriodoResuelto;
        sucursal_id: string;
        pedidos: {
            id: string;
            numero_pedido: string;
            tipo: string;
            mesa_nombre: string | null;
            cliente_nombre: string | null;
            total: number;
            estado: string;
            created_at: string;
        }[];
    }>;
    export(usuario: JwtPayload, query: FiltroAnaliticaDto, res: Response): Promise<void>;
    comparativaSedes(usuario: JwtPayload, query: FiltroAnaliticaDto): Promise<{
        periodo: import("./analitica-periodo.util").PeriodoResuelto;
        restaurante_id: string;
        sucursales_activas: number;
        totales: {
            ventas_netas: number;
            pedidos: number;
            alertas_abiertas: number;
        };
        sedes: {
            sucursal_id: string;
            nombre: string;
            kpis: {
                ventas_netas: number;
                pedidos: number;
                ticket_promedio: number;
                margen_bruto_estimado: number;
                margen_bruto_pct: number;
                cobertura_costo_pct: number;
                pct_cancelacion: number;
                efectivo_vs_digital: {
                    efectivo: number;
                    digital: number;
                };
                alertas_abiertas: number;
            };
        }[];
    }>;
}
