import { PoolClient } from 'pg';
export type OrigenCambioEstadoPedido = 'kanban' | 'aprobacion_qr' | 'cocina' | 'dispatch' | 'domiciliario' | 'cobro' | 'sistema';
export type AplicarEstadoPedidoParams = {
    pedidoId: string;
    sucursalId: string;
    nuevoEstado: string;
    origen: OrigenCambioEstadoPedido;
    usuarioId?: string | null;
    motivo?: string | null;
    estadoAnterior?: string;
    tipo?: string;
    rol?: string | null;
};
export declare class PedidosEstadoCommandService {
    aplicarEstadoEnTransaccion(client: PoolClient, params: AplicarEstadoPedidoParams): Promise<{
        aplicado: boolean;
        anterior: string;
        nuevo: string;
        tipo: string;
    }>;
    private transicionPermitidaParaOrigen;
    private motivoPorOrigen;
}
