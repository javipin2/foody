import { DatabaseService } from '../../core/database/database.service';
import { JwtPayload } from '../../core/auth/jwt-payload';
import { SucursalScopeService } from '../../core/auth/sucursal-scope.service';
import { FiltrosAnalitica } from './analitica-filtros.util';
import { PeriodoResuelto } from './analitica-periodo.util';
import { FiltroAnaliticaDto } from './dto/filtro-analitica.dto';
export declare class AnaliticaService {
    private readonly database;
    private readonly sucursalScope;
    constructor(database: DatabaseService, sucursalScope: SucursalScopeService);
    resolverContexto(usuario: JwtPayload, query: FiltroAnaliticaDto): Promise<{
        sucursalId: string;
        periodo: PeriodoResuelto;
        anterior: {
            desde: string;
            hasta: string;
        } | undefined;
        filtros: FiltrosAnalitica;
    }>;
    comparativaSedesParaUsuario(usuario: JwtPayload, query: FiltroAnaliticaDto): Promise<{
        periodo: PeriodoResuelto;
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
    private inicio;
    private inicioCaja;
    private consultarVentasKpi;
    resumen(sucursalId: string, periodo: PeriodoResuelto, anterior?: {
        desde: string;
        hasta: string;
    }, filtros?: FiltrosAnalitica): Promise<{
        periodo: PeriodoResuelto;
        sucursal_id: string;
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
        comparativa: Record<string, unknown> | undefined;
        alertas_abiertas_lista: {
            id: string;
            tipo: string;
            nivel: string;
            descripcion: string;
            created_at: string;
        }[];
    }>;
    private ventasNetasPeriodo;
    private kpisPeriodo;
    private adjuntarComparativaKpis;
    ventas(sucursalId: string, periodo: PeriodoResuelto, filtros?: FiltrosAnalitica, anterior?: {
        desde: string;
        hasta: string;
    }): Promise<Record<string, unknown>>;
    productos(sucursalId: string, periodo: PeriodoResuelto, filtros?: FiltrosAnalitica, anterior?: {
        desde: string;
        hasta: string;
    }): Promise<Record<string, unknown>>;
    cocinas(sucursalId: string, periodo: PeriodoResuelto, filtros?: FiltrosAnalitica, anterior?: {
        desde: string;
        hasta: string;
    }): Promise<Record<string, unknown>>;
    inventario(sucursalId: string, periodo: PeriodoResuelto, filtros?: FiltrosAnalitica, anterior?: {
        desde: string;
        hasta: string;
    }): Promise<Record<string, unknown>>;
    domiciliarios(sucursalId: string, periodo: PeriodoResuelto, filtros?: FiltrosAnalitica, anterior?: {
        desde: string;
        hasta: string;
    }): Promise<Record<string, unknown>>;
    caja(sucursalId: string, periodo: PeriodoResuelto, filtros?: FiltrosAnalitica, anterior?: {
        desde: string;
        hasta: string;
    }): Promise<Record<string, unknown>>;
    rentabilidad(sucursalId: string, periodo: PeriodoResuelto, filtros?: FiltrosAnalitica, anterior?: {
        desde: string;
        hasta: string;
    }): Promise<{
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
    riesgo(sucursalId: string, periodo: PeriodoResuelto, filtros?: FiltrosAnalitica, anterior?: {
        desde: string;
        hasta: string;
    }): Promise<Record<string, unknown>>;
    pedidosRecientes(sucursalId: string, periodo: PeriodoResuelto, filtros?: FiltrosAnalitica, limite?: number): Promise<{
        periodo: PeriodoResuelto;
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
    private cocinasPrepDelta;
    private categoriasCaida;
    private csvEscape;
    private csvRow;
    exportarCsv(sucursalId: string, periodo: PeriodoResuelto, anterior: {
        desde: string;
        hasta: string;
    } | undefined, filtros?: FiltrosAnalitica): Promise<{
        filename: string;
        buffer: Buffer<ArrayBuffer>;
        mime: string;
    }>;
    comparativaSedes(restauranteId: string, periodo: PeriodoResuelto): Promise<{
        periodo: PeriodoResuelto;
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
