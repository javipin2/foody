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
      metodo_pago: string;
      caja_id: string;
      neto: string;
    }>(
      `SELECT caja_id,
              COALESCE(metodo_pago, 'sin_metodo') AS metodo_pago,
              (COALESCE(SUM(monto) FILTER (WHERE tipo = 'venta'), 0) -
               COALESCE(SUM(monto) FILTER (WHERE tipo = 'devolucion'), 0))::text AS neto
       FROM movimientos_caja
       WHERE pedido_id = $1 AND tipo IN ('venta', 'devolucion')
       GROUP BY caja_id, COALESCE(metodo_pago, 'sin_metodo')
       HAVING COALESCE(SUM(monto) FILTER (WHERE tipo = 'venta'), 0) > 0
       ORDER BY caja_id, metodo_pago`,
      [pedidoId],
    );
    // Conserva el total neto vigente, pero atribuye la reversa a cada caja y
    // método de origen. Si un reembolso previo se registró en otro método, se
    // distribuye el saldo pendiente proporcionalmente entre los saldos positivos.
    const saldos = ventas.rows.map((fila) => ({
      cajaId: fila.caja_id,
      metodoPago: fila.metodo_pago,
      netoCentavos: Math.round(Number(fila.neto) * 100),
    }));
    const netoCentavos = saldos.reduce(
      (total, saldo) => total + saldo.netoCentavos,
      0,
    );
    if (netoCentavos < 1) {
      return { movimientos: 0, monto_total: 0 };
    }
    const saldosPositivos = saldos.filter((saldo) => saldo.netoCentavos > 0);
    const totalPositivo = saldosPositivos.reduce(
      (total, saldo) => total + saldo.netoCentavos,
      0,
    );
    if (totalPositivo < 1) return { movimientos: 0, monto_total: 0 };

    const asignaciones = saldosPositivos.map((saldo) => {
      const exacto = (netoCentavos * saldo.netoCentavos) / totalPositivo;
      return {
        ...saldo,
        centavos: Math.floor(exacto),
        residuo: exacto - Math.floor(exacto),
      };
    });
    let centavosSinAsignar =
      netoCentavos -
      asignaciones.reduce((total, saldo) => total + saldo.centavos, 0);
    const porResiduo = [...asignaciones].sort(
      (a, b) =>
        b.residuo - a.residuo ||
        a.cajaId.localeCompare(b.cajaId) ||
        a.metodoPago.localeCompare(b.metodoPago),
    );
    for (let i = 0; centavosSinAsignar > 0; i++, centavosSinAsignar--) {
      porResiduo[i % porResiduo.length].centavos++;
    }

    let movimientos = 0;
    for (const asignacion of asignaciones) {
      if (asignacion.centavos < 1) continue;
      await this.insertar(client, {
        cajaId: asignacion.cajaId,
        sucursalId,
        pedidoId,
        tipo: 'devolucion',
        monto: asignacion.centavos / 100,
        metodoPago: asignacion.metodoPago,
        descripcion: motivo?.trim() || 'Reversa venta pedido',
        usuarioId: usuarioId ?? null,
      });
      movimientos++;
    }
    return { movimientos, monto_total: netoCentavos / 100 };
  }
}
