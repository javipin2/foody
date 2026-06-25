export declare class CompraItemDto {
    ingrediente_id: string;
    cantidad_unidades_base: number;
    precio_total: number;
}
export declare class RegistrarCompraDto {
    sucursal_id: string;
    proveedor?: string;
    observaciones?: string;
    items: CompraItemDto[];
}
