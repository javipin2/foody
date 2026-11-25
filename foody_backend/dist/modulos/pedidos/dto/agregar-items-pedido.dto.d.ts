import { ComboPedidoDto, ItemPedidoDto } from './crear-pedido.dto';
export declare class AgregarItemsPedidoDto {
    idempotency_key?: string;
    items?: ItemPedidoDto[];
    combos?: ComboPedidoDto[];
}
