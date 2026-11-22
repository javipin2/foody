export declare class SubrecetaItemDto {
    tipo_item?: 'ingrediente' | 'subreceta';
    ingrediente_id?: string;
    subreceta_id?: string;
    cantidad: number;
    unidad: string;
}
export declare class CrearSubrecetaDto {
    sucursal_id: string;
    nombre: string;
    cantidad_resultado: number;
    unidad_resultado: string;
    margen_error?: number;
    usa_produccion_lote?: boolean;
    items: SubrecetaItemDto[];
}
