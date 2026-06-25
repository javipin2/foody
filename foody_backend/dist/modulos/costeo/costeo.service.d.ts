import { PoolClient } from 'pg';
import { DatabaseService } from '../../core/database/database.service';
import { AlertasRiesgoService } from '../alertas/alertas-riesgo.service';
import { ActualizarSubrecetaDto } from './dto/actualizar-subreceta.dto';
import { CrearSubrecetaDto } from './dto/crear-subreceta.dto';
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
    constructor(database: DatabaseService, alertasRiesgo: AlertasRiesgoService);
    costoRealUnitario(costoUnitario: number, rendimientoPorcentaje: number): number;
    calcularReceta(client: PoolClient, recetaId: string, sucursalId: string, visitados?: Set<string>): Promise<DesgloseCostoReceta>;
    persistirCostoReceta(client: PoolClient, sucursalId: string, desglose: DesgloseCostoReceta, precioVenta?: number | null): Promise<void>;
    recalcularProducto(client: PoolClient, productoId: string, sucursalId: string, recalculando?: Set<string>, recalcularPadres?: boolean): Promise<number>;
    recalcularCombo(client: PoolClient, comboId: string, sucursalId: string): Promise<number>;
    recalcularSucursal(sucursalId: string): Promise<{
        productos_recalculados: number;
        combos_recalculados: number;
        subrecetas_recalculadas: number;
    }>;
    expandirIngredientesProducto(client: PoolClient, productoId: string, sucursalId: string, cantidadPorciones: number, incluirEmpaques: boolean): Promise<IngredienteExpandido[]>;
    expandirSoloRecetaProducto(client: PoolClient, productoId: string, sucursalId: string, cantidadPorciones: number, incluirEmpaques: boolean): Promise<IngredienteExpandido[]>;
    listarItemsIncluidosProducto(productoId: string, sucursalId: string): Promise<import("pg").QueryResultRow[]>;
    calcularPrecioSugerido(costo: number, margenObjetivoPct: number): number;
    impactoStockProducto(productoId: string, sucursalId: string, cantidad?: number): Promise<{
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
    resumenSucursal(sucursalId: string): Promise<{
        productos: import("pg").QueryResultRow[];
        combos: import("pg").QueryResultRow[];
        productos_bajo_margen: number;
        umbral_margen: number;
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
    private recalcularProductosQueUsanSubreceta;
    private expandirReceta;
    private costoUnitarioSubreceta;
    private costoLineaIngrediente;
    private insertarItemsSubreceta;
    private cantidadEnUnidadSubreceta;
    private consultarReceta;
    private margenObjetivoProducto;
    private umbralMargenSucursal;
    private umbralMargenSucursalDesdeDb;
    private sumarCostosItemsIncluidos;
    private obtenerCostoUnitarioIncluido;
    private recalcularProductosPadre;
    private evaluarAlertaMargenProducto;
}
