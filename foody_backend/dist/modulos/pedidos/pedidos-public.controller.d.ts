import { CrearPedidoDto } from './dto/crear-pedido.dto';
import { PedidosService } from './pedidos.service';
export declare class PedidosPublicController {
    private readonly pedidosService;
    constructor(pedidosService: PedidosService);
    crear(dto: CrearPedidoDto): Promise<{
        pedido_id: string;
        numero_pedido: string;
        subtotal: number;
        costo_domicilio: number;
        total: number;
        estado: string;
        tiempo_estimado_minutos: number;
        factura_id: string | null;
    } | {
        idempotente: boolean;
    }>;
    listarMios(deviceId?: string): Promise<import("pg").QueryResultRow[]>;
    estado(id: string): Promise<{
        pedido_id: string;
        numero_pedido: string;
        estado_actual: string;
        tipo: string;
        total: number;
        lat: number | null;
        lng: number | null;
        direccion_entrega: string | null;
        tiempo_estimado_minutos: number | null;
        historial: {
            estado: string;
            fecha: Date;
        }[];
    }>;
}
