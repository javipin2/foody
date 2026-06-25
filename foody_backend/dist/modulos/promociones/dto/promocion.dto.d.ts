export declare class CrearPromocionDto {
    sucursal_id: string;
    titulo?: string;
    imagen_url: string;
    descripcion?: string;
    expira_at?: string;
    codigo?: string;
    descuento_porcentaje?: number;
    descuento_monto?: number;
}
export declare class ActualizarPromocionDto {
    titulo?: string;
    imagen_url?: string;
    descripcion?: string;
    expira_at?: string;
    activa?: boolean;
    codigo?: string;
    descuento_porcentaje?: number;
    descuento_monto?: number;
}
export declare class RegistrarVistaPromocionDto {
    device_id: string;
}
