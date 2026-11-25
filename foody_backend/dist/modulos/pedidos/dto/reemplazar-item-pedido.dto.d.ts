import { ComboPedidoDto, ItemPedidoDto } from './crear-pedido.dto';
export declare class ReemplazarItemPedidoDto {
    idempotency_key: string;
    items?: ItemPedidoDto[];
    combos?: ComboPedidoDto[];
    motivo?: string;
}
