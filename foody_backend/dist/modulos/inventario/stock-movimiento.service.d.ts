import { PoolClient } from 'pg';
export type TipoMovimientoStock = 'venta' | 'ajuste' | 'compra' | 'conteo' | 'merma' | 'produccion';
export type AplicarMovimientoStockParams = {
    client: PoolClient;
    sucursalId: string;
    ingredienteId: string;
    tipo: TipoMovimientoStock;
    cantidad: number;
    motivo: string;
    stockPosterior: number;
    stockAnterior?: number;
    pedidoId?: string | null;
    usuarioId?: string | null;
    produccionId?: string | null;
    costoUnitarioActual?: number;
};
export type ResultadoMovimientoStock = {
    stockAnterior: number;
    stockPosterior: number;
    stockMinimo: number;
};
export declare class StockMovimientoService {
    aplicarMovimiento(p: AplicarMovimientoStockParams): Promise<ResultadoMovimientoStock>;
}
