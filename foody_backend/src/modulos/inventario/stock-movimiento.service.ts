import { Injectable, NotFoundException } from '@nestjs/common';
import { PoolClient } from 'pg';

export type TipoMovimientoStock =
  | 'venta'
  | 'ajuste'
  | 'compra'
  | 'conteo'
  | 'merma'
  | 'devolucion'
  | 'produccion';

export type AplicarMovimientoStockParams = {
  client: PoolClient;
  sucursalId: string;
  ingredienteId: string;
  tipo: TipoMovimientoStock;
  /** Valor absoluto guardado en movimientos_ingrediente.cantidad */
  cantidad: number;
  motivo: string;
  /**
   * Stock final. Si no se pasa `stockAnterior`, se lee con FOR UPDATE
   * y se usa este valor como absoluto (ajuste/conteo).
   */
  stockPosterior: number;
  /** Si ya se bloqueó la fila (p. ej. pedidos), pasar el valor leído. */
  stockAnterior?: number;
  pedidoId?: string | null;
  /** Order line that caused this movement; deferred FK supports create ordering. */
  pedidoItemId?: string | null;
  usuarioId?: string | null;
  /** Producción en lote: FK a `producciones`. */
  produccionId?: string | null;
  /** Compra: actualiza también costo_unitario_actual en el mismo UPDATE. */
  costoUnitarioActual?: number;
};

export type ResultadoMovimientoStock = {
  stockAnterior: number;
  stockPosterior: number;
  stockMinimo: number;
};

/**
 * Única escritura de stock + movimiento (AQ-DUP-01).
 * Sin expansión de recetas ni cascade de catálogo — eso queda en el caller.
 */
@Injectable()
export class StockMovimientoService {
  async aplicarMovimiento(
    p: AplicarMovimientoStockParams,
  ): Promise<ResultadoMovimientoStock> {
    const {
      client,
      sucursalId,
      ingredienteId,
      tipo,
      cantidad,
      motivo,
      stockPosterior,
      pedidoId = null,
      pedidoItemId = null,
      usuarioId = null,
      produccionId = null,
      costoUnitarioActual,
    } = p;

    let stockAnterior = p.stockAnterior;
    let stockMinimo = 0;

    if (stockAnterior === undefined) {
      const fila = await client.query<{
        stock_actual: string;
        stock_minimo: string;
      }>(
        `SELECT stock_actual, stock_minimo FROM ingredientes
         WHERE id = $1 AND sucursal_id = $2 FOR UPDATE`,
        [ingredienteId, sucursalId],
      );
      const row = fila.rows[0];
      if (!row) {
        throw new NotFoundException({
          error: 'INGREDIENTE_NO_ENCONTRADO',
          mensaje: 'Ingrediente no encontrado para movimiento de stock',
        });
      }
      stockAnterior = Number(row.stock_actual);
      stockMinimo = Number(row.stock_minimo);
    }

    if (stockPosterior !== stockAnterior) {
      if (costoUnitarioActual !== undefined) {
        await client.query(
          `UPDATE ingredientes
           SET stock_actual = $1, costo_unitario_actual = $2
           WHERE id = $3 AND sucursal_id = $4`,
          [stockPosterior, costoUnitarioActual, ingredienteId, sucursalId],
        );
      } else {
        await client.query(
          `UPDATE ingredientes
           SET stock_actual = $1
           WHERE id = $2 AND sucursal_id = $3`,
          [stockPosterior, ingredienteId, sucursalId],
        );
      }
    } else if (costoUnitarioActual !== undefined) {
      await client.query(
        `UPDATE ingredientes
         SET costo_unitario_actual = $1
         WHERE id = $2 AND sucursal_id = $3`,
        [costoUnitarioActual, ingredienteId, sucursalId],
      );
    }

    await client.query(
      `INSERT INTO movimientos_ingrediente (
         sucursal_id, ingrediente_id, pedido_id, pedido_item_id, tipo,
         cantidad, stock_anterior, stock_posterior, motivo,
         usuario_id, produccion_id
       ) VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11)`,
      [
        sucursalId,
        ingredienteId,
        pedidoId,
        pedidoItemId,
        tipo,
        cantidad,
        stockAnterior,
        stockPosterior,
        motivo,
        usuarioId,
        produccionId,
      ],
    );

    return {
      stockAnterior,
      stockPosterior,
      stockMinimo,
    };
  }
}
