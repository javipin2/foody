declare const ESTADOS_VALIDOS: readonly ["pendiente", "pendiente_aprobacion", "confirmado", "en_cocina", "listo", "pagando", "asignado", "en_camino", "entregado", "cancelado", "rechazado"];
export declare class CambiarEstadoPedidoDto {
    estado: (typeof ESTADOS_VALIDOS)[number];
    motivo?: string;
}
export {};
