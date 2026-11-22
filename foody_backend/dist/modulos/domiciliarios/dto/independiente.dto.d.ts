export declare class IniciarSesionDto {
    lat: number;
    lng: number;
    ciudad_id?: string;
}
export declare class UbicacionDto {
    lat: number;
    lng: number;
}
export declare class UbicacionEntregaDto extends UbicacionDto {
    pedido_id?: string;
}
export declare class ResponderOfertaDto {
    respuesta: 'aceptada' | 'rechazada';
}
