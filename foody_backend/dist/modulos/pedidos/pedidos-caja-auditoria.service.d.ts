import { PoolClient } from 'pg';
export declare const METODOS_CON_CAJA: readonly ["efectivo", "tarjeta", "transferencia", "nequi"];
export declare function esPagoDiferidoMesa(tipo: string, mesaId: string | null | undefined): boolean;
export declare class PedidosCajaAuditoriaService {
    debeRegistrarVentaAlCrear(estadoInicial: string, tipo: string, mesaId: string | null | undefined, metodoPago: string): boolean;
    obtenerCajaAbiertaId(client: PoolClient, sucursalId: string): Promise<string | null>;
    registrarVentaEnCaja(client: PoolClient, sucursalId: string, pedidoId: string, total: number, metodoPago: string, opciones?: {
        exigirCaja?: boolean;
        descripcion?: string;
    }): Promise<void>;
    revertirVentasPedido(client: PoolClient, pedidoId: string, sucursalId: string, usuarioId?: string, motivo?: string): Promise<number>;
    registrarAuditoria(client: PoolClient, sucursalId: string, pedidoId: string, datos: Record<string, unknown>): Promise<void>;
    registrarAuditoriaCobroMesa(client: PoolClient, sucursalId: string, mesaId: string, usuarioId: string, datos: Record<string, unknown>): Promise<void>;
}
