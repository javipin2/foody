import { PagoLineaDto } from './cobrar-mesa.dto';
declare class ToppingItemDto {
    topping_id: string;
}
declare class BebidaItemDto {
    bebida_id: string;
    cantidad: number;
}
export declare class ItemPedidoDto {
    producto_id: string;
    cantidad: number;
    precio: number;
    observaciones?: string;
    toppings?: ToppingItemDto[];
    bebidas?: BebidaItemDto[];
}
export declare class ComboPedidoDto {
    combo_id: string;
    cantidad: number;
    precio: number;
}
export declare class CrearPedidoDto {
    sucursal_id: string;
    mesa_id?: string;
    device_id: string;
    tipo: string;
    cliente_nombre?: string;
    cliente_telefono?: string;
    direccion_entrega?: string;
    lat?: number;
    lng?: number;
    metodo_pago?: string;
    requiere_factura?: boolean;
    nit_cliente?: string;
    nombre_fiscal_cliente?: string;
    email_cliente?: string;
    observaciones?: string;
    items?: ItemPedidoDto[];
    combos?: ComboPedidoDto[];
    codigo_promocion?: string;
    idempotency_key?: string;
    pagos?: PagoLineaDto[];
    propina?: number;
}
export {};
