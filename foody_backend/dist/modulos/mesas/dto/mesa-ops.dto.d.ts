export declare class ReservarMesaDto {
    sucursal_id: string;
    cliente_nombre: string;
    cliente_telefono?: string;
    reserva_hasta: string;
}
export declare class UnirMesasDto {
    sucursal_id: string;
    mesa_principal_id: string;
    mesas_secundarias: string[];
}
export declare class SalioSinPagarDto {
    sucursal_id: string;
    cliente_nombre: string;
    cliente_telefono?: string;
    motivo: string;
}
