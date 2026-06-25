export declare class CrearIngredienteDto {
    sucursal_id: string;
    nombre: string;
    unidad_base: string;
    tipo_costeo?: string;
    proveedor?: string;
    categoria_insumo?: string;
    precio_compra?: number;
    peso_bruto?: number;
    peso_neto?: number;
    stock_minimo?: number;
    stock_actual?: number;
    costo_unitario_actual?: number;
    descontar_stock?: boolean;
}
