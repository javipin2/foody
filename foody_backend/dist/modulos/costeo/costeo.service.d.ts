import { PoolClient } from 'pg';
import { DatabaseService } from '../../core/database/database.service';
import { AlertasRiesgoService } from '../alertas/alertas-riesgo.service';
import { ActualizarSubrecetaDto } from './dto/actualizar-subreceta.dto';
import { CrearSubrecetaDto } from './dto/crear-subreceta.dto';
import { RegistrarProduccionDto } from './dto/registrar-produccion.dto';
import { PeriodoResuelto } from '../analitica/analitica-periodo.util';
import { PresetAnalitica } from '../analitica/dto/filtro-analitica.dto';
import { StockMovimientoService } from '../inventario/stock-movimiento.service';
export interface DesgloseCostoReceta {
    receta_id: string;
    costo_ingredientes: number;
    costo_subrecetas: number;
    costo_empaques: number;
    costo_merma: number;
    costo_base: number;
    costo_domicilio: number;
    costo_por_porcion: number;
}
export interface IngredienteExpandido {
    ingrediente_id: string;
    cantidad: number;
}
export declare class CosteoService {
    private readonly database;
    private readonly alertasRiesgo;
    private readonly stockMovimiento;
    constructor(database: DatabaseService, alertasRiesgo: AlertasRiesgoService, stockMovimiento: StockMovimientoService);
    costoRealUnitario(costoUnitario: number, rendimientoPorcentaje: number): number;
    calcularReceta(client: PoolClient, recetaId: string, sucursalId: string, visitados?: Set<string>): Promise<DesgloseCostoReceta>;
    persistirCostoReceta(client: PoolClient, sucursalId: string, desglose: DesgloseCostoReceta, precioVenta?: number | null): Promise<void>;
    recalcularProducto(client: PoolClient, productoId: string, sucursalId: string, recalculando?: Set<string>, recalcularPadres?: boolean): Promise<number>;
    recalcularCombo(client: PoolClient, comboId: string, sucursalId: string): Promise<number>;
    recalcularSucursal(sucursalId: string): Promise<{
        productos_recalculados: number;
        bebidas_recalculadas: number;
        toppings_recalculados: number;
        combos_recalculados: number;
        subrecetas_recalculadas: number;
    }>;
    expandirIngredientesExtra(client: PoolClient, tipo: 'bebida' | 'topping', extraId: string, sucursalId: string, cantidadPorciones: number, incluirEmpaques: boolean): Promise<IngredienteExpandido[]>;
    recalcularExtra(client: PoolClient, tipo: 'bebida' | 'topping', extraId: string, sucursalId: string): Promise<number>;
    recalcularExtraPorId(tipo: 'bebida' | 'topping', extraId: string, sucursalId: string): Promise<{
        tipo_entidad: "bebida" | "topping";
        id: string;
        costo_calculado: number;
    }>;
    expandirIngredientesProducto(client: PoolClient, productoId: string, sucursalId: string, cantidadPorciones: number, incluirEmpaques: boolean): Promise<IngredienteExpandido[]>;
    expandirSoloRecetaProducto(client: PoolClient, productoId: string, sucursalId: string, cantidadPorciones: number, incluirEmpaques: boolean): Promise<IngredienteExpandido[]>;
    listarItemsIncluidosProducto(productoId: string, sucursalId: string): Promise<import("pg").QueryResultRow[]>;
    calcularPrecioSugerido(costo: number, margenObjetivoPct: number): number;
    impactoStockProducto(productoId: string, sucursalId: string, cantidad?: number, tipoEntidad?: 'producto' | 'bebida' | 'topping'): Promise<{
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
    private impactoStockExtra;
    resumenSucursal(sucursalId: string): Promise<{
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
    recalcularComboPorId(comboId: string, sucursalId: string): Promise<{
        combo_id: string;
        costo_calculado: number;
    }>;
    recalcularProductoPorId(productoId: string, sucursalId: string): Promise<{
        producto_id: string;
        costo_calculado: number;
    }>;
    crearSubreceta(dto: CrearSubrecetaDto): Promise<{
        receta_id: string;
        costo_por_unidad: number;
        desglose: DesgloseCostoReceta;
    }>;
    listarCombos(sucursalId: string): Promise<import("pg").QueryResultRow[]>;
    listarSubrecetas(sucursalId: string): Promise<import("pg").QueryResultRow[]>;
    obtenerSubrecetaDetalle(recetaId: string, sucursalId: string): Promise<{
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
    actualizarSubreceta(recetaId: string, dto: ActualizarSubrecetaDto): Promise<{
        receta_id: string;
        costo_por_unidad: number;
        desglose: DesgloseCostoReceta;
    }>;
    recalcularSubrecetaPorId(recetaId: string, sucursalId: string): Promise<{
        receta_id: string;
        costo_por_unidad: number;
        desglose: DesgloseCostoReceta;
    }>;
    simuladorPopularidad(sucursalId: string, preset?: PresetAnalitica, desde?: string, hasta?: string): Promise<{
        periodo: PeriodoResuelto;
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
    private construirSimuladorPopularidad;
    private enriquecerCanalPopularidad;
    private mediana;
    listarProducciones(sucursalId: string, recetaId?: string): Promise<import("pg").QueryResultRow[]>;
    registrarProduccion(dto: RegistrarProduccionDto, usuarioId: string): Promise<{
        produccion_id: string;
        receta_id: string;
        cantidad_producida: number;
        costo_real_produccion: number;
        costo_unitario: number;
        ingrediente_lote_id: string;
        stock_lote: number;
    }>;
    private recalcularProductosQueUsanSubreceta;
    private margenObjetivoSucursal;
    private expandirReceta;
    private costoUnitarioSubreceta;
    private costoLineaIngrediente;
    private insertarItemsSubreceta;
    private cantidadEnUnidadSubreceta;
    private consultarReceta;
    private margenObjetivoProducto;
    private umbralMargenSucursal;
    private umbralMargenSucursalDesdeDb;
    private margenObjetivoDefaultSucursal;
    private margenObjetivoDefaultSucursalDesdeDb;
    private sumarCostosItemsIncluidos;
    private obtenerCostoUnitarioIncluido;
    private recalcularProductosPadre;
    private asegurarIngredienteSubreceta;
    private obtenerIngredienteSubreceta;
    private aplicarMovimientoStock;
    private calcularConsumoProduccion;
    private costoLineaIngredienteConBase;
    private evaluarAlertaMargenProducto;
}
