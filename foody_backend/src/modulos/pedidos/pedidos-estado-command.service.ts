import {
  BadRequestException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { PoolClient } from 'pg';
import {
  ESTADOS_PEDIDO_INMUTABLES_DESDE_COCINA,
  pedidoCocinaCompleta,
  puedeForzarPagadoSinCocinaCompleta,
  transicionEstadoPermitida,
} from './pedido-estados';

/** Origen del cambio — F-11: única puerta para mutar `pedidos.estado` fuera de Kanban. */
export type OrigenCambioEstadoPedido =
  | 'kanban'
  | 'aprobacion_qr'
  | 'cocina'
  | 'dispatch'
  | 'domiciliario'
  | 'cobro'
  | 'sistema';

export type AplicarEstadoPedidoParams = {
  pedidoId: string;
  sucursalId: string;
  nuevoEstado: string;
  origen: OrigenCambioEstadoPedido;
  usuarioId?: string | null;
  motivo?: string | null;
  /** Si el pedido ya está bloqueado en la transacción (evita segundo FOR UPDATE). */
  estadoAnterior?: string;
  tipo?: string;
  /** VIE-05 C: rol del usuario (override admin+motivo en cobro→pagado). */
  rol?: string | null;
};

/**
 * F-11: centraliza UPDATE de `pedidos.estado` + `estados_pedido_historial`
 * para cocina, domiciliarios, dispatch y cobro.
 */
@Injectable()
export class PedidosEstadoCommandService {
  async aplicarEstadoEnTransaccion(
    client: PoolClient,
    params: AplicarEstadoPedidoParams,
  ): Promise<{
    aplicado: boolean;
    anterior: string;
    nuevo: string;
    tipo: string;
  }> {
    let anterior = params.estadoAnterior;
    let tipo = params.tipo;

    if (!anterior || !tipo) {
      const fila = await client.query<{ estado: string; tipo: string }>(
        `SELECT estado, tipo FROM pedidos
         WHERE id = $1 AND sucursal_id = $2
         FOR UPDATE`,
        [params.pedidoId, params.sucursalId],
      );
      if (!fila.rows[0]) {
        throw new NotFoundException('Pedido no encontrado');
      }
      anterior = fila.rows[0].estado;
      tipo = fila.rows[0].tipo;
    }

    const nuevo = params.nuevoEstado;
    if (anterior === nuevo) {
      return { aplicado: false, anterior, nuevo, tipo };
    }

    if (
      !this.transicionPermitidaParaOrigen(params.origen, anterior, nuevo, tipo)
    ) {
      throw new BadRequestException({
        error: 'TRANSICION_ESTADO_NO_PERMITIDA',
        message: `No se puede pasar de ${anterior} a ${nuevo} (origen: ${params.origen})`,
      });
    }

    // Un pedido solo puede aparecer como listo cuando Cocina resolvió todas
    // sus líneas. La misma regla debe cubrir Kanban y los cambios automáticos.
    if (nuevo === 'listo') {
      const completa = await pedidoCocinaCompleta(client, params.pedidoId);
      if (!completa) {
        throw new BadRequestException({
          error: 'COCINA_INCOMPLETA_PARA_LISTO',
          message:
            'No se puede marcar el pedido como listo hasta resolver todos sus ítems en Cocina.',
        });
      }
    }

    // VIE-05/13 C: cobro→pagado exige cocina completa (salvo admin+motivo)
    if (params.origen === 'cobro' && nuevo === 'pagado') {
      const completa = await pedidoCocinaCompleta(client, params.pedidoId);
      if (
        !completa &&
        !puedeForzarPagadoSinCocinaCompleta(params.rol, params.motivo)
      ) {
        throw new BadRequestException({
          error: 'COCINA_INCOMPLETA_PARA_PAGADO',
          message:
            'Hay ítems aún en cocina. Registra un abono o espera cocina completa. Admin/gerente puede cerrar con motivo.',
        });
      }
    }

    await client.query(`UPDATE pedidos SET estado = $1 WHERE id = $2`, [
      nuevo,
      params.pedidoId,
    ]);
    // ponytail: duración = now - último historial (o created_at del pedido). Techo: si no hay fila previa, usa pedidos.created_at.
    await client.query(
      `INSERT INTO estados_pedido_historial
         (pedido_id, estado_anterior, estado_nuevo, usuario_id, motivo, duracion_estado_anterior_seg)
       VALUES (
         $1, $2, $3, $4, $5,
         GREATEST(0, EXTRACT(EPOCH FROM (
           now() - COALESCE(
             (SELECT MAX(fecha) FROM estados_pedido_historial WHERE pedido_id = $1),
             (SELECT created_at FROM pedidos WHERE id = $1)
           )
         ))::int)
       )`,
      [
        params.pedidoId,
        anterior,
        nuevo,
        params.usuarioId ?? null,
        params.motivo?.trim() || this.motivoPorOrigen(params.origen),
      ],
    );

    return { aplicado: true, anterior, nuevo, tipo };
  }

  private transicionPermitidaParaOrigen(
    origen: OrigenCambioEstadoPedido,
    anterior: string,
    nuevo: string,
    tipo: string,
  ): boolean {
    if (origen === 'cobro' && nuevo === 'pagado') {
      return !['cancelado', 'rechazado', 'pagado'].includes(anterior);
    }
    if (origen === 'cobro' && nuevo === 'pagando') {
      return !['cancelado', 'rechazado', 'pagado'].includes(anterior);
    }
    if (origen === 'dispatch' || origen === 'domiciliario') {
      if (
        anterior === 'listo' &&
        nuevo === 'asignado' &&
        tipo === 'domicilio'
      ) {
        return true;
      }
      if (anterior === 'asignado' && nuevo === 'en_camino') return true;
      if (
        anterior === 'en_camino' &&
        nuevo === 'entregado' &&
        tipo === 'domicilio'
      ) {
        return true;
      }
      return false;
    }
    if (origen === 'cocina') {
      if (ESTADOS_PEDIDO_INMUTABLES_DESDE_COCINA.has(anterior)) {
        return false;
      }
      return nuevo === 'en_cocina' || nuevo === 'listo';
    }
    if (origen === 'aprobacion_qr') {
      return anterior === 'pendiente_aprobacion' && nuevo === 'en_cocina';
    }
    if (origen === 'sistema') {
      return (
        (anterior === 'pendiente_aprobacion' && nuevo === 'rechazado') ||
        transicionEstadoPermitida(anterior, nuevo, tipo)
      );
    }
    return transicionEstadoPermitida(anterior, nuevo, tipo);
  }

  private motivoPorOrigen(origen: OrigenCambioEstadoPedido): string {
    switch (origen) {
      case 'cocina':
        return 'Cambio automático desde cocina';
      case 'dispatch':
        return 'Asignación automática — planta libre';
      case 'domiciliario':
        return 'Actualización desde app domiciliario';
      case 'cobro':
        return 'Cobro en caja';
      case 'aprobacion_qr':
        return 'Aprobación pedido mesa QR';
      case 'sistema':
        return 'Cambio automático del sistema';
      default:
        return 'Cambio de estado';
    }
  }
}
