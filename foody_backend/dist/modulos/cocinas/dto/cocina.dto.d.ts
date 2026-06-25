export declare class CrearCocinaDto {
    sucursal_id: string;
    nombre: string;
}
export declare class ActualizarCocinaDto {
    nombre?: string;
    activa?: boolean;
}
export declare class CrearImpresoraDto {
    sucursal_id: string;
    cocina_id: string;
    nombre: string;
    ip_local?: string;
    tipo?: string;
}
export declare class ActualizarImpresoraDto {
    nombre?: string;
    cocina_id?: string;
    ip_local?: string;
    tipo?: string;
    activa?: boolean;
}
export declare class CambiarEstadoItemDto {
    estado_cocina: 'pendiente' | 'preparando' | 'listo' | 'no_disponible';
    motivo?: string;
}
