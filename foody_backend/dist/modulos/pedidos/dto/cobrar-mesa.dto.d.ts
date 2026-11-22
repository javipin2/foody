export declare class PagoLineaDto {
    metodo_pago: string;
    monto: number;
}
export declare class CobrarMesaDto {
    metodo_pago?: string;
    motivo?: string;
    pagos?: PagoLineaDto[];
    item_ids?: string[];
    monto_parcial?: number;
    propina?: number;
    idempotency_key?: string;
}
