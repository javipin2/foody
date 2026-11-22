declare class ToppingPatchDto {
    topping_id: string;
}
export declare class ActualizarItemPedidoDto {
    cantidad?: number;
    observaciones?: string | null;
    toppings?: ToppingPatchDto[];
}
export {};
