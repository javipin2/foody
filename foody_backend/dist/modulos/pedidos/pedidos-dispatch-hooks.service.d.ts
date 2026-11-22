export type ResultadoDispatchAuto = {
    iniciado: boolean;
    motivo?: string;
};
type HandlerDispatchAuto = (pedidoId: string, sucursalId: string) => Promise<ResultadoDispatchAuto>;
export declare class PedidosDispatchHooksService {
    private handler;
    registrar(handler: HandlerDispatchAuto): void;
    intentarDispatchAutomatico(pedidoId: string, sucursalId: string): Promise<ResultadoDispatchAuto>;
}
export {};
