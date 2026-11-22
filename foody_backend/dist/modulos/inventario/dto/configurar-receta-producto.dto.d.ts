export declare class RecetaItemDto {
    tipo_item: 'ingrediente' | 'subreceta' | 'empaque';
    ingrediente_id?: string;
    subreceta_id?: string;
    cantidad: number;
    unidad: string;
}
export declare class ConfigurarRecetaProductoDto {
    producto_id: string;
    tipo_entidad?: 'producto' | 'bebida' | 'topping';
    items: RecetaItemDto[];
    margen_error?: number;
}
