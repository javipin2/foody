import { BadRequestException, Injectable } from '@nestjs/common';
import { PoolClient } from 'pg';

export const METODOS_CON_CAJA = [
  'efectivo',
  'tarjeta',
  'transferencia',
  'nequi',
] as const;

/** Cuenta mesa / pedidos con mesa_id: la venta contable se registra al cobrar. */
export function esPagoDiferidoMesa(
  tipo: string,
  mesaId: string | null | undefined,
): boolean {
  return tipo === 'mesa' || mesaId != null;
}

/**
 * Movimiento de caja y auditoría dentro de la transacción de pedido.
 */
@Injectable()
export class PedidosCajaAuditoriaService {
  debeRegistrarVentaAlCrear(
    estadoInicial: string,
    tipo: string,
    mesaId: string | null | undefined,
    metodoPago: string,
  ): boolean {
    if (!METODOS_CON_CAJA.includes(metodoPago as (typeof METODOS_CON_CAJA)[number])) {
      return false;
    }
    if (estadoInicial === 'pendiente_aprobacion') return false;
    if (esPagoDiferidoMesa(tipo, mesaId)) return false;
    return true;
  }

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

  async registrarVentaEnCaja(
    client: PoolClient,
    sucursalId: string,
    pedidoId: string,
    total: number,
    metodoPago: string,
    opciones?: { exigirCaja?: boolean; descripcion?: string },
  ): Promise<void> {
    if (
      !METODOS_CON_CAJA.includes(metodoPago as (typeof METODOS_CON_CAJA)[number])
    ) {
      return;
    }

    const cajaId = await this.obtenerCajaAbiertaId(client, sucursalId);
    if (!cajaId) {
      if (opciones?.exigirCaja) {
        throw new BadRequestException({
          error: 'CAJA_NO_ABIERTA',
          message:
            'No hay caja abierta en la sucursal. Abre caja antes de registrar la venta.',
        });
      }
      return;
    }

    await client.query(
      `INSERT INTO movimientos_caja (
         caja_id, sucursal_id, pedido_id, tipo, monto, metodo_pago, descripcion
       ) VALUES ($1,$2,$3,'venta',$4,$5,$6)`,
      [
        cajaId,
        sucursalId,
        pedidoId,
        total,
        metodoPago,
        opciones?.descripcion ?? 'Venta automática por pedido',
      ],
    );
  }

  /** Elimina movimientos de venta previos — registra devolución auditada. */
  async revertirVentasPedido(
    client: PoolClient,
    pedidoId: string,
    sucursalId: string,
    usuarioId?: string,
    motivo?: string,
  ): Promise<number> {
    const ventas = await client.query<{ id: string; monto: string; metodo_pago: string | null; caja_id: string }>(
      `SELECT id, monto, metodo_pago, caja_id FROM movimientos_caja
       WHERE pedido_id = $1 AND tipo = 'venta'`,
      [pedidoId],
    );
    let n = 0;
    for (const v of ventas.rows) {
      await client.query(
        `INSERT INTO movimientos_caja (
           caja_id, sucursal_id, pedido_id, tipo, monto, metodo_pago, descripcion, usuario_id
         ) VALUES ($1,$2,$3,'devolucion',$4,$5,$6,$7)`,
        [
          v.caja_id,
          sucursalId,
          pedidoId,
          Number(v.monto),
          v.metodo_pago,
          motivo?.trim() || 'Reversa venta pedido',
          usuarioId ?? null,
        ],
      );
      await client.query(`DELETE FROM movimientos_caja WHERE id = $1`, [v.id]);
      n++;
    }
    return n;
  }

  async registrarAuditoria(
    client: PoolClient,
    sucursalId: string,
    pedidoId: string,
    datos: Record<string, unknown>,
  ): Promise<void> {
    await client.query(
      `INSERT INTO auditoria_logs (
         sucursal_id, accion, tabla_afectada, registro_id, datos_despues
       ) VALUES ($1,'CREAR_PEDIDO','pedidos',$2,$3::jsonb)`,
      [sucursalId, pedidoId, JSON.stringify(datos)],
    );
  }

  async registrarAuditoriaCobroMesa(
    client: PoolClient,
    sucursalId: string,
    mesaId: string,
    usuarioId: string,
    datos: Record<string, unknown>,
  ): Promise<void> {
    await client.query(
      `INSERT INTO auditoria_logs (
         sucursal_id, accion, tabla_afectada, registro_id, usuario_id, datos_despues
       ) VALUES ($1,'COBRAR_CUENTA_MESA','mesas',$2,$3,$4::jsonb)`,
      [sucursalId, mesaId, usuarioId, JSON.stringify(datos)],
    );
  }
}
