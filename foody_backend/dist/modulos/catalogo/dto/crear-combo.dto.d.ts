export declare class ComboItemDto {
    tipo_item: string;
    item_id: string;
    cantidad?: number;
}
export declare class CrearComboDto {
    sucursal_id: string;
    nombre: string;
    descripcion?: string;
    precio_fijo: number;
    items: ComboItemDto[];
}
