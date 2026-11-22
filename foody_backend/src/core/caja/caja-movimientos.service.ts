import { BadRequestException, Injectable, Logger } from '@nestjs/common';
import { PoolClient } from 'pg';

export type TipoMovimientoCaja =
  | 'venta'
  | 'devolucion'
  | 'apertura'
  | 'gasto'
  | 'retiro'
  | 'ingreso_extra';

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

/**
 * Única vía de escritura en `movimientos_caja` (A-02).
 * Caja manual y cobros de pedido deben usar este servicio.
 */
@Injectable()
export class CajaMovimientosService {
  private readonly logger = new Logger(CajaMovimientosService.name);

  async obtenerCajaAbiertaId(
    client: PoolClient,
    sucursalId: string,
  ): Promise<string | null> {
    const caja = await client.query<{ id: string }>(
      `SELECT id FROM cajas
       WHERE sucursal_id = $1 AND estado = 'abierta'
       ORDER BY apertura_at DESC
       LIMIT 1`,
      [sucursalId],
    );
    return caja.rows[0]?.id ?? null;
  }

  async insertar(
    client: PoolClient,
    params: MovimientoCajaParams,
  ): Promise<void> {
    await client.query(
      `INSERT INTO movimientos_caja (
         caja_id, sucursal_id, pedido_id, tipo, monto, metodo_pago, descripcion, usuario_id
       ) VALUES ($1,$2,$3,$4,$5,$6,$7,$8)`,
      [
        params.cajaId,
        params.sucursalId,
        params.pedidoId ?? null,
        params.tipo,
        params.monto,
        params.metodoPago ?? null,
        params.descripcion ?? null,
        params.usuarioId ?? null,
      ],
    );
  }

  /**
   * Registra venta ligada a pedido. Devuelve false si no hay caja y no se exige.
   */
  async registrarVentaPedido(
    client: PoolClient,
    params: {
      sucursalId: string;
      pedidoId: string;
      monto: number;
      metodoPago: string;
      descripcion?: string;
      usuarioId?: string | null;
    },
    opciones: { exigirCaja?: boolean } = {},
  ): Promise<boolean> {
    const exigirCaja = opciones.exigirCaja ?? true;

    const tope = await client.query<{ registrado: string; total: string }>(
      `SELECT COALESCE(SUM(mc.monto), 0) AS registrado, p.total
       FROM pedidos p
       LEFT JOIN movimientos_caja mc
         ON mc.pedido_id = p.id AND mc.tipo = 'venta'
       WHERE p.id = $1
       GROUP BY p.total`,
      [params.pedidoId],
    );
    const registrado = Number(tope.rows[0]?.registrado ?? 0);
    const totalPedido = Number(tope.rows[0]?.total ?? 0);
    const pendienteCaja = Math.max(0, totalPedido - registrado);
    const montoEfectivo = Math.min(params.monto, pendienteCaja);
    if (montoEfectivo <= 0.01) {
      return false;
    }

    const cajaId = await this.obtenerCajaAbiertaId(client, params.sucursalId);
    if (!cajaId) {
      if (exigirCaja) {
        throw new BadRequestException({
        error: 'CAJA_NO_ABIERTA',
        mensaje:
          'No hay caja abierta en la sucursal. Abre caja antes de registrar la venta.',
      });
      }
      this.logger.warn(
        `Venta pedido ${params.pedidoId} no registrada en caja: sin turno abierto (sucursal ${params.sucursalId})`,
      );
      return false;
    }

    await this.insertar(client, {
      cajaId,
      sucursalId: params.sucursalId,
      pedidoId: params.pedidoId,
      tipo: 'venta',
      monto: montoEfectivo,
      metodoPago: params.metodoPago,
      descripcion: params.descripcion ?? 'Venta por pedido',
      usuarioId: params.usuarioId ?? null,
    });
    return true;
  }

  /** Neto cobrado en caja para un pedido (ventas activas menos devoluciones registradas). */
  async netoCobradoPedidoEnCaja(
    client: PoolClient,
    pedidoId: string,
    cajaId?: string,
  ): Promise<number> {
    const fila = await client.query<{ neto: string }>(
      `SELECT COALESCE(SUM(
         CASE
           WHEN tipo = 'venta' THEN monto
           WHEN tipo = 'devolucion' THEN -monto
           ELSE 0
         END
       ), 0)::text AS neto
       FROM movimientos_caja
       WHERE pedido_id = $1
         ${cajaId ? 'AND caja_id = $2' : ''}`,
      cajaId ? [pedidoId, cajaId] : [pedidoId],
    );
    return Number(fila.rows[0]?.neto ?? 0);
  }

  /** Ventas del turno menos devoluciones ya registradas (tope para devolución manual sin pedido). */
  async netoVentasDisponiblesTurno(
    client: PoolClient,
    cajaId: string,
  ): Promise<number> {
    const fila = await client.query<{ neto: string }>(
      `SELECT COALESCE(SUM(
         CASE
           WHEN tipo = 'venta' THEN monto
           WHEN tipo = 'devolucion' THEN -monto
           ELSE 0
         END
       ), 0)::text AS neto
       FROM movimientos_caja
       WHERE caja_id = $1`,
      [cajaId],
    );
    return Number(fila.rows[0]?.neto ?? 0);
  }

  async revertirVentasPedido(
    client: PoolClient,
    pedidoId: string,
    sucursalId: string,
    usuarioId?: string,
    motivo?: string,
  ): Promise<ReversaVentasPedidoResultado> {
    const ventas = await client.query<{
      id: string;
      monto: string;
      metodo_pago: string | null;
      caja_id: string;
    }>(
      `SELECT id, monto, metodo_pago, caja_id FROM movimientos_caja
       WHERE pedido_id = $1 AND tipo = 'venta'`,
      [pedidoId],
    );
    // Neto ya cobrado (ventas menos devoluciones previas): solo revertimos lo que
    // realmente entró a la caja. Se registra UNA devolución y se conserva la venta
    // original para no perder el rastro contable (evita la doble resta: borrar la
    // venta + agregar devolución dejaba la caja con -monto de menos).
    const neto = await this.netoCobradoPedidoEnCaja(client, pedidoId);
    if (neto < 0.01) {
      return { movimientos: 0, monto_total: 0 };
    }
    const referencia = ventas.rows[0];
    await this.insertar(client, {
      cajaId: referencia.caja_id,
      sucursalId,
      pedidoId,
      tipo: 'devolucion',
      monto: neto,
      metodoPago: referencia.metodo_pago,
      descripcion: motivo?.trim() || 'Reversa venta pedido',
      usuarioId: usuarioId ?? null,
    });
    return { movimientos: 1, monto_total: neto };
  }
}
