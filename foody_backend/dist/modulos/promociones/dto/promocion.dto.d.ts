export declare class CrearPromocionDto {
    sucursal_id: string;
    titulo?: string;
    imagen_url: string;
    descripcion?: string;
    expira_at?: string;
    producto_id?: string;
    tipo_media?: 'imagen' | 'video';
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
    producto_id?: string | null;
    codigo?: string;
    descuento_porcentaje?: number;
    descuento_monto?: number;
}
export declare class RegistrarVistaPromocionDto {
    device_id: string;
}
export declare class ValidarCodigoPromocionDto {
    sucursal_id: string;
    codigo: string;
    subtotal: number;
}
