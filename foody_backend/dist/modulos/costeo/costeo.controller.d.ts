import { CosteoService } from './costeo.service';
import { ActualizarSubrecetaDto } from './dto/actualizar-subreceta.dto';
import { CrearSubrecetaDto } from './dto/crear-subreceta.dto';
export declare class CosteoController {
    private readonly costeo;
    constructor(costeo: CosteoService);
    resumen(sucursalId: string): Promise<{
        productos: import("pg").QueryResultRow[];
        combos: import("pg").QueryResultRow[];
        productos_bajo_margen: number;
        umbral_margen: number;
    }>;
    subrecetaDetalle(recetaId: string, sucursalId: string): Promise<{
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
    subrecetas(sucursalId: string): Promise<import("pg").QueryResultRow[]>;
    combos(sucursalId: string): Promise<import("pg").QueryResultRow[]>;
    recalcular(sucursalId: string): Promise<{
        productos_recalculados: number;
        combos_recalculados: number;
        subrecetas_recalculadas: number;
    }>;
    impactoStock(productoId: string, sucursalId: string, cantidad?: string): Promise<{
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
    recalcularProducto(productoId: string, sucursalId: string): Promise<{
        producto_id: string;
        costo_calculado: number;
    }>;
    recalcularCombo(comboId: string, sucursalId: string): Promise<{
        combo_id: string;
        costo_calculado: number;
    }>;
    crearSubreceta(dto: CrearSubrecetaDto): Promise<{
        receta_id: string;
        costo_por_unidad: number;
        desglose: import("./costeo.service").DesgloseCostoReceta;
    }>;
    actualizarSubreceta(recetaId: string, dto: ActualizarSubrecetaDto): Promise<{
        receta_id: string;
        costo_por_unidad: number;
        desglose: import("./costeo.service").DesgloseCostoReceta;
    }>;
    recalcularSubreceta(recetaId: string, sucursalId: string): Promise<{
        receta_id: string;
        costo_por_unidad: number;
        desglose: import("./costeo.service").DesgloseCostoReceta;
    }>;
}
