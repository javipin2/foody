import { JwtPayload } from '../../core/auth/jwt-payload';
import { SucursalScopeService } from '../../core/auth/sucursal-scope.service';
import { CosteoService } from './costeo.service';
import { ActualizarSubrecetaDto } from './dto/actualizar-subreceta.dto';
import { CrearSubrecetaDto } from './dto/crear-subreceta.dto';
import { RegistrarProduccionDto } from './dto/registrar-produccion.dto';
import { FiltroPopularidadQueryDto } from './dto/filtro-popularidad.dto';
import { ImpactoStockQueryDto } from './dto/impacto-stock-query.dto';
export declare class CosteoController {
    private readonly costeo;
    private readonly sucursalScope;
    constructor(costeo: CosteoService, sucursalScope: SucursalScopeService);
    resumen(usuario: JwtPayload, sucursalId: string): Promise<{
        productos: {
            tipo_entidad: string;
            costo_canal_llevar: number;
            precio_sugerido_llevar: number | null;
            margen_llevar_porcentaje: number | null;
        }[];
        bebidas: {
            tipo_entidad: string;
            margen_porcentaje: number | null;
            food_cost_porcentaje: number | null;
        }[];
        toppings: {
            tipo_entidad: string;
            margen_porcentaje: number | null;
            food_cost_porcentaje: number | null;
        }[];
        combos: import("pg").QueryResultRow[];
        productos_bajo_margen: number;
        umbral_margen: number;
        margen_objetivo_default: number;
    }>;
    subrecetaDetalle(usuario: JwtPayload, recetaId: string, sucursalId: string): Promise<{
        items: import("pg").QueryResultRow[];
        costo: {
            costo_total: string;
            costo_por_porcion: string;
            costo_ingredientes: string;
            costo_merma: string;
            calculado_at: string;
        } | null;
        id: string;
        nombre: string;
        cantidad_resultado: string;
        unidad_resultado: string;
        margen_error: string;
        usa_produccion_lote: boolean;
    }>;
    subrecetas(usuario: JwtPayload, sucursalId: string): Promise<import("pg").QueryResultRow[]>;
    combos(usuario: JwtPayload, sucursalId: string): Promise<import("pg").QueryResultRow[]>;
    recalcular(usuario: JwtPayload, sucursalId: string): Promise<{
        productos_recalculados: number;
        bebidas_recalculadas: number;
        toppings_recalculados: number;
        combos_recalculados: number;
        subrecetas_recalculadas: number;
    }>;
    impactoStock(usuario: JwtPayload, productoId: string, query: ImpactoStockQueryDto): Promise<{
        producto_id: string;
        producto_nombre: string;
        cantidad: number;
        tiene_receta: boolean;
        puede_vender: boolean;
        ingredientes: never[];
        faltas: never[];
        incluidos: {
            producto_id: string;
            nombre: string;
            cantidad: number;
        }[];
        mensaje: string | null;
    } | {
        producto_id: string;
        producto_nombre: string;
        cantidad: number;
        tiene_receta: boolean;
        puede_vender: boolean;
        ingredientes: {
            ingrediente_id: string;
            nombre: string;
            unidad: string;
            necesita: number;
            disponible: number;
            minimo: number;
            descontar_stock: boolean;
            bajo_minimo: boolean;
            falta: boolean;
        }[];
        faltas: {
            ingrediente_id: string;
            nombre: string;
            unidad: string;
            necesita: number;
            disponible: number;
            minimo: number;
            descontar_stock: boolean;
            bajo_minimo: boolean;
            falta: boolean;
        }[];
        incluidos: {
            producto_id: string;
            nombre: string;
            cantidad: number;
        }[];
        mensaje: string;
    }>;
    recalcularProducto(usuario: JwtPayload, productoId: string, sucursalId: string, tipoEntidad?: string): Promise<{
        tipo_entidad: "bebida" | "topping";
        id: string;
        costo_calculado: number;
    } | {
        producto_id: string;
        costo_calculado: number;
    }>;
    recalcularCombo(usuario: JwtPayload, comboId: string, sucursalId: string): Promise<{
        combo_id: string;
        costo_calculado: number;
    }>;
    crearSubreceta(usuario: JwtPayload, dto: CrearSubrecetaDto): Promise<{
        receta_id: string;
        costo_por_unidad: number;
        desglose: import("./costeo.service").DesgloseCostoReceta;
    }>;
    actualizarSubreceta(usuario: JwtPayload, recetaId: string, dto: ActualizarSubrecetaDto): Promise<{
        receta_id: string;
        costo_por_unidad: number;
        desglose: import("./costeo.service").DesgloseCostoReceta;
    }>;
    recalcularSubreceta(usuario: JwtPayload, recetaId: string, sucursalId: string): Promise<{
        receta_id: string;
        costo_por_unidad: number;
        desglose: import("./costeo.service").DesgloseCostoReceta;
    }>;
    simuladorPopularidad(usuario: JwtPayload, sucursalId: string, query: FiltroPopularidadQueryDto): Promise<{
        periodo: import("../analitica/analitica-periodo.util").PeriodoResuelto;
        sucursal_id: string;
        mesa: {
            productos: {
                margen_porcentaje: number;
                participacion_ventas_pct: number;
                participacion_acum_pct: number;
                clasificacion_abc: "A" | "B" | "C";
                clasificacion_matriz: "estrella" | "caballo" | "puzzle" | "perro";
                producto_id: string;
                nombre: string;
                cantidad: number;
                ventas: number;
                margen_bruto: number;
            }[];
            totales: {
                ventas: number;
                cantidad: number;
                margen_bruto: number;
            };
            medianas: {
                cantidad: number;
                margen_porcentaje: number;
            };
            resumen_matriz: {
                estrella: number;
                caballo: number;
                puzzle: number;
                perro: number;
            };
        };
        domicilio: {
            productos: {
                margen_porcentaje: number;
                participacion_ventas_pct: number;
                participacion_acum_pct: number;
                clasificacion_abc: "A" | "B" | "C";
                clasificacion_matriz: "estrella" | "caballo" | "puzzle" | "perro";
                producto_id: string;
                nombre: string;
                cantidad: number;
                ventas: number;
                margen_bruto: number;
            }[];
            totales: {
                ventas: number;
                cantidad: number;
                margen_bruto: number;
            };
            medianas: {
                cantidad: number;
                margen_porcentaje: number;
            };
            resumen_matriz: {
                estrella: number;
                caballo: number;
                puzzle: number;
                perro: number;
            };
        };
    }>;
    listarProducciones(usuario: JwtPayload, sucursalId: string, recetaId?: string): Promise<import("pg").QueryResultRow[]>;
    registrarProduccion(usuario: JwtPayload, dto: RegistrarProduccionDto): Promise<{
        produccion_id: string;
        receta_id: string;
        cantidad_producida: number;
        costo_real_produccion: number;
        costo_unitario: number;
        ingrediente_lote_id: string;
        stock_lote: number;
    }>;
}
