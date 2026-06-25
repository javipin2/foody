export declare class CrearZonaDto {
    sucursal_id: string;
    nombre: string;
    costo_domicilio: number;
    distancia_max_km: number;
}
export declare class ActualizarZonaDto {
    nombre?: string;
    costo_domicilio?: number;
    distancia_max_km?: number;
    activa?: boolean;
}
export declare class UbicacionSucursalDto {
    lat: number;
    lng: number;
}
export declare class CotizarDomicilioDto {
    sucursal_id: string;
    lat?: number;
    lng?: number;
}
