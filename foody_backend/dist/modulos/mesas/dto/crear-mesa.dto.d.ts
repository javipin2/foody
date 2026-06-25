export declare class CrearMesaDto {
    sucursal_id: string;
    nombre: string;
    qr_token?: string;
}
export declare class ActualizarMesaDto {
    nombre?: string;
    activa?: boolean;
    mesera_asignada_id?: string | null;
}
