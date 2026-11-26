export declare function validarTotalEsperadoPedido(esperado: number | undefined, actual: number, contexto: {
    subtotal: number;
    costoDomicilio: number;
    descuento: number;
}): void;
export declare function huellaIdempotenciaPedido(dto: Record<string, unknown>): string;
