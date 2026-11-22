import { PoolClient } from 'pg';
export type TipoMovimientoCaja = 'venta' | 'devolucion' | 'apertura' | 'gasto' | 'retiro' | 'ingreso_extra';
export type ReversaVentasPedidoResultado = {
    movimientos: number;
    monto_total: number;
};
export interface MovimientoCajaParams {
    cajaId: string;
    sucursalId: string;
    tipo: TipoMovimientoCaja;
    monto: number;
    pedidoId?: string | null;
    metodoPago?: string | null;
    descripcion?: string | null;
    usuarioId?: string | null;
}
export declare class CajaMovimientosService {
    private readonly logger;
    obtenerCajaAbiertaId(client: PoolClient, sucursalId: string): Promise<string | null>;
    insertar(client: PoolClient, params: MovimientoCajaParams): Promise<void>;
    registrarVentaPedido(client: PoolClient, params: {
        sucursalId: string;
        pedidoId: string;
        monto: number;
        metodoPago: string;
        descripcion?: string;
        usuarioId?: string | null;
    }, opciones?: {
        exigirCaja?: boolean;
    }): Promise<boolean>;
    netoCobradoPedidoEnCaja(client: PoolClient, pedidoId: string, cajaId?: string): Promise<number>;
    netoVentasDisponiblesTurno(client: PoolClient, cajaId: string): Promise<number>;
    revertirVentasPedido(client: PoolClient, pedidoId: string, sucursalId: string, usuarioId?: string, motivo?: string): Promise<ReversaVentasPedidoResultado>;
}
