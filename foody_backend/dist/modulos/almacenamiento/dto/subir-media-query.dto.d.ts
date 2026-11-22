declare const TIPOS_IMAGEN: readonly ["producto", "categoria", "combo", "promocion", "general"];
export declare class SubirImagenQueryDto {
    sucursal_id?: string;
    tipo?: (typeof TIPOS_IMAGEN)[number];
    entidad_id?: string;
}
export declare class SubirVideoQueryDto {
    sucursal_id?: string;
    tipo?: (typeof TIPOS_IMAGEN)[number];
}
export {};
