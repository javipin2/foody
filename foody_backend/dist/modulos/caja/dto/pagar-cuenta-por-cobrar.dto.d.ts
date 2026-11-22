declare const METODOS: readonly ["efectivo", "tarjeta", "transferencia", "nequi"];
export declare class PagarCuentaPorCobrarDto {
    metodo_pago?: (typeof METODOS)[number];
}
export {};
