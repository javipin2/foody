export type CategoriaInsumo = 'alimento' | 'empaque' | 'mano_obra' | 'servicio';
export interface DatosMercadoInsumo {
    precio_compra: number;
    peso_bruto: number;
    peso_neto: number;
    unidad_base: string;
}
export interface CostoDerivadoMercado {
    costo_unitario_actual: number;
    rendimiento_porcentaje: number;
    factor_correccion: number;
    costo_por_unidad_bruta: number;
}
export declare function derivarCostoDesdeMercado(datos: DatosMercadoInsumo): CostoDerivadoMercado;
export declare function tipoCosteoDesdeUnidad(unidad: string): string;
export declare function enriquecerInsumoRespuesta<T extends Record<string, unknown>>(fila: T): T & {
    costo_real: number;
    factor_correccion: number | null;
};
