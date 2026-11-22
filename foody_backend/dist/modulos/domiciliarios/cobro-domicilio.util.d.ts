export declare function repartirCobroDomicilio(total: number, costoDomicilio: number, montoPagado: number): {
    saldo: number;
    productoPendiente: number;
    domicilioPendiente: number;
};
export declare function montoVentaCajaEntregaDomicilio(total: number, costoDomicilio: number, montoPagado: number, domicilioIngresaACaja: boolean): number;
